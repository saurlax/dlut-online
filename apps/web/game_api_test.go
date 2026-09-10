package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"github.com/go-chi/chi/v5"
	"net/http/httptest"
	"sync"
	"testing"
	"time"
)

func TestAdmissionAndPresence(t *testing.T) {
	g := newGameAPI(gameConfig{endpoint: "enet://game.example.com:8061", serviceToken: "service", adminToken: "admin"})
	now := time.Now()
	g.now = func() time.Time { return now }
	r := chi.NewRouter()
	g.routes(r)
	request := func(method, path, token string, body any) (int, map[string]any) {
		b, _ := json.Marshal(body)
		q := httptest.NewRequest(method, path, bytes.NewReader(b))
		if token != "" {
			q.Header.Set("Authorization", "Bearer "+token)
		}
		w := httptest.NewRecorder()
		r.ServeHTTP(w, q)
		v := map[string]any{}
		_ = json.Unmarshal(w.Body.Bytes(), &v)
		return w.Code, v
	}
	id := "0123456789abcdef0123456789abcdef"
	c, v := request("POST", "/api/v1/game/tickets", "", map[string]any{"id": id, "version": 3})
	if c != 201 {
		t.Fatal(c, v)
	}
	if v["game_server_url"] != "enet://game.example.com:8061" || v["version"] != float64(3) {
		t.Fatal("missing trusted game endpoint", v)
	}
	if _, ok := v["ws_path"]; ok {
		t.Fatal("legacy gateway endpoint")
	}

	ticket := v["ticket"]
	var wg sync.WaitGroup
	results := make(chan int, 2)
	for i := 0; i < 2; i++ {
		wg.Go(func() {
			c, _ := request("POST", "/internal/v1/game/tickets/consume", "service", map[string]any{"ticket": ticket})
			results <- c
		})
	}
	wg.Wait()
	close(results)
	sum := 0
	for c := range results {
		sum += c
	}
	if sum != 601 {
		t.Fatal("ticket not single use", sum)
	}
	if c, _ := request("POST", "/internal/v1/game/tickets/consume", "admin", map[string]any{"ticket": ticket}); c != 401 {
		t.Fatal(c)
	}
	now = now.Add(time.Second)
	_, v = request("POST", "/api/v1/game/tickets", "", map[string]any{"id": id, "version": 3})
	now = now.Add(31 * time.Second)
	if c, _ := request("POST", "/internal/v1/game/tickets/consume", "service", map[string]any{"ticket": v["ticket"]}); c != 401 {
		t.Fatal("expired", c)
	}
	if c, _ := request("POST", "/api/v1/game/tickets", "", map[string]any{"id": id, "version": 3, "campus": "eda"}); c != 400 {
		t.Fatal("campus must not bind ticket")
	}
	_, v = request("GET", "/api/v1/game/online", "", nil)
	if v["status"] != "unavailable" || v["total"] != nil {
		t.Fatal(v)
	}
	_, v = request("POST", "/internal/v1/game/register", "service", map[string]any{"instance_id": "main", "boot_id": "0123456789abcdef"})
	epoch := v["epoch"]
	_, again := request("POST", "/internal/v1/game/register", "service", map[string]any{"instance_id": "main", "boot_id": "0123456789abcdef"})
	if again["epoch"] != epoch {
		t.Fatal("registration not idempotent")
	}
	p := map[string]any{"instance_id": "main", "epoch": epoch, "seq": 0, "players": []any{}}
	if c, _ := request("POST", "/internal/v1/game/presence", "service", p); c != 200 {
		t.Fatal(c)
	}
	_, v = request("GET", "/api/v1/game/online", "", nil)
	if v["total"] != float64(0) || v["status"] != "live" {
		t.Fatal(v)
	}
	if c, _ := request("POST", "/internal/v1/game/presence", "service", p); c != 409 {
		t.Fatal("old sequence accepted")
	}
	now = now.Add(16 * time.Second)
	_, v = request("GET", "/api/v1/game/online", "", nil)
	if v["total"] != nil || v["status"] != "stale" {
		t.Fatal(v)
	}
	if c, _ := request("GET", "/api/v1/admin/game/players", "", nil); c != 401 {
		t.Fatal(c)
	}
	_, v = request("POST", "/internal/v1/game/register", "service", map[string]any{"instance_id": "main", "boot_id": "fedcba9876543210"})
	if v["epoch"] == epoch {
		t.Fatal("epoch reused")
	}
	if c, _ := request("POST", "/internal/v1/game/presence", "service", p); c != 409 {
		t.Fatal("old boot accepted")
	}
	if c, _ := request("POST", "/internal/v1/game/register", "service", map[string]any{"instance_id": "main", "boot_id": "0123456789abcdef"}); c != 409 {
		t.Fatal("retired boot accepted")
	}
}

func TestOriginAndTicketLimits(t *testing.T) {
	g := newGameAPI(gameConfig{})
	r := chi.NewRouter()
	g.routes(r)
	for _, path := range []string{"/api/v1/game/tickets"} {
		method := "POST"
		q := httptest.NewRequest(method, path, nil)
		q.Header.Set("Origin", "https://other.example")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, q)
		if w.Code != 403 {
			t.Fatal(path, w.Code)
		}
	}
	for i := 0; i < 101; i++ {
		b, _ := json.Marshal(map[string]any{"id": fmt.Sprintf("%032x", i), "version": 3})
		q := httptest.NewRequest("POST", "/api/v1/game/tickets", bytes.NewReader(b))
		w := httptest.NewRecorder()
		r.ServeHTTP(w, q)
		want := 201
		if i == 100 {
			want = 429
		}
		if w.Code != want {
			t.Fatal(i, w.Code)
		}
	}
}
