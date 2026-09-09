package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/gorilla/websocket"
)

// Opt-in process test: no mocks of game rules, only controlled HTTP failures and network delay.
func TestGodotFaultIsolation(t *testing.T) {
	project := os.Getenv("DO_TEST_GODOT_PROJECT")
	if project == "" {
		t.Skip("set DO_TEST_GODOT_PROJECT")
	}
	project, _ = filepath.Abs(project)
	listener, e := net.Listen("tcp", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	address := listener.Addr().String()
	listener.Close()
	_, port, _ := net.SplitHostPort(address)
	service := randomID()
	admin := randomID()
	g := newGameAPI(gameConfig{upstream: "http://" + address, serviceToken: service, adminToken: admin})
	r := chi.NewRouter()
	g.routes(r)
	var outage atomic.Bool
	api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, q *http.Request) {
		if outage.Load() && strings.HasPrefix(q.URL.Path, "/internal/") {
			http.Error(w, "unavailable", 503)
			return
		}
		r.ServeHTTP(w, q)
	}))
	defer api.Close()
	cmd := exec.Command("godot", "--headless", "--path", project, "scenes/server.tscn")
	cmd.Env = append(os.Environ(), "DO_GAME_PORT="+port, "DO_API_SERVER_URL="+api.URL, "DO_GAME_SERVICE_TOKEN="+service, "DO_GAME_INSTANCE_ID=main")
	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = &output
	if e = cmd.Start(); e != nil {
		t.Fatal(e)
	}
	defer func() {
		cmd.Process.Kill()
		cmd.Wait()
		if t.Failed() {
			t.Log(output.String())
		}
	}()
	for i := 0; i < 100; i++ {
		c, e := net.DialTimeout("tcp", address, 100*time.Millisecond)
		if e == nil {
			c.Close()
			break
		}
		time.Sleep(50 * time.Millisecond)
	}
	c := connectGame(t, api.URL, "abcd0000000000000000000000000001", "panjin")
	awaitMessage(t, c, "welcome")
	outage.Store(true)
	for i := 0; i < 4; i++ {
		c.WriteJSON(map[string]any{"type": "heartbeat"})
		awaitMessage(t, c, "heartbeat")
		time.Sleep(4 * time.Second)
	}
	resp, _ := http.Get(api.URL + "/api/v1/game/online")
	v := map[string]any{}
	json.NewDecoder(resp.Body).Decode(&v)
	resp.Body.Close()
	if v["status"] == "live" {
		t.Fatal("presence stayed live through outage")
	}
	c.WriteJSON(map[string]any{"type": "change_map", "request_id": 1, "campus": "eda"})
	p := awaitMessage(t, c, "map_prepare")
	c.WriteJSON(map[string]any{"type": "map_ready", "transfer_id": p["transfer_id"]})
	awaitMessage(t, c, "map_entered")
	rejected := connectGame(t, api.URL, "abcd0000000000000000000000000002", "panjin")
	rejected.SetReadDeadline(time.Now().Add(5 * time.Second))
	_, _, e = rejected.ReadMessage()
	if !websocket.IsCloseError(e, 4003) {
		t.Fatal("outage admission bypassed", e)
	}
	outage.Store(false)
	for i := 0; i < 15; i++ {
		c.WriteJSON(map[string]any{"type": "heartbeat"})
		awaitMessage(t, c, "heartbeat")
		resp, _ = http.Get(api.URL + "/api/v1/game/online")
		json.NewDecoder(resp.Body).Decode(&v)
		resp.Body.Close()
		if v["status"] == "live" {
			break
		}
		time.Sleep(time.Second)
	}
	if v["status"] != "live" {
		t.Fatal("presence did not recover", v)
	}
	// Simulate Go losing its in-memory registrations while proxy connections survive.
	g.mu.Lock()
	g.epoch = ""
	g.boot = ""
	g.seq = -1
	g.received = time.Time{}
	g.mu.Unlock()
	for i := 0; i < 20; i++ {
		c.WriteJSON(map[string]any{"type": "heartbeat"})
		awaitMessage(t, c, "heartbeat")
		time.Sleep(time.Second)
		g.mu.Lock()
		recovered := g.epoch != "" && !g.received.IsZero()
		g.mu.Unlock()
		if recovered {
			break
		}
		if i == 19 {
			t.Fatal("registration did not recover")
		}
	}
}

func TestGodotClientLatency(t *testing.T) {
	project := os.Getenv("DO_TEST_GODOT_PROJECT")
	if project == "" {
		t.Skip("set DO_TEST_GODOT_PROJECT")
	}
	base := gameURL(t)
	delayed := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/ws" {
			q, e := http.NewRequest(r.Method, base+r.URL.Path, r.Body)
			if e != nil {
				http.Error(w, "request", 500)
				return
			}
			q.Header = r.Header.Clone()
			resp, e := http.DefaultClient.Do(q)
			if e != nil {
				http.Error(w, "upstream", 502)
				return
			}
			defer resp.Body.Close()
			for k, vs := range resp.Header {
				for _, v := range vs {
					w.Header().Add(k, v)
				}
			}
			w.WriteHeader(resp.StatusCode)
			io.Copy(w, resp.Body)
			return
		}
		up := websocket.Upgrader{CheckOrigin: func(*http.Request) bool { return true }}
		client, e := up.Upgrade(w, r, nil)
		if e != nil {
			return
		}
		defer client.Close()
		server, _, e := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(base, "http")+"/ws", nil)
		if e != nil {
			return
		}
		defer server.Close()
		done := make(chan struct{}, 2)
		relay := func(from, to *websocket.Conn) {
			type packet struct {
				k  int
				b  []byte
				at time.Time
			}
			queue := make(chan packet, 128)
			stop := make(chan struct{})
			defer close(stop)
			go func() {
				defer close(queue)
				for {
					k, b, e := from.ReadMessage()
					if e != nil {
						return
					}
					select {
					case queue <- packet{k, b, time.Now().Add(75 * time.Millisecond)}:
					case <-stop:
						return
					}
				}
			}()
			for p := range queue {
				if d := time.Until(p.at); d > 0 {
					time.Sleep(d)
				}
				if to.WriteMessage(p.k, p.b) != nil {
					break
				}
			}
			done <- struct{}{}
		}
		go relay(client, server)
		go relay(server, client)
		<-done
	}))
	defer delayed.Close()
	cmd := exec.Command("godot", "--headless", "--path", project, "--script", "tests/player_network.gd")
	cmd.Env = append(os.Environ(), "DO_SERVER_URL="+delayed.URL)
	output, e := cmd.CombinedOutput()
	if e != nil || !bytes.Contains(output, []byte("PASS:")) {
		t.Fatalf("latency client: %v\n%s", e, output)
	}
	t.Log(string(output))
}
