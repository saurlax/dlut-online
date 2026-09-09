package main

import (
	"flag"
	"fmt"
	"log/slog"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
)

func router(webDir string) http.Handler {
	r := chi.NewRouter()
	r.Get("/ws", newPlayerHub().serve)
	r.Get("/web", func(w http.ResponseWriter, req *http.Request) {
		http.Redirect(w, req, "/web/", http.StatusPermanentRedirect)
	})
	files := http.StripPrefix("/web", http.FileServer(http.Dir(webDir)))
	r.Handle("/web/*", http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		if req.Method != http.MethodGet && req.Method != http.MethodHead {
			w.Header().Set("Allow", "GET, HEAD")
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		// Export filenames are stable across builds; revalidate to avoid stale clients.
		w.Header().Set("Cache-Control", "no-cache")
		rel := strings.TrimPrefix(req.URL.Path, "/web/")
		target := filepath.Join(webDir, filepath.FromSlash(rel))
		if info, err := os.Stat(target); err == nil && info.IsDir() {
			if _, err := os.Stat(filepath.Join(target, "index.html")); err != nil {
				http.NotFound(w, req)
				return
			}
		}
		files.ServeHTTP(w, req)
	}))
	return r
}

func listenAddress(port string) (string, error) {
	if port == "" {
		port = "8060"
	}
	n, err := strconv.Atoi(port)
	if err != nil || n < 1 || n > 65535 {
		return "", fmt.Errorf("invalid PORT %q: expected 1-65535", port)
	}
	return ":" + strconv.Itoa(n), nil
}

func main() {
	addr := flag.String("addr", "", "HTTP listen address (overrides PORT)")
	webDir := flag.String("web-dir", "../client/build/web", "Godot Web export directory")
	flag.Parse()
	if *addr == "" {
		var err error
		*addr, err = listenAddress(os.Getenv("PORT"))
		if err != nil {
			slog.Error("Invalid listener configuration", "error", err)
			os.Exit(1)
		}
	}
	info, err := os.Stat(filepath.Join(*webDir, "index.html"))
	if err != nil || info.IsDir() {
		slog.Error("Godot Web export missing", "directory", *webDir)
		os.Exit(1)
	}
	_ = mime.AddExtensionType(".wasm", "application/wasm")
	server := &http.Server{Addr: *addr, Handler: router(*webDir), ReadHeaderTimeout: 5 * time.Second, IdleTimeout: 60 * time.Second}
	slog.Info("DLUT Online HTTP server", "address", *addr, "game", "/web/", "resources", *webDir)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		slog.Error("HTTP server stopped", "error", err)
		os.Exit(1)
	}
}
