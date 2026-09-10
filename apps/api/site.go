package main

import (
	"embed"
	"io/fs"
	"net/http"
	"path"
	"strings"
)

// Build apps/web before compiling Go; Vite writes the embedded website here.
//
//go:embed static
var website embed.FS

func siteHandler() http.Handler {
	files, err := fs.Sub(website, "static")
	if err != nil {
		panic(err)
	}
	server := http.FileServer(http.FS(files))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		name := strings.TrimPrefix(r.URL.Path, "/")
		if name == "" || name == "download" || name == "download/" {
			name = "index.html"
			r = r.Clone(r.Context())
			r.URL.Path = "/"
		}
		if !fs.ValidPath(name) || path.Clean(name) != name {
			http.NotFound(w, r)
			return
		}
		info, err := fs.Stat(files, name)
		if err != nil || info.IsDir() {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("X-Content-Type-Options", "nosniff")
		if strings.HasPrefix(name, "assets/") {
			w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
		} else {
			w.Header().Set("Cache-Control", "no-cache")
		}
		server.ServeHTTP(w, r)
	})
}
