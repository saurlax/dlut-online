package site

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"testing/fstest"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/router"
)

func TestRegisterRejectsIncompleteExport(t *testing.T) {
	for name, files := range map[string]fstest.MapFS{
		"missing":   {},
		"directory": {"index.html/nested.txt": {Data: []byte("invalid")}},
	} {
		t.Run(name, func(t *testing.T) {
			if err := Register(&core.ServeEvent{}, files); err == nil {
				t.Fatal("expected an incomplete frontend to fail before route registration")
			}
		})
	}
}

func TestStaticRoutesPreserveBackendAndMissingPaths(t *testing.T) {
	r := router.NewRouter(func(w http.ResponseWriter, req *http.Request) (*core.RequestEvent, router.EventCleanupFunc) {
		e := &core.RequestEvent{}
		e.Response = w
		e.Request = req
		return e, nil
	})
	r.GET("/api/health", func(e *core.RequestEvent) error { return e.JSON(200, map[string]bool{"healthy": true}) })
	r.GET("/_/{path...}", func(e *core.RequestEvent) error { return e.String(200, "admin") })
	files := fstest.MapFS{
		"index.html":          {Data: []byte("homepage")},
		"404.html":            {Data: []byte("page not found")},
		"guide/index.html":    {Data: []byte("guide")},
		"_next/static/app.js": {Data: []byte("script")},
	}
	if err := Register(&core.ServeEvent{Router: r}, files); err != nil {
		t.Fatal(err)
	}
	mux, err := r.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct {
		path   string
		status int
		body   string
	}{
		{"/", 200, "homepage"},
		{"/guide/", 200, "guide"},
		{"/_next/static/app.js", 200, "script"},
		{"/api/health", 200, "healthy"},
		{"/_/", 200, "admin"},
		{"/missing", 404, "page not found"},
		{"/api/missing", 404, ""},
	} {
		t.Run(tc.path, func(t *testing.T) {
			res := httptest.NewRecorder()
			mux.ServeHTTP(res, httptest.NewRequest(http.MethodGet, tc.path, nil))
			if res.Code != tc.status || !strings.Contains(res.Body.String(), tc.body) {
				t.Fatalf("got status %d body %q", res.Code, res.Body.String())
			}
			if tc.path == "/api/missing" && !strings.HasPrefix(res.Header().Get("Content-Type"), "application/json") {
				t.Fatalf("missing API must return JSON, got %q", res.Header().Get("Content-Type"))
			}
		})
	}
}
