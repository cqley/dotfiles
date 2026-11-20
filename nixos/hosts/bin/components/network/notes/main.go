package main

import (
	"bytes"
	"embed"
	"html"
	"html/template"
	"io/fs"
	"log"
	"net"
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
	pages  = template.Must(template.New("").Funcs(template.FuncMap{"leaf": leaf, "path": escape, "at": at, "dir": dir, "up": up, "parent": parent}).ParseFS(embedded, "page.html"))
	token  = regexp.MustCompile("`([^`]+)`" + `|(!?)\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|([^\]]*))?\]\]|(!?)\[([^\]]*)\]\(((?:[^()\s]|\([^()\s]*\))+)\)|\*\*(.+?)\*\*|\*([^*\s][^*]*)\*|(https?://[^\s<]+)`)
	head   = regexp.MustCompile(`^(#{1,6})\s+(.*)$`)
	item   = regexp.MustCompile(`^(\s*)([-*+]|\d+[.)])\s+(.*)$`)
	scheme = regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9+.-]*:`)
	link   = regexp.MustCompile(`(!?)\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|([^\]]*))?\]\]`)
)

type page struct {
	Q, New, Name, Text     string
	HTML                   template.HTML
	Notes, Dirs, All, Back []string
	Missing                bool
}

func main() {
	var err error
	if root, err = filepath.EvalSymlinks(env("NOTES_DIR", "notes")); err != nil {
		log.Fatal(err)
	}
	static, _ := fs.Sub(embedded, "static")
	m := http.NewServeMux()
	m.Handle("GET /static/", http.StripPrefix("/static/", http.FileServerFS(static)))
	m.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) { folder(w, r, "") })
	m.HandleFunc("GET /today", today)
	m.HandleFunc("GET /n/{name...}", view)
	m.HandleFunc("GET /e/{name...}", edit)
	m.HandleFunc("POST /e/{name...}", save)
	m.HandleFunc("POST /d/{name...}", remove)
	m.HandleFunc("GET /f/{name...}", file)
	m.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) { no(w) })
	l, err := net.FileListener(os.NewFile(3, "notes.sock"))
	if err != nil {
		log.Fatal(err)
	}
	c := http.NewCrossOriginProtection()
	for _, o := range strings.Fields(os.Getenv("NOTES_ORIGINS")) {
		if err := c.AddTrustedOrigin(o); err != nil {
			log.Fatal(err)
		}
	}
	log.Fatal(http.Serve(l, c.Handler(m)))
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

func no(w http.ResponseWriter) {
	var b bytes.Buffer
	if fail(w, pages.ExecuteTemplate(&b, "no", page{})) {
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusNotFound)
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

func bare(name string) string {
	return strings.TrimSuffix(name, ".md")
}

func at(name string) string {
	return "/n/" + escape(name) + ".md"
}

func named(w http.ResponseWriter, r *http.Request) string {
	n := bare(clean(r.PathValue("name")))
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

func parent(name string) string {
	return name[:max(strings.LastIndex(name, "/"), 0)]
}

func dir(name string) string {
	if name == "" {
		return "/"
	}
	return "/n/" + escape(name) + "/"
}

func up(name string) []string {
	var out []string
	for i, c := range name {
		if c == '/' {
			out = append(out, name[:i])
		}
	}
	return out
}

func isdir(name string) bool {
	s, err := os.Stat(filepath.Join(root, name))
	return err == nil && s.IsDir()
}

func prune(name string) {
	for d := parent(name); d != "" && os.Remove(filepath.Join(root, d)) == nil; d = parent(d) {
	}
}

func near(name string) string {
	d := parent(name)
	for d != "" && !isdir(d) {
		d = parent(d)
	}
	return dir(d)
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
	if l := strings.ToLower(u); scheme.MatchString(u) && !strings.HasPrefix(l, "http:") && !strings.HasPrefix(l, "https:") && !strings.HasPrefix(l, "mailto:") {
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
			t, label := strings.TrimSpace(g(3)), g(4)
			if label == "" {
				label = leaf(t)
			}
			to := at(bare(t))
			if g(2) != "" {
				to = "/f/" + escape(t)
			}
			b.WriteString(ref(g(2) != "", to, label))
		case m[14] >= 0:
			b.WriteString(ref(g(5) != "", g(7), g(6)))
		case m[16] >= 0:
			b.WriteString("<strong>" + inline(g(8)) + "</strong>")
		case m[18] >= 0:
			b.WriteString("<em>" + inline(g(9)) + "</em>")
		default:
			u := g(10)
			for len(u) > 0 {
				c := u[len(u)-1]
				if !strings.ContainsRune(".,:;!?'\"", rune(c)) && (c != ')' || strings.Count(u, "(") >= strings.Count(u, ")")) {
					break
				}
				u = u[:len(u)-1]
			}
			b.WriteString(`<a href="` + esc(u) + `">` + esc(u) + `</a>` + esc(g(10)[len(u):]))
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
				r = link.ReplaceAllStringFunc(r, func(s string) string { return strings.ReplaceAll(s, "|", "\x00") })
				for _, c := range strings.Split(r, "|") {
					b.WriteString("<td>" + inline(strings.ReplaceAll(strings.TrimSpace(c), "\x00", "|")) + "</td>")
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

func folder(w http.ResponseWriter, r *http.Request, d string) {
	q := strings.TrimSpace(r.FormValue("q"))
	pre := ""
	if d != "" {
		pre = d + "/"
	}
	p := page{Q: q, Name: d}
	if q != "" {
		p.New = bare(clean(pre + q))
	}
	list, err := os.ReadDir(filepath.Join(root, d))
	if fail(w, err) {
		return
	}
	for _, e := range list {
		if strings.HasPrefix(e.Name(), ".") {
			continue
		}
		if e.IsDir() {
			p.Dirs = append(p.Dirs, pre+e.Name())
		} else if strings.HasSuffix(e.Name(), ".md") {
			p.Notes = append(p.Notes, pre+bare(e.Name()))
		}
	}
	for n := range notes() {
		if strings.HasPrefix(n, pre) && strings.Contains(strings.ToLower(n[len(pre):]), strings.ToLower(q)) {
			p.All = append(p.All, n)
		}
		if n == p.New {
			p.New = ""
		}
	}
	sort.Strings(p.All)
	show(w, "home", p)
}

func today(w http.ResponseWriter, r *http.Request) {
	go303(w, r, at("daily/"+time.Now().Format("2006-01-02")))
}

func find(n string) string {
	if strings.Contains(n, "/") {
		return ""
	}
	hit := ""
	for o := range notes() {
		if leaf(o) == n {
			if hit != "" {
				return ""
			}
			hit = o
		}
	}
	return hit
}

func view(w http.ResponseWriter, r *http.Request) {
	if clean(r.PathValue("name")) == "" {
		http.Redirect(w, r, "/", http.StatusMovedPermanently)
		return
	}
	n := named(w, r)
	if n == "" {
		return
	}
	if raw := clean(r.PathValue("name")); !strings.HasSuffix(raw, ".md") {
		if s, err := os.Stat(filepath.Join(root, raw)); err == nil && s.IsDir() {
			if strings.HasSuffix(r.URL.Path, "/") {
				folder(w, r, raw)
			} else {
				http.Redirect(w, r, dir(raw), http.StatusMovedPermanently)
			}
		} else if err == nil && s.Mode().IsRegular() {
			go303(w, r, "/f/"+escape(raw))
		} else {
			http.Redirect(w, r, at(n), http.StatusMovedPermanently)
		}
		return
	}
	b, err := os.ReadFile(src(n))
	if os.IsNotExist(err) {
		if o := find(n); o != "" {
			go303(w, r, at(o))
		} else {
			go303(w, r, "/e/"+escape(n))
		}
		return
	}
	if fail(w, err) {
		return
	}
	p := page{Name: n, HTML: template.HTML(render(string(b)))}
	short := n
	if find(leaf(n)) == n {
		short = leaf(n)
	}
	for o, text := range notes() {
		if o != n && slices.ContainsFunc(link.FindAllStringSubmatch(text, -1), func(m []string) bool { t := bare(strings.TrimSpace(m[2])); return t == n || t == short }) {
			p.Back = append(p.Back, o)
		}
	}
	sort.Strings(p.Back)
	show(w, "view", p)
}

func edit(w http.ResponseWriter, r *http.Request) {
	if n := named(w, r); n != "" {
		b, err := os.ReadFile(src(n))
		if os.IsNotExist(err) || !fail(w, err) {
			show(w, "edit", page{Name: n, Text: string(b), Missing: err != nil})
		}
	}
}

func save(w http.ResponseWriter, r *http.Request) {
	n := named(w, r)
	if n == "" {
		return
	}
	to := bare(clean(r.FormValue("name")))
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
		if err := os.Remove(src(n)); !os.IsNotExist(err) && fail(w, err) {
			return
		}
		prune(n)
	}
	go303(w, r, at(to))
}

func remove(w http.ResponseWriter, r *http.Request) {
	n := named(w, r)
	if n == "" {
		return
	}
	if isdir(n) {
		if l, err := os.ReadDir(filepath.Join(root, n)); fail(w, err) {
			return
		} else if len(l) > 0 {
			http.Error(w, "folder is not empty", http.StatusConflict)
		} else if !fail(w, os.Remove(filepath.Join(root, n))) {
			prune(n)
			go303(w, r, near(n))
		}
		return
	}
	if err := os.Remove(src(n)); os.IsNotExist(err) {
		no(w)
	} else if !fail(w, err) {
		prune(n)
		go303(w, r, near(n))
	}
}

func file(w http.ResponseWriter, r *http.Request) {
	if n := clean(r.PathValue("name")); n == "" {
		http.Error(w, "bad name", http.StatusBadRequest)
	} else if isdir(n) {
		http.Redirect(w, r, dir(n), http.StatusMovedPermanently)
	} else if _, err := os.Stat(filepath.Join(root, n)); err != nil {
		no(w)
	} else {
		w.Header().Set("Content-Security-Policy", "sandbox")
		http.ServeFile(w, r, filepath.Join(root, n))
	}
}
