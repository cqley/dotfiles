package main

import (
	"bytes"
	"embed"
	"html"
	"html/template"
	"io/fs"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"sort"
	"strconv"
	"strings"
	"time"
)

//go:embed page.html static
var embedded embed.FS

var (
	root   string
	pages  = template.Must(template.New("").Funcs(template.FuncMap{"leaf": leaf, "path": escape}).ParseFS(embedded, "page.html"))
	token  = regexp.MustCompile("`([^`]+)`" + `|(!?)\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|([^\]]*))?\]\]|(!?)\[([^\]]*)\]\(([^)\s]+)\)|\*\*(.+?)\*\*|\*([^*\s][^*]*)\*|(https?://[^\s<]+)`)
	head   = regexp.MustCompile(`^(#{1,6})\s+(.*)$`)
	item   = regexp.MustCompile(`^(\s*)([-*+]|\d+[.)])\s+(.*)$`)
	scheme = regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9+.-]*:`)
	link   = regexp.MustCompile(`(!?)\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|([^\]]*))?\]\]`)
)

type page struct {
	Title, Q, New, Name, Text string
	HTML                      template.HTML
	Notes, Back               []string
}

func main() {
	var err error
	if root, err = filepath.EvalSymlinks(env("NOTES_DIR", "notes")); err != nil {
		log.Fatal(err)
	}
	static, _ := fs.Sub(embedded, "static")
	m := http.NewServeMux()
	m.Handle("GET /static/", http.StripPrefix("/static/", http.FileServerFS(static)))
	m.HandleFunc("GET /{$}", home)
	m.HandleFunc("GET /today", today)
	m.HandleFunc("GET /n/{name...}", view)
	m.HandleFunc("GET /e/{name...}", edit)
	m.HandleFunc("POST /e/{name...}", save)
	m.HandleFunc("POST /d/{name...}", remove)
	m.HandleFunc("GET /f/{name...}", file)
	log.Fatal(http.ListenAndServe(env("NOTES_ADDR", "127.0.0.1:4605"), m))
}

func env(k, v string) string {
	if s := os.Getenv(k); s != "" {
		return s
	}
	return v
}

func show(w http.ResponseWriter, name string, p page) {
	var b bytes.Buffer
	if fail(w, pages.ExecuteTemplate(&b, name, p)) {
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-cache")
	b.WriteTo(w)
}

func fail(w http.ResponseWriter, err error) bool {
	if err != nil {
		log.Print(err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
	return err != nil
}

func go303(w http.ResponseWriter, r *http.Request, to string) {
	http.Redirect(w, r, to, http.StatusSeeOther)
}

func clean(name string) string {
	name = strings.Trim(strings.TrimSpace(name), "/")
	for _, p := range strings.Split(name, "/") {
		if p == "" || strings.HasPrefix(p, ".") || strings.ContainsAny(p, "\\\x00") {
			return ""
		}
	}
	return name
}

func named(w http.ResponseWriter, r *http.Request) string {
	n := clean(r.PathValue("name"))
	if n == "" {
		http.Error(w, "bad name", http.StatusBadRequest)
	}
	return n
}

func src(name string) string {
	return filepath.Join(root, name) + ".md"
}

func escape(name string) string {
	p := strings.Split(name, "/")
	for i := range p {
		p[i] = url.PathEscape(p[i])
	}
	return strings.Join(p, "/")
}

func leaf(name string) string {
	return name[strings.LastIndex(name, "/")+1:]
}

func notes() map[string]string {
	out := map[string]string{}
	filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err == nil && p != root && strings.HasPrefix(d.Name(), ".") && d.IsDir() {
			return filepath.SkipDir
		}
		if err == nil && strings.HasSuffix(p, ".md") && !strings.HasPrefix(d.Name(), ".") {
			b, _ := os.ReadFile(p)
			rel, _ := filepath.Rel(root, p)
			out[strings.TrimSuffix(filepath.ToSlash(rel), ".md")] = string(b)
		}
		return nil
	})
	return out
}

func esc(s string) string {
	return html.EscapeString(s)
}

func ref(img bool, u, label string) string {
	if scheme.MatchString(u) && !strings.HasPrefix(u, "http") && !strings.HasPrefix(u, "mailto:") {
		u = "#"
	}
	if img {
		return `<img src="` + esc(u) + `" alt="` + esc(label) + `">`
	}
	return `<a href="` + esc(u) + `">` + inline(label) + `</a>`
}

func inline(s string) string {
	var b strings.Builder
	last := 0
	for _, m := range token.FindAllStringSubmatchIndex(s, -1) {
		b.WriteString(esc(s[last:m[0]]))
		last = m[1]
		g := func(i int) string {
			if m[2*i] < 0 {
				return ""
			}
			return s[m[2*i]:m[2*i+1]]
		}
		switch {
		case m[2] >= 0:
			b.WriteString("<code>" + esc(g(1)) + "</code>")
		case m[6] >= 0:
			t, label, to := strings.TrimSpace(g(3)), g(4), "/n/"
			if label == "" {
				label = leaf(t)
			}
			if g(2) != "" {
				to = "/f/"
			}
			b.WriteString(ref(g(2) != "", to+escape(t), label))
		case m[14] >= 0:
			b.WriteString(ref(g(5) != "", g(7), g(6)))
		case m[16] >= 0:
			b.WriteString("<strong>" + inline(g(8)) + "</strong>")
		case m[18] >= 0:
			b.WriteString("<em>" + inline(g(9)) + "</em>")
		default:
			b.WriteString(`<a href="` + esc(g(10)) + `">` + esc(g(10)) + `</a>`)
		}
	}
	return b.String() + esc(s[last:])
}

func render(text string) string {
	var b strings.Builder
	open := ""
	end := func() {
		if open != "" {
			b.WriteString("</" + open + ">\n")
			open = ""
		}
	}
	start := func(t string) {
		if open == t && (t == "p" || t == "blockquote") {
			b.WriteString("<br>")
		} else if open != t {
			end()
			b.WriteString("<" + t + ">")
			open = t
		}
	}
	ls := strings.Split(text, "\n")
	for i := 0; i < len(ls); i++ {
		l := strings.TrimRight(ls[i], " \t\r")
		t := strings.TrimSpace(l)
		switch {
		case strings.HasPrefix(t, "```") || strings.HasPrefix(t, "~~~"):
			end()
			b.WriteString("<pre><code>")
			for i++; i < len(ls) && !strings.HasPrefix(strings.TrimSpace(ls[i]), t[:3]); i++ {
				b.WriteString(esc(ls[i]) + "\n")
			}
			b.WriteString("</code></pre>\n")
		case t == "":
			end()
		case head.MatchString(t):
			end()
			m := head.FindStringSubmatch(t)
			h := strconv.Itoa(len(m[1]))
			b.WriteString("<h" + h + ">" + inline(m[2]) + "</h" + h + ">\n")
		case len(t) >= 3 && strings.Trim(t, "-*_ ") == "":
			end()
			b.WriteString("<hr>\n")
		case strings.HasPrefix(t, ">"):
			start("blockquote")
			b.WriteString(inline(strings.TrimSpace(t[1:])))
		case strings.HasPrefix(t, "|"):
			end()
			b.WriteString("<table>")
			for ; i < len(ls) && strings.HasPrefix(strings.TrimSpace(ls[i]), "|"); i++ {
				r := strings.Trim(strings.TrimSpace(ls[i]), "|")
				if strings.Trim(r, "|-: ") == "" {
					continue
				}
				b.WriteString("<tr>")
				for _, c := range strings.Split(r, "|") {
					b.WriteString("<td>" + inline(strings.TrimSpace(c)) + "</td>")
				}
				b.WriteString("</tr>")
			}
			i--
			b.WriteString("</table>\n")
		case item.MatchString(l):
			m := item.FindStringSubmatch(l)
			kind := "ul"
			if m[2][0] >= '0' && m[2][0] <= '9' {
				kind = "ol"
			}
			start(kind)
			s, box := m[3], ""
			switch {
			case strings.HasPrefix(s, "[ ] "):
				s, box = s[4:], `<input type="checkbox" disabled>`
			case strings.HasPrefix(s, "[x] "), strings.HasPrefix(s, "[X] "):
				s, box = s[4:], `<input type="checkbox" disabled checked>`
			}
			b.WriteString(`<li style="margin-left:` + strconv.Itoa(min(len(m[1])/2, 6)) + `em">` + box + inline(s) + "</li>")
		default:
			start("p")
			b.WriteString(inline(t))
		}
	}
	end()
	return b.String()
}

