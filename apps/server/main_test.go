package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestWebRoutes(t *testing.T) {
	dir := t.TempDir()
	for name, data := range map[string]string{"index.html": "game", "index.wasm": "wasm"} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(data), 0600); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.Mkdir(filepath.Join(dir, "empty"), 0700); err != nil {
		t.Fatal(err)
	}
	handler := router(dir)
	for _, tc := range []struct {
		path   string
		status int
	}{
		{"/web", 308}, {"/web/", 200}, {"/web/index.wasm", 200},
		{"/web/missing.wasm", 404}, {"/web/empty/", 404}, {"/", 200}, {"/api/v1/missing", 404},
	} {
		t.Run(tc.path, func(t *testing.T) {
			w := httptest.NewRecorder()
			handler.ServeHTTP(w, httptest.NewRequest(http.MethodGet, tc.path, nil))
			if w.Code != tc.status {
				t.Fatalf("status %d, want %d", w.Code, tc.status)
			}
			if tc.path == "/web" && w.Header().Get("Location") != "/web/" {
				t.Fatal("missing slash redirect")
			}
			if tc.path == "/web/" && (w.Body.String() != "game" || w.Header().Get("Cache-Control") != "no-cache") {
				t.Fatal("invalid game response")
			}
			if tc.path == "/web/index.wasm" && w.Header().Get("Content-Type") != "application/wasm" {
				t.Fatal("invalid WASM MIME")
			}
		})
	}
}

func TestListenAddress(t *testing.T) {
	for _, tc := range []struct{ port, want string }{
		{"", ":8060"}, {"9090", ":9090"}, {"65535", ":65535"},
	} {
		got, err := listenAddress(tc.port)
		if err != nil || got != tc.want {
			t.Fatalf("PORT=%q: got %q, %v; want %q", tc.port, got, err, tc.want)
		}
	}
	for _, port := range []string{"0", "65536", "-1", "abc", "127.0.0.1:8060"} {
		if _, err := listenAddress(port); err == nil {
			t.Errorf("accepted invalid PORT %q", port)
		}
	}
}
