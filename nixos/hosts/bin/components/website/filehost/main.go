package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"html/template"
	"io/fs"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"time"
)

const siteURL = "https://share.1f2t.org/"

var (
	filesDir = filepath.Join(os.Getenv("LINX_DIR"), "files")
	metaDir  = filepath.Join(os.Getenv("LINX_DIR"), "meta")
)

type file struct {
	Name, Path, Size, Type string
	mod                    time.Time
}

var page = template.Must(template.New("").Parse(`<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>分</title>
<link rel="stylesheet" href="/assets/style.css">
<script src="/assets/theme.js"></script>
<style>
td.d { width: 1%; padding-left: 1.2rem; }
form { display: inline; margin: 0; }
button { border: 0; padding: 0; min-height: 0; background: none; color: var(--dim); font-size: .85em; }
button:hover { color: var(--err); }
</style>
</head>
<body>
<main class="wrap">
<h1>files</h1>
{{if .}}<table><tbody>{{range .}}<tr>
<td><a href="` + siteURL + `{{.Path}}">{{.Name}}</a></td>
<td class="d">{{.Size}}</td>
<td class="d">{{.Type}}</td>
<td class="d"><form method="post" action="/d/{{.Path}}"><button onclick="return confirm('delete {{.Name}}?')">delete</button></form></td>
</tr>{{end}}</tbody></table>{{else}}<p class="muted">no files uploaded yet.</p>{{end}}
</main>
</body>
</html>
`))

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

func list() ([]file, error) {
	entries, err := os.ReadDir(filesDir)
	if err != nil {
		return nil, err
	}
	var out []file
	for _, e := range entries {
		if !e.Type().IsRegular() {
			continue
		}
		info, err := e.Info()
		if err != nil {
			return nil, err
		}
		f := file{Name: e.Name(), Path: url.PathEscape(e.Name()), Size: size(info.Size()), Type: "-", mod: info.ModTime()}
		if b, err := os.ReadFile(filepath.Join(metaDir, e.Name()+".json")); err == nil {
			var m struct{ Mimetype string }
			if json.Unmarshal(b, &m) == nil && m.Mimetype != "" {
				f.Type = m.Mimetype
			}
		} else if !errors.Is(err, fs.ErrNotExist) {
			return nil, err
		}
		out = append(out, f)
	}
	sort.Slice(out, func(a, b int) bool { return out[a].mod.After(out[b].mod) })
	return out, nil
}

func fail(w http.ResponseWriter, err error) {
	log.Print(err)
	http.Error(w, err.Error(), http.StatusInternalServerError)
}

func main() {
	http.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		files, err := list()
		if err != nil {
			fail(w, err)
			return
		}
		if err := page.Execute(w, files); err != nil {
			log.Print(err)
		}
	})
	http.HandleFunc("POST /d/{name}", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Sec-Fetch-Site") == "cross-site" {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		name := r.PathValue("name")
		if name == "" || name == "." || name == ".." || filepath.Base(name) != name {
			http.Error(w, "bad name", http.StatusBadRequest)
			return
		}
		for _, p := range []string{filepath.Join(filesDir, name), filepath.Join(metaDir, name+".json")} {
			if err := os.Remove(p); err != nil && !errors.Is(err, fs.ErrNotExist) {
				fail(w, err)
				return
			}
		}
		http.Redirect(w, r, "/", http.StatusSeeOther)
	})
	log.Fatal(http.ListenAndServe(os.Getenv("FILEHOST_ADDR"), nil))
}
