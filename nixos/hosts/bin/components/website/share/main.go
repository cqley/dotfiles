package main

import (
	"archive/tar"
	"archive/zip"
	"bytes"
	"compress/gzip"
	"crypto/pbkdf2"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"html/template"
	"io"
	"io/fs"
	"log"
	"mime"
	"net"
	"net/http"
	"net/netip"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
	"unicode"
	"unicode/utf8"
)

//go:embed page.html static
var embedded embed.FS

const (
	limit   = 250 << 20
	textMax = 1 << 20
	csp     = "default-src 'none'; img-src 'self'; media-src 'self'; frame-src 'self'; style-src 'self'; script-src 'self'; connect-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'self'"
	rawCSP  = "default-src 'none'; img-src 'self' data:; media-src 'self'; style-src 'unsafe-inline'; sandbox"
	pdfCSP  = "default-src 'none'; img-src 'self' data:; style-src 'unsafe-inline'; frame-ancestors 'self'"
)

var (
	root    = env("SHARE_DIR", "share")
	site    = env("SHARE_URL", "https://share.1f2t.org/")
	pages   = template.Must(template.New("").Funcs(template.FuncMap{"host": func() string { u, _ := url.Parse(site); return u.Host }}).ParseFS(embedded, "page.html"))
	upKey   [32]byte
	mu      sync.Mutex
	slow    sync.Mutex
	token   = regexp.MustCompile("`([^`]+)`" + `|(!?)\[([^\]]*)\]\(([^)\s]+)\)|\*\*(.+?)\*\*|\*([^*\s][^*]*)\*|(https?://[^\s<]+)`)
	head    = regexp.MustCompile(`^(#{1,6})\s+(.*)$`)
	item    = regexp.MustCompile(`^(\s*)([-*+]|\d+[.)])\s+(.*)$`)
	scheme  = regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9+.-]*:`)
	blocked = []netip.Prefix{
		netip.MustParsePrefix("0.0.0.0/8"),
		netip.MustParsePrefix("100.64.0.0/10"),
		netip.MustParsePrefix("198.18.0.0/15"),
		netip.MustParsePrefix("64:ff9b::/96"),
	}
	client = &http.Client{
		Timeout: 10 * time.Minute,
		Transport: &http.Transport{
			DialContext:           (&net.Dialer{Timeout: 10 * time.Second, Control: public}).DialContext,
			TLSHandshakeTimeout:   10 * time.Second,
			ResponseHeaderTimeout: 30 * time.Second,
		},
		CheckRedirect: func(r *http.Request, via []*http.Request) error {
			if len(via) >= 5 || (r.URL.Scheme != "http" && r.URL.Scheme != "https") {
				return errors.New("bad redirect")
			}
			return nil
		},
	}
	types = []struct{ ext, typ, kind string }{
		{".png", "image/png", "image"},
		{".jpg", "image/jpeg", "image"},
		{".jpeg", "image/jpeg", "image"},
		{".gif", "image/gif", "image"},
		{".webp", "image/webp", "image"},
		{".avif", "image/avif", "image"},
		{".bmp", "image/bmp", "image"},
		{".ico", "image/x-icon", "image"},
		{".svg", "image/svg+xml", "image"},
		{".mp4", "video/mp4", "video"},
		{".m4v", "video/mp4", "video"},
		{".webm", "video/webm", "video"},
		{".mov", "video/quicktime", "video"},
		{".ogv", "video/ogg", "video"},
		{".mp3", "audio/mpeg", "audio"},
		{".ogg", "audio/ogg", "audio"},
		{".opus", "audio/ogg", "audio"},
		{".oga", "audio/ogg", "audio"},
		{".flac", "audio/flac", "audio"},
		{".wav", "audio/wav", "audio"},
		{".m4a", "audio/mp4", "audio"},
		{".aac", "audio/aac", "audio"},
		{".pdf", "application/pdf", "pdf"},
		{".zip", "application/zip", "archive"},
		{".tar", "application/x-tar", "archive"},
		{".tar.gz", "application/gzip", "archive"},
		{".tgz", "application/gzip", "archive"},
	}
)

type meta struct {
	Expiry int64  `json:"expiry,omitempty"`
	Delete string `json:"delete,omitempty"`
	Access string `json:"access,omitempty"`
	Sha256 string `json:"sha256,omitempty"`
}

type file struct {
	Name, Kind, Type, Size, Date, Expires string
	Locked                                bool
	mod                                   time.Time
	size                                  int64
}

type entry struct{ Name, Size string }

type result struct {
	URL       string `json:"url"`
	Raw       string `json:"direct_url"`
	Name      string `json:"filename"`
	DeleteKey string `json:"delete_key"`
	Expiry    int64  `json:"expiry"`
	Size      int64  `json:"size"`
	Sha256    string `json:"sha256sum"`
}

type opts struct {
	name, del, access string
	random            bool
	expiry            int64
}

type page struct {
	Title, Text, Err, Abs, Site string
	Code                        template.HTML
	Hidden                      bool
	F                           file
	HTML                        template.HTML
	Lines                       []int
	Source                      bool
	Known                       bool
	Entries                     []entry
	Files                       []file
	Done                        []result
}

type oops struct {
	code int
	msg  string
}

func (e oops) Error() string { return e.msg }

func main() {
	k, err := os.ReadFile(filepath.Join(os.Getenv("CREDENTIALS_DIRECTORY"), "key"))
	if err != nil || len(bytes.TrimSpace(k)) < 16 {
		log.Fatal("no upload key ", err)
	}
	upKey = sha256.Sum256(bytes.TrimSpace(k))
	for _, d := range []string{"files", "meta"} {
		if err := os.MkdirAll(filepath.Join(root, d), 0o700); err != nil {
			log.Fatal(err)
		}
	}
	go sweep()
	static, _ := fs.Sub(embedded, "static")
	pub := http.NewServeMux()
	pub.Handle("GET /static/", http.StripPrefix("/static/", http.FileServerFS(static)))
	pub.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		show(w, 200, "home", page{Title: "分", Known: known(r)})
	})
	pub.HandleFunc("POST /forget", func(w http.ResponseWriter, r *http.Request) {
		remember(w, "", -1)
		http.Redirect(w, r, "/", http.StatusSeeOther)
	})
	pub.HandleFunc("POST /upload", upload)
	pub.HandleFunc("PUT /upload", upload)
	pub.HandleFunc("PUT /upload/", upload)
	pub.HandleFunc("GET /{name}", view)
	pub.HandleFunc("POST /{name}", unlock)
	pub.HandleFunc("DELETE /{name}", remove)
	pub.HandleFunc("POST /d/{name}", remove)
	pub.HandleFunc("GET /raw/{name}", raw)
	pub.HandleFunc("GET /selif/{name}", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/raw/"+url.PathEscape(r.PathValue("name")), http.StatusMovedPermanently)
	})
	dash := http.NewServeMux()
	dash.Handle("GET /static/", http.StripPrefix("/static/", http.FileServerFS(static)))
	dash.HandleFunc("GET /{$}", list)
	dash.HandleFunc("POST /d/{name}", purge)
	go serve(4, dash, strings.Fields(os.Getenv("SHARE_DASH_ORIGINS")))
	serve(3, pub, nil)
}

func serve(fd uintptr, m *http.ServeMux, trusted []string) {
	c := http.NewCrossOriginProtection()
	for _, o := range trusted {
		if err := c.AddTrustedOrigin(o); err != nil {
			log.Fatal(err)
		}
	}
	l, err := net.FileListener(os.NewFile(fd, "share.sock"))
	if err != nil {
		log.Fatal(err)
	}
	s := &http.Server{Handler: c.Handler(m), ReadHeaderTimeout: 10 * time.Second}
	log.Fatal(s.Serve(l))
}

func env(k, v string) string {
	if s := os.Getenv(k); s != "" {
		return s
	}
	return v
}

func at(dir, name string) string {
	return filepath.Join(root, dir, name)
}

func show(w http.ResponseWriter, code int, name string, p page) {
	var b bytes.Buffer
	if err := pages.ExecuteTemplate(&b, name, p); err != nil {
		fail(w, err)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Content-Security-Policy", csp)
	w.Header().Set("Cache-Control", "no-cache")
	w.WriteHeader(code)
	b.WriteTo(w)
}

func fail(w http.ResponseWriter, err error) bool {
	var e oops
	switch {
	case err == nil:
		return false
	case errors.As(err, &e):
		http.Error(w, e.msg, e.code)
	case errors.Is(err, fs.ErrNotExist):
		http.Error(w, "no.", http.StatusNotFound)
	default:
		log.Print(err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
	return true
}

func wantsJSON(r *http.Request) bool {
	return strings.Contains(r.Header.Get("Accept"), "application/json")
}

func reply(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}

func random(n int) string {
	const abc = "abcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, n)
	rand.Read(b)
	for i := range b {
		b[i] = abc[int(b[i])%len(abc)]
	}
	return string(b)
}

func ext(name string) string {
	if l := strings.ToLower(name); strings.HasSuffix(l, ".tar.gz") {
		return name[len(name)-7:]
	}
	return filepath.Ext(name)
}

func clean(s string) string {
	var b strings.Builder
	for _, r := range path.Base(strings.ReplaceAll(s, "\\", "/")) {
		switch {
		case unicode.IsLetter(r) || unicode.IsDigit(r) || r == '.' || r == '_' || r == '-':
			b.WriteRune(r)
		case unicode.IsSpace(r):
			b.WriteRune('_')
		}
	}
	n := strings.TrimLeft(b.String(), ".-")
	if len(n) > 100 {
		e := ext(n)
		if len(e) > 20 {
			e = ""
		}
		n = strings.ToValidUTF8(n[:100-len(e)], "") + e
	}
	if n == "upload" || n == "forget" {
		return ""
	}
	return n
}

func kind(name string, head []byte) (string, string) {
	e := strings.ToLower(ext(name))
	for _, t := range types {
		if t.ext == e {
			return t.kind, t.typ
		}
	}
	if !text(head) {
		return "file", "application/octet-stream"
	}
	if e == ".md" {
		return "md", "text/plain"
	}
	return "text", "text/plain"
}

func text(b []byte) bool {
	if bytes.IndexByte(b, 0) >= 0 {
		return false
	}
	for i := 0; i < 3 && len(b) > 0 && !utf8.Valid(b); i++ {
		b = b[:len(b)-1]
	}
	return utf8.Valid(b)
}

func peek(p string, n int) []byte {
	f, err := os.Open(p)
	if err != nil {
		return nil
	}
	defer f.Close()
	b := make([]byte, n)
	n, _ = io.ReadFull(f, b)
	return b[:n]
}

func size(n int64) string {
	units := []string{"B", "KB", "MB", "GB", "TB"}
	v, i := float64(n), 0
	for v >= 1024 && i < len(units)-1 {
		v /= 1024
		i++
	}
	if i == 0 {
		return fmt.Sprintf("%d B", n)
	}
	if v < 10 {
		return fmt.Sprintf("%.2f %s", v, units[i])
	}
	return fmt.Sprintf("%.1f %s", v, units[i])
}

func hash(k string) string {
	salt := make([]byte, 16)
	rand.Read(salt)
	return hex.EncodeToString(salt) + "$" + hex.EncodeToString(derive(k, salt))
}

func derive(k string, salt []byte) []byte {
	slow.Lock()
	defer slow.Unlock()
	b, _ := pbkdf2.Key(sha256.New, k, salt, 100000, 32)
	return b
}

func check(stored, k string) bool {
	s, h, ok := strings.Cut(stored, "$")
	salt, err := hex.DecodeString(s)
	want, err2 := hex.DecodeString(h)
	if !ok || k == "" || err != nil || err2 != nil {
		return false
	}
	return subtle.ConstantTimeCompare(derive(k, salt), want) == 1
}

func authed(k string) bool {
	h := sha256.Sum256([]byte(strings.TrimSpace(k)))
	return k != "" && subtle.ConstantTimeCompare(h[:], upKey[:]) == 1
}

func ticket() string {
	h := sha256.Sum256(append(upKey[:], "upload"...))
	return hex.EncodeToString(h[:])
}

func known(r *http.Request) bool {
	c, err := r.Cookie("up")
	return err == nil && subtle.ConstantTimeCompare([]byte(c.Value), []byte(ticket())) == 1
}

func remember(w http.ResponseWriter, v string, age int) {
	http.SetCookie(w, &http.Cookie{Name: "up", Value: v, Path: "/", MaxAge: age, Secure: true, HttpOnly: true, SameSite: http.SameSiteStrictMode})
}

func cookie(name string) string {
	h := sha256.Sum256([]byte(name))
	return "k" + hex.EncodeToString(h[:6])
}

func pass(m meta) string {
	h := sha256.Sum256([]byte("share " + m.Access))
	return hex.EncodeToString(h[:])
}

func opened(r *http.Request, name string, m meta) bool {
	if m.Access == "" {
		return true
	}
	if c, err := r.Cookie(cookie(name)); err == nil && subtle.ConstantTimeCompare([]byte(c.Value), []byte(pass(m))) == 1 {
		return true
	}
	return check(m.Access, r.Header.Get("Linx-Access-Key"))
}

func drop(name string) error {
	for _, p := range []string{at("files", name), at("meta", name)} {
		if err := os.Remove(p); err != nil && !errors.Is(err, fs.ErrNotExist) {
			return err
		}
	}
	return nil
}

func load(name string) (file, meta, error) {
	var m meta
	if name == "" || clean(name) != name {
		return file{}, m, fs.ErrNotExist
	}
	fi, err := os.Stat(at("files", name))
	if err != nil {
		return file{}, m, err
	}
	if !fi.Mode().IsRegular() {
		return file{}, m, fs.ErrNotExist
	}
	b, err := os.ReadFile(at("meta", name))
	if err == nil {
		err = json.Unmarshal(b, &m)
	} else if errors.Is(err, fs.ErrNotExist) {
		err = nil
	}
	if err != nil {
		return file{}, m, fmt.Errorf("%s: %w", name, err)
	}
	if m.Expiry > 0 && time.Now().Unix() >= m.Expiry {
		if err := drop(name); err != nil {
			log.Print(err)
		}
		return file{}, m, fs.ErrNotExist
	}
	f := file{Name: name, Size: size(fi.Size()), Date: fi.ModTime().Format("2006-01-02 15:04"), Locked: m.Access != "", mod: fi.ModTime(), size: fi.Size()}
	f.Kind, f.Type = kind(name, peek(at("files", name), 8192))
	if m.Expiry > 0 {
		f.Expires = until(m.Expiry)
	}
	return f, m, nil
}

func until(t int64) string {
	d := time.Until(time.Unix(t, 0))
	n, u := int(d.Minutes()), "minute"
	switch {
	case d >= 48*time.Hour:
		n, u = int(d.Hours()/24), "day"
	case d >= 2*time.Hour:
		n, u = int(d.Hours()), "hour"
	}
	if n != 1 {
		u += "s"
	}
	return strconv.Itoa(n) + " " + u
}

func sweep() {
	for ; ; time.Sleep(10 * time.Minute) {
		ms, _ := os.ReadDir(filepath.Join(root, "meta"))
		for _, e := range ms {
			if _, err := os.Stat(at("files", e.Name())); errors.Is(err, fs.ErrNotExist) {
				if i, err := e.Info(); err == nil && time.Since(i.ModTime()) > time.Hour {
					os.Remove(at("meta", e.Name()))
				}
				continue
			}
			if _, _, err := load(e.Name()); err != nil && !errors.Is(err, fs.ErrNotExist) {
				log.Print(err)
			}
		}
		tmps, _ := os.ReadDir(filepath.Join(root, "files"))
		for _, e := range tmps {
			if i, err := e.Info(); err == nil && strings.HasPrefix(e.Name(), ".up") && time.Since(i.ModTime()) > 24*time.Hour {
				os.Remove(at("files", e.Name()))
			}
		}
	}
}

func taken(name string) bool {
	for _, d := range []string{"files", "meta"} {
		if _, err := os.Lstat(at(d, name)); !errors.Is(err, fs.ErrNotExist) {
			return true
		}
	}
	return false
}

func store(body io.Reader, o opts) (result, error) {
	tmp, err := os.CreateTemp(filepath.Join(root, "files"), ".up")
	if err != nil {
		return result{}, err
	}
	defer os.Remove(tmp.Name())
	defer tmp.Close()
	h := sha256.New()
	n, err := io.Copy(io.MultiWriter(tmp, h), io.LimitReader(body, limit+1))
	if err != nil {
		return result{}, err
	}
	if n > limit {
		return result{}, oops{http.StatusRequestEntityTooLarge, "too big, max " + size(limit)}
	}
	if err := tmp.Close(); err != nil {
		return result{}, err
	}
	name, e := clean(o.name), ""
	if e = ext(name); e == "" {
		t := http.DetectContentType(peek(tmp.Name(), 512))
		for _, x := range types {
			if x.typ == t {
				e = x.ext
				break
			}
		}
		if name != "" {
			name += e
		}
	}
	if len(e) > 20 {
		e = ""
	}
	if o.random {
		name = ""
	}
	if o.del == "" {
		o.del = random(24)
	}
	m := meta{Delete: hash(o.del), Sha256: hex.EncodeToString(h.Sum(nil))}
	if o.expiry > 0 {
		m.Expiry = time.Now().Unix() + o.expiry
	}
	if o.access != "" {
		m.Access = hash(o.access)
	}
	b, err := json.Marshal(m)
	if err != nil {
		return result{}, err
	}
	mu.Lock()
	defer mu.Unlock()
	for name == "" || taken(name) {
		name = random(8) + strings.ToLower(e)
	}
	if err := os.WriteFile(at("meta", name), b, 0o600); err != nil {
		return result{}, err
	}
	if err := os.Rename(tmp.Name(), at("files", name)); err != nil {
		os.Remove(at("meta", name))
		return result{}, err
	}
	return result{URL: site + url.PathEscape(name), Raw: site + "raw/" + url.PathEscape(name), Name: name, DeleteKey: o.del, Expiry: m.Expiry, Size: n, Sha256: m.Sha256}, nil
}

func public(network, address string, _ syscall.RawConn) error {
	host, port, err := net.SplitHostPort(address)
	ip, err2 := netip.ParseAddr(host)
	if err != nil || err2 != nil || (port != "80" && port != "443") {
		return errors.New("blocked address")
	}
	ip = ip.Unmap()
	if !ip.IsGlobalUnicast() || ip.IsPrivate() {
		return errors.New("blocked address")
	}
	for _, p := range blocked {
		if p.Contains(ip) {
			return errors.New("blocked address")
		}
	}
	return nil
}

func fetch(link string, o opts) (result, error) {
	u, err := url.Parse(link)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		return result{}, oops{http.StatusBadRequest, "bad url"}
	}
	req, err := http.NewRequest("GET", u.String(), nil)
	if err != nil {
		return result{}, oops{http.StatusBadRequest, "bad url"}
	}
	req.Header.Set("User-Agent", "share/1")
	res, err := client.Do(req)
	if err != nil {
		return result{}, oops{http.StatusBadGateway, err.Error()}
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return result{}, oops{http.StatusBadGateway, u.Host + ": " + res.Status}
	}
	if t, _, _ := mime.ParseMediaType(res.Header.Get("Content-Type")); t == "text/html" || t == "application/xhtml+xml" {
		return result{}, oops{http.StatusBadRequest, "that link is a web page, not a file"}
	}
	o.name = path.Base(res.Request.URL.Path)
	return store(res.Body, o)
}

func pick(o opts, lock, own bool, pw, dk string) opts {
	if lock {
		o.access = pw
	}
	if own {
		o.del = dk
	}
	return o
}

func upload(w http.ResponseWriter, r *http.Request) {
	_, p, _ := r.BasicAuth()
	ok := authed(r.Header.Get("Linx-Api-Key")) || authed(p) || known(r)
	came := false
	if r.Method == http.MethodPut {
		if !ok {
			http.Error(w, "wrong key", http.StatusUnauthorized)
			return
		}
		exp, _ := strconv.ParseInt(r.Header.Get("Linx-Expiry"), 10, 64)
		res, err := store(r.Body, opts{
			name:   strings.Trim(strings.TrimPrefix(r.URL.Path, "/upload"), "/"),
			random: strings.EqualFold(r.Header.Get("Linx-Randomize"), "yes"),
			expiry: max(exp, 0),
			del:    r.Header.Get("Linx-Delete-Key"),
			access: r.Header.Get("Linx-Access-Key"),
		})
		if fail(w, err) {
			return
		}
		if wantsJSON(r) {
			reply(w, res)
		} else {
			fmt.Fprintln(w, res.URL)
		}
		return
	}
	mr, err := r.MultipartReader()
	if err != nil {
		http.Error(w, "bad form", http.StatusBadRequest)
		return
	}
	o, link, done := opts{}, "", []result{}
	lock, own, pw, dk := false, false, "", ""
	for {
		part, err := mr.NextPart()
		if err == io.EOF {
			break
		}
		if err != nil {
			http.Error(w, "bad form", http.StatusBadRequest)
			return
		}
		v := func() string {
			b, _ := io.ReadAll(io.LimitReader(part, 4096))
			return strings.TrimSpace(string(b))
		}
		switch part.FormName() {
		case "key":
			if authed(v()) {
				ok, came = true, true
			}
		case "random":
			o.random = true
		case "lock":
			lock = true
		case "own":
			own = true
		case "expiry":
			n, _ := strconv.ParseInt(v(), 10, 64)
			o.expiry = max(n, 0)
		case "password":
			pw = v()
		case "delete":
			dk = v()
		case "url":
			link = v()
		case "file":
			if part.FileName() == "" {
				continue
			}
			if !ok {
				http.Error(w, "wrong key", http.StatusUnauthorized)
				return
			}
			o.name = part.FileName()
			res, err := store(part, pick(o, lock, own, pw, dk))
			if fail(w, err) {
				return
			}
			done = append(done, res)
		}
	}
	if link != "" {
		if !ok {
			http.Error(w, "wrong key", http.StatusUnauthorized)
			return
		}
		res, err := fetch(link, pick(o, lock, own, pw, dk))
		if fail(w, err) {
			return
		}
		done = append(done, res)
	}
	if len(done) == 0 {
		http.Error(w, "nothing to upload", http.StatusBadRequest)
		return
	}
	if came {
		remember(w, ticket(), 365*86400)
	}
	if wantsJSON(r) {
		reply(w, done)
	} else {
		show(w, 200, "done", page{Title: "分", Done: done})
	}
}

func view(w http.ResponseWriter, r *http.Request) {
	f, m, err := load(r.PathValue("name"))
	if fail(w, err) {
		return
	}
	p := page{Title: f.Name, F: f}
	if !opened(r, f.Name, m) {
		show(w, 200, "locked", p)
		return
	}
	if !f.Locked {
		p.Abs = site + "raw/" + url.PathEscape(f.Name)
	}
	switch f.Kind {
	case "text", "md":
		if f.size > textMax {
			p.Err = "too big to show"
			break
		}
		b, err := os.ReadFile(at("files", f.Name))
		if fail(w, err) {
			return
		}
		p.Source = r.URL.Query().Has("source")
		p.Code, p.Hidden = mark(string(b))
		if f.Kind == "md" && !p.Source {
			p.HTML = template.HTML(render(string(b)))
			break
		}
		if strings.Count(string(b), "\n") > 20000 {
			p.Err = "too many lines to show"
			break
		}
		p.Text = string(b)
		for i := range strings.Count(strings.TrimSuffix(p.Text, "\n"), "\n") + 1 {
			p.Lines = append(p.Lines, i+1)
		}
	case "archive":
		if p.Entries, err = entries(f.Name); err != nil {
			p.Err = "can't read archive"
		}
	}
	show(w, 200, "view", p)
}

func entries(name string) ([]entry, error) {
	var out []entry
	if strings.EqualFold(ext(name), ".zip") {
		z, err := zip.OpenReader(at("files", name))
		if err != nil {
			return nil, err
		}
		defer z.Close()
		for _, f := range z.File[:min(len(z.File), 1000)] {
			out = append(out, entry{f.Name, size(int64(f.UncompressedSize64))})
		}
		return out, nil
	}
	fh, err := os.Open(at("files", name))
	if err != nil {
		return nil, err
	}
	defer fh.Close()
	var rd io.Reader = fh
	if e := strings.ToLower(ext(name)); e == ".tar.gz" || e == ".tgz" {
		gz, err := gzip.NewReader(fh)
		if err != nil {
			return nil, err
		}
		rd = io.LimitReader(gz, 64<<20)
	}
	tr := tar.NewReader(rd)
	for len(out) < 1000 {
		h, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return out, err
		}
		if n := strings.TrimPrefix(h.Name, "./"); n != "" {
			out = append(out, entry{n, size(h.Size)})
		}
	}
	return out, nil
}

func unlock(w http.ResponseWriter, r *http.Request) {
	f, m, err := load(r.PathValue("name"))
	if fail(w, err) {
		return
	}
	if m.Access == "" || !check(m.Access, r.FormValue("password")) {
		show(w, http.StatusForbidden, "locked", page{Title: f.Name, F: f, Err: "wrong password"})
		return
	}
	http.SetCookie(w, &http.Cookie{Name: cookie(f.Name), Value: pass(m), Path: "/", MaxAge: 7 * 86400, Secure: true, HttpOnly: true, SameSite: http.SameSiteLaxMode})
	http.Redirect(w, r, "/"+url.PathEscape(f.Name), http.StatusSeeOther)
}

func raw(w http.ResponseWriter, r *http.Request) {
	f, m, err := load(r.PathValue("name"))
	if fail(w, err) {
		return
	}
	if !opened(r, f.Name, m) {
		http.Error(w, "locked", http.StatusForbidden)
		return
	}
	fh, err := os.Open(at("files", f.Name))
	if fail(w, err) {
		return
	}
	defer fh.Close()
	h := w.Header()
	h.Set("Content-Type", f.Type)
	if strings.HasPrefix(f.Type, "text/") {
		h.Set("Content-Type", f.Type+"; charset=utf-8")
	}
	h.Set("Content-Security-Policy", rawCSP)
	if f.Kind == "pdf" {
		h.Set("Content-Security-Policy", pdfCSP)
	}
	h.Set("Cache-Control", "no-cache")
	if f.Locked {
		h.Set("Cache-Control", "private, no-cache")
	}
	if m.Sha256 != "" {
		h.Set("ETag", `"`+m.Sha256+`"`)
	}
	how := "inline"
	if f.Kind == "file" || r.URL.Query().Has("download") {
		how = "attachment"
	}
	h.Set("Content-Disposition", mime.FormatMediaType(how, map[string]string{"filename": f.Name}))
	http.ServeContent(w, r, "", f.mod, fh)
}

func remove(w http.ResponseWriter, r *http.Request) {
	f, m, err := load(r.PathValue("name"))
	if fail(w, err) {
		return
	}
	k := r.Header.Get("Linx-Delete-Key")
	if r.Method == http.MethodPost {
		k = r.FormValue("key")
	}
	if m.Delete == "" || !check(m.Delete, k) {
		http.Error(w, "wrong key", http.StatusForbidden)
		return
	}
	if fail(w, drop(f.Name)) {
		return
	}
	if r.Method == http.MethodPost && !wantsJSON(r) {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}
	fmt.Fprintln(w, "deleted")
}

func list(w http.ResponseWriter, r *http.Request) {
	es, err := os.ReadDir(filepath.Join(root, "files"))
	if fail(w, err) {
		return
	}
	p := page{Title: "files", Site: site}
	for _, e := range es {
		if strings.HasPrefix(e.Name(), ".") {
			continue
		}
		f, _, err := load(e.Name())
		if err != nil {
			if !errors.Is(err, fs.ErrNotExist) {
				log.Print(err)
			}
			continue
		}
		p.Files = append(p.Files, f)
	}
	sort.Slice(p.Files, func(a, b int) bool { return p.Files[a].mod.After(p.Files[b].mod) })
	show(w, 200, "list", p)
}

func purge(w http.ResponseWriter, r *http.Request) {
	n := r.PathValue("name")
	if n == "" || clean(n) != n {
		http.Error(w, "bad name", http.StatusBadRequest)
		return
	}
	if !fail(w, drop(n)) {
		http.Redirect(w, r, "/", http.StatusSeeOther)
	}
}

func mark(s string) (template.HTML, bool) {
	var b strings.Builder
	found := false
	for i, r := range s {
		switch {
		case r == '\n' || r == '\t' || (r == '\r' && strings.HasPrefix(s[i+1:], "\n")) || (r == '\uFEFF' && i == 0):
			b.WriteRune(r)
		case r < 32 || r == 127:
			found = true
			b.WriteString(fmt.Sprintf(`<span class="hid" title="U+%04X">^%c</span>`, r, (r+64)%128))
		case unicode.In(r, unicode.Cf, unicode.Zl, unicode.Zp):
			found = true
			b.WriteString(fmt.Sprintf(`<span class="hid">U+%04X</span>`, r))
		default:
			b.WriteString(esc(string(r)))
		}
	}
	return template.HTML(b.String()), found
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
		case m[8] >= 0:
			b.WriteString(ref(g(2) != "", g(4), g(3)))
		case m[10] >= 0:
			b.WriteString("<strong>" + inline(g(5)) + "</strong>")
		case m[12] >= 0:
			b.WriteString("<em>" + inline(g(6)) + "</em>")
		default:
			b.WriteString(`<a href="` + esc(g(7)) + `">` + esc(g(7)) + `</a>`)
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
			b.WriteString(`<li class="i` + strconv.Itoa(min(len(m[1])/2, 3)) + `">` + box + inline(s) + "</li>")
		default:
			start("p")
			b.WriteString(inline(t))
		}
	}
	end()
	return b.String()
}
