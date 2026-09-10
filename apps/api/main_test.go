package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestDesktopRoutes(t *testing.T) {
	handler := router(gameConfig{})
	for _, path := range []string{"/web", "/web/", "/web/index.wasm", "/ws", "/api/v1/missing", "/assets/missing.js", "/assets/"} {
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, httptest.NewRequest(http.MethodGet, path, nil))
		if w.Code != 404 {
			t.Fatalf("%s: %d", path, w.Code)
		}
	}
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/", nil))
	if w.Code != 200 || !strings.Contains(w.Body.String(), "id=\"app\"") {
		t.Fatal("missing Vue application entry")
	}
}

func TestGameEndpoint(t *testing.T) {
	for _, value := range []string{"enet://localhost:1949", "enets://game.example.com:9000", "enet://[::1]:1949"} {
		if !validGameEndpoint(value) {
			t.Fatal(value)
		}
	}
	for _, value := range []string{"https://host:1949", "enet://host", "enet://host:0", "enet://host:65536", "enet://host:1949/ws", "enet://user:pass@host:1949", "enet://host:1949?x=1"} {
		if validGameEndpoint(value) {
			t.Fatal(value)
		}
	}
}

func TestListenAddress(t *testing.T) {
	for _, tc := range []struct{ port, want string }{
		{"", ":8415"}, {"9090", ":9090"}, {"65535", ":65535"},
	} {
		got, err := listenAddress(tc.port)
		if err != nil || got != tc.want {
			t.Fatalf("PORT=%q: got %q, %v; want %q", tc.port, got, err, tc.want)
		}
	}
	for _, port := range []string{"0", "65536", "-1", "abc", "127.0.0.1:8415"} {
		if _, err := listenAddress(port); err == nil {
			t.Errorf("accepted invalid PORT %q", port)
		}
	}
}

func TestEmbeddedAssets(t *testing.T) {
	entries, err := website.ReadDir("static/assets")
	if err != nil {
		t.Fatal(err)
	}
	handler := router(gameConfig{})
	foundJS := false
	for _, entry := range entries {
		if !strings.HasSuffix(entry.Name(), ".js") {
			continue
		}
		foundJS = true
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/assets/"+entry.Name(), nil))
		if w.Code != 200 || !strings.Contains(w.Header().Get("Content-Type"), "javascript") || !strings.Contains(w.Header().Get("Cache-Control"), "immutable") {
			t.Fatalf("invalid embedded JS response: %d %v", w.Code, w.Header())
		}
	}
	if !foundJS {
		t.Fatal("website JavaScript missing")
	}
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/api/v1/game/online", nil))
	if w.Code != 200 || !strings.Contains(w.Header().Get("Content-Type"), "application/json") {
		t.Fatal("website shadowed API")
	}
}