func home(w http.ResponseWriter, r *http.Request) {
	q := strings.TrimSpace(r.FormValue("q"))
	p := page{Title: "notes", Q: q, New: clean(q)}
	for n := range notes() {
		if strings.Contains(strings.ToLower(n), strings.ToLower(q)) {
			p.Notes = append(p.Notes, n)
		}
		if n == p.New {
			p.New = ""
		}
	}
	sort.Strings(p.Notes)
	show(w, "home", p)
}

func today(w http.ResponseWriter, r *http.Request) {
	go303(w, r, "/n/"+time.Now().Format("2006-01-02"))
}

func view(w http.ResponseWriter, r *http.Request) {
	n := named(w, r)
	if n == "" {
		return
	}
	b, err := os.ReadFile(src(n))
	if err != nil {
		go303(w, r, "/e/"+escape(n))
		return
	}
	p := page{Title: leaf(n), Name: n, HTML: template.HTML(render(string(b)))}
	for o, text := range notes() {
		if o != n && slices.ContainsFunc(link.FindAllStringSubmatch(text, -1), func(m []string) bool { return strings.TrimSpace(m[2]) == n }) {
			p.Back = append(p.Back, o)
		}
	}
	sort.Strings(p.Back)
	show(w, "view", p)
}

func edit(w http.ResponseWriter, r *http.Request) {
	if n := named(w, r); n != "" {
		b, _ := os.ReadFile(src(n))
		show(w, "edit", page{Title: leaf(n), Name: n, Text: string(b)})
	}
}

func save(w http.ResponseWriter, r *http.Request) {
	n := named(w, r)
	if n == "" {
		return
	}
	to := clean(r.FormValue("name"))
	if to == "" {
		to = n
	}
	if _, err := os.Stat(src(to)); to != n && err == nil {
		http.Error(w, to+" already exists", http.StatusConflict)
		return
	}
	text := strings.ReplaceAll(r.FormValue("text"), "\r\n", "\n")
	if fail(w, os.MkdirAll(filepath.Dir(src(to)), 0o755)) ||
		fail(w, os.WriteFile(src(to)+".tmp", []byte(text), 0o644)) ||
		fail(w, os.Rename(src(to)+".tmp", src(to))) {
		return
	}
	if to != n {
		os.Remove(src(n))
	}
	go303(w, r, "/n/"+escape(to))
}

func remove(w http.ResponseWriter, r *http.Request) {
	if n := named(w, r); n != "" && !fail(w, os.Remove(src(n))) {
		go303(w, r, "/")
	}
}

func file(w http.ResponseWriter, r *http.Request) {
	if n := named(w, r); n != "" {
		w.Header().Set("Content-Security-Policy", "sandbox")
		http.ServeFile(w, r, filepath.Join(root, n))
	}
}
