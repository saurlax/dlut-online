package main

import (
	"net/http"
	"testing"
)

func apiHandler(api *gameAPI, withSite bool) http.Handler {
	mux := http.NewServeMux()
	for _, route := range api.routes() {
		mux.Handle(route.method+" "+route.path, route.handler)
	}
	if withSite {
		mux.Handle("GET /", siteHandler())
	}
	return mux
}

func testGameAPI(config gameConfig, endpoint string) *gameAPI {
	api := newGameAPI(config)
	if endpoint != "" {
		api.resolveGameEndpoint = func() (string, bool) { return endpoint, true }
	}
	api.resolveAccount = func(token string) (admission, bool) {
		if !validPlayerID(token) {
			return admission{}, false
		}
		return admission{ID: token, Username: "Test player", Kind: "account"}, true
	}
	return api
}

func router(config gameConfig, endpoint string) http.Handler {
	return apiHandler(testGameAPI(config, endpoint), true)
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
			t.Fatalf("API server port %q: got %q, %v; want %q", tc.port, got, err, tc.want)
		}
	}
	for _, port := range []string{"0", "65536", "-1", "abc", "127.0.0.1:8415"} {
		if _, err := listenAddress(port); err == nil {
			t.Errorf("accepted invalid API server port %q", port)
		}
	}
}
