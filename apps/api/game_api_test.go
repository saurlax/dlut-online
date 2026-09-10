package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"sync"
	"testing"
	"time"
)

func TestAdmissionAndPresence(t *testing.T) {
	g := testGameAPI(gameConfig{apiKey: "service"}, "enet://game.example.com:1949")
	now := time.Now()
	g.now = func() time.Time { return now }
	r := apiHandler(g, false)
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
	id := "0123456789abcde"
	c, v := request("POST", "/api/v1/game/tickets", id, map[string]any{"id": id, "version": 4})
	if c != 201 {
		t.Fatal(c, v)
	}
	if v["game_server_url"] != "enet://game.example.com:1949" || v["version"] != float64(4) {
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
			c, _ := request("POST", "/api/v1/game/tickets/consume", "service", map[string]any{"ticket": ticket})
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
	if c, _ := request("POST", "/api/v1/game/tickets/consume", "wrong", map[string]any{"ticket": ticket}); c != 401 {
		t.Fatal(c)
	}
	now = now.Add(time.Second)
	_, v = request("POST", "/api/v1/game/tickets", id, map[string]any{"id": id, "version": 4})
	now = now.Add(31 * time.Second)
	if c, _ := request("POST", "/api/v1/game/tickets/consume", "service", map[string]any{"ticket": v["ticket"]}); c != 401 {
		t.Fatal("expired", c)
	}
	if c, _ := request("POST", "/api/v1/game/tickets", id, map[string]any{"id": id, "version": 4, "campus": "eda"}); c != 400 {
		t.Fatal("campus must not bind ticket")
	}
	_, v = request("GET", "/api/v1/game/online", "", nil)
	if v["status"] != "unavailable" || v["total"] != nil {
		t.Fatal(v)
	}
	_, v = request("POST", "/api/v1/game/register", "service", map[string]any{"instance_id": "main", "boot_id": "0123456789abcdef"})
	epoch := v["epoch"]
	_, again := request("POST", "/api/v1/game/register", "service", map[string]any{"instance_id": "main", "boot_id": "0123456789abcdef"})
	if again["epoch"] != epoch {
		t.Fatal("registration not idempotent")
	}
	p := map[string]any{"instance_id": "main", "epoch": epoch, "seq": 0, "players": []any{}}
	if c, _ := request("POST", "/api/v1/game/presence", "service", p); c != 200 {
		t.Fatal(c)
	}
	_, v = request("GET", "/api/v1/game/online", "", nil)
	if v["total"] != float64(0) || v["status"] != "live" {
		t.Fatal(v)
	}
	if c, _ := request("POST", "/api/v1/game/presence", "service", p); c != 409 {
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
	_, v = request("POST", "/api/v1/game/register", "service", map[string]any{"instance_id": "main", "boot_id": "fedcba9876543210"})
	if v["epoch"] == epoch {
		t.Fatal("epoch reused")
	}
	if c, _ := request("POST", "/api/v1/game/presence", "service", p); c != 409 {
		t.Fatal("old boot accepted")
	}
	if c, _ := request("POST", "/api/v1/game/register", "service", map[string]any{"instance_id": "main", "boot_id": "0123456789abcdef"}); c != 409 {
		t.Fatal("retired boot accepted")
	}
}

func TestOriginAndTicketLimits(t *testing.T) {
	g := testGameAPI(gameConfig{}, "enet://game.example.com:1949")
	r := apiHandler(g, false)
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
		b, _ := json.Marshal(map[string]any{"id": fmt.Sprintf("%015x", i), "version": 4})
		q := httptest.NewRequest("POST", "/api/v1/game/tickets", bytes.NewReader(b))
		q.Header.Set("Authorization", "Bearer "+fmt.Sprintf("%015x", i))
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

func TestAccountTicketUsesResolvedIdentity(t *testing.T) {
	g := testGameAPI(gameConfig{apiKey: "service"}, "enet://game.example.com:1949")
	g.resolveAccount = func(token string) (admission, bool) {
		if token != "valid" {
			return admission{}, false
		}
		return admission{ID: "account12345678", Username: "王同学", Kind: "account"}, true
	}
	r := apiHandler(g, false)
	body, _ := json.Marshal(map[string]any{"id": "forged12345678", "version": 4})
	req := httptest.NewRequest("POST", "/api/v1/game/tickets", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer valid")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != 201 {
		t.Fatal(w.Code, w.Body.String())
	}
	issued := map[string]any{}
	_ = json.Unmarshal(w.Body.Bytes(), &issued)
	consumeBody, _ := json.Marshal(map[string]any{"ticket": issued["ticket"]})
	consume := httptest.NewRequest("POST", "/api/v1/game/tickets/consume", bytes.NewReader(consumeBody))
	consume.Header.Set("Authorization", "Bearer "+g.config.apiKey)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, consume)
	identity := map[string]any{}
	_ = json.Unmarshal(w.Body.Bytes(), &identity)
	if identity["id"] != "account12345678" || identity["username"] != "王同学" || identity["kind"] != "account" {
		t.Fatal(identity)
	}

	req = httptest.NewRequest("POST", "/api/v1/game/tickets", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer invalid")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != 401 {
		t.Fatal(w.Code)
	}
}
