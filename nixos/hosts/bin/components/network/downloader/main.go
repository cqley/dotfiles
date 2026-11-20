package main

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"slices"
	"sort"
	"strings"
	"sync/atomic"
	"time"
)

//go:embed page.html
var page []byte

var (
	home    = env("DOWNLOADER_HOME", "/var/lib/navidrome")
	music   = home + "/music"
	temp    = home + "/tmp"
	sources = map[string][]string{
		"youtube":    {"youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be"},
		"spotify":    {"open.spotify.com"},
		"soundcloud": {"soundcloud.com", "www.soundcloud.com", "m.soundcloud.com", "on.soundcloud.com"},
	}
	spotify = regexp.MustCompile(`^/(intl-[a-z]{2}(-[a-z]{2})?/)?(track|album|playlist|artist)/[A-Za-z0-9]+/?$`)
	busy    atomic.Bool
)

func env(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

func check(raw string) (string, string, bool) {
	if len(raw) > 2048 {
		return "", "", false
	}
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil || (u.Scheme != "https" && u.Scheme != "http") || u.User != nil || u.Port() != "" || u.Opaque != "" {
		return "", "", false
	}
	host := strings.ToLower(u.Hostname())
	for s, hosts := range sources {
		if !slices.Contains(hosts, host) {
			continue
		}
		if s == "spotify" && !spotify.MatchString(u.Path) {
			return "", "", false
		}
		u.Scheme, u.Host, u.Fragment, u.RawFragment = "https", host, "", ""
		return s, u.String(), true
	}
	return "", "", false
}

func command(source, link, kind, out string) *exec.Cmd {
	if source == "spotify" {
		return exec.Command("spotdl", "download", link, "--output", out, "--format", "mp3")
	}
	args := []string{"-x", "--audio-format", "mp3", "--embed-metadata", "--embed-thumbnail", "-o", "%(title)s.%(ext)s", "-P", out}
	if kind == "song" {
		args = append(args, "--no-playlist")
	}
	return exec.Command("yt-dlp", append(args, "--", link)...)
}

func run(c *exec.Cmd, dir string) (bool, string) {
	c.Dir = dir
	out, err := c.CombinedOutput()
	if err != nil {
		log.Printf("%s: %v", c.Path, err)
		if _, ok := err.(*exec.ExitError); !ok {
			out = append(out, err.Error()...)
		}
	}
	return err == nil, string(out)
}

func reply(w http.ResponseWriter, code int, text string) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(code)
	io.WriteString(w, text)
}

func clean() error {
	if err := os.MkdirAll(temp, 0o750); err != nil {
		return err
	}
	es, err := os.ReadDir(temp)
	if err != nil {
		return err
	}
	for _, e := range es {
		p := filepath.Join(temp, e.Name())
		if i, err := os.Stat(p); err == nil && time.Since(i.ModTime()) > time.Hour {
			if err := os.RemoveAll(p); err != nil {
				log.Print(err)
			}
		}
	}
	return nil
}

func attachment(name string) string {
	var a, b strings.Builder
	for _, r := range name {
		if r < 0x20 || r > 0x7e || r == '"' || r == '\\' {
			a.WriteByte('_')
		} else {
			a.WriteRune(r)
		}
	}
	for _, c := range []byte(name) {
		if c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || strings.IndexByte("-._~", c) >= 0 {
			b.WriteByte(c)
		} else {
			fmt.Fprintf(&b, "%%%02X", c)
		}
	}
	return `attachment; filename="` + a.String() + `"; filename*=UTF-8''` + b.String()
}

func device(w http.ResponseWriter, source, link, kind string) error {
	if err := clean(); err != nil {
		return err
	}
	tmp, err := os.MkdirTemp(temp, "")
	if err != nil {
		return err
	}
	defer func() {
		if err := os.RemoveAll(tmp); err != nil {
			log.Print(err)
		}
	}()
	out := filepath.Join(tmp, "out")
	if err := os.Mkdir(out, 0o750); err != nil {
		return err
	}
	_, logs := run(command(source, link, kind, out), tmp)
	es, err := os.ReadDir(out)
	if err != nil {
		return err
	}
	var files []string
	for _, e := range es {
		if e.Type().IsRegular() && strings.HasSuffix(e.Name(), ".mp3") {
			files = append(files, filepath.Join(out, e.Name()))
		}
	}
	sort.Strings(files)
	if len(files) == 0 {
		reply(w, 422, "error\n\n"+logs)
		return nil
	}
	path, name, mime := files[0], filepath.Base(files[0]), "audio/mpeg"
	if len(files) > 1 {
		path, name, mime = filepath.Join(tmp, "music.zip"), "music.zip", "application/zip"
		if ok, zl := run(exec.Command("zip", append([]string{"-0", "-j", "-q", path}, files...)...), tmp); !ok {
			reply(w, 500, "error\n\n"+zl)
			return nil
		}
	}
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	i, err := f.Stat()
	if err != nil {
		return err
	}
	w.Header().Set("Content-Type", mime)
	w.Header().Set("Content-Length", fmt.Sprint(i.Size()))
	w.Header().Set("Content-Disposition", attachment(name))
	if _, err := io.Copy(w, f); err != nil {
		log.Printf("send %s: %v", name, err)
	}
	return nil
}

func download(w http.ResponseWriter, r *http.Request) {
	if r.ContentLength > 4096 {
		reply(w, 413, "error\n\nrequest too large")
		return
	}
	var body struct{ URL, Type, Dest string }
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&body); err != nil {
		reply(w, 400, "error\n\ninvalid request")
		return
	}
	source, link, ok := check(body.URL)
	if !ok {
		reply(w, 400, "error\n\nonly youtube, spotify and soundcloud links are allowed")
		return
	}
	kind := "song"
	if body.Type == "playlist" {
		kind = "playlist"
	}
	if !busy.CompareAndSwap(false, true) {
		reply(w, 429, "error\n\nanother download is running, try again in a bit")
		return
	}
	defer busy.Store(false)
	if body.Dest == "device" {
		if err := device(w, source, link, kind); err != nil {
			log.Print(err)
			reply(w, 500, "error\n\n"+err.Error())
		}
		return
	}
	ok, logs := run(command(source, link, kind, music), home)
	if ok {
		reply(w, 200, "success\n\n"+logs)
	} else {
		reply(w, 422, "error\n\n"+logs)
	}
}

func main() {
	l, err := net.FileListener(os.NewFile(3, "downloader.sock"))
	if err != nil {
		log.Fatal(err)
	}
	m := http.NewServeMux()
	m.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Write(page)
	})
	m.HandleFunc("POST /dl", download)
	m.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) { reply(w, 404, "not found") })
	c := http.NewCrossOriginProtection()
	for _, o := range strings.Fields(os.Getenv("DOWNLOADER_ORIGINS")) {
		if err := c.AddTrustedOrigin(o); err != nil {
			log.Fatal(err)
		}
	}
	log.Fatal(http.Serve(l, c.Handler(m)))
}
