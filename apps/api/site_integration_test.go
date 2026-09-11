//go:build integration

package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestDesktopRoutes(t *testing.T) {
	handler := router(gameConfig{}, "")
	for _, path := range []string{"/web", "/web/", "/web/index.wasm", "/ws", "/api/v1/missing", "/assets/missing.js", "/assets/"} {
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, httptest.NewRequest(http.MethodGet, path, nil))
		if w.Code != 404 {
			t.Fatalf("%s: %d", path, w.Code)
		}
	}
	for _, path := range []string{"/", "/download", "/download/", "/login", "/register", "/login/", "/register/", "/profile", "/profile/"} {
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, httptest.NewRequest(http.MethodGet, path, nil))
		if w.Code != 200 || !strings.Contains(w.Body.String(), "id=\"app\"") {
			t.Fatalf("%s: missing Vue application entry, status %d", path, w.Code)
		}
	}
}

func TestEmbeddedAssets(t *testing.T) {
	entries, err := website.ReadDir("static/assets")
	if err != nil {
		t.Fatal(err)
	}
	handler := router(gameConfig{}, "")
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
