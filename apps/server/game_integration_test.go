package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"github.com/gorilla/websocket"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func gameURL(t *testing.T) string {
	t.Helper()
	s := os.Getenv("DO_TEST_SERVER_URL")
	if s == "" {
		t.Skip("set DO_TEST_SERVER_URL to the running Go + Godot stack")
	}
	return s
}
func connectGame(t *testing.T, base, id, campus string) *websocket.Conn {
	t.Helper()
	b, _ := json.Marshal(map[string]any{"id": id, "version": 2})
	r, e := http.Post(base+"/api/v1/game/tickets", "application/json", bytes.NewReader(b))
	if e != nil {
		t.Fatal(e)
	}
	defer r.Body.Close()
	v := map[string]any{}
	_ = json.NewDecoder(r.Body).Decode(&v)
	if r.StatusCode != 201 {
		t.Fatal(r.StatusCode, v)
	}
	c, _, e := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(base, "http")+"/ws", nil)
	if e != nil {
		t.Fatal(e)
	}
	t.Cleanup(func() { c.Close() })
	c.WriteJSON(map[string]any{"type": "hello", "version": 2, "ticket": v["ticket"], "campus": campus})
	return c
}
func awaitMessage(t *testing.T, c *websocket.Conn, kind string) map[string]any {
	t.Helper()
	c.SetReadDeadline(time.Now().Add(8 * time.Second))
	for {
		v := map[string]any{}
		if e := c.ReadJSON(&v); e != nil {
			t.Fatal(e)
		}
		if v["type"] == kind {
			return v
		}
	}
}
func TestGameProtocol(t *testing.T) {
	base := gameURL(t)
	c := connectGame(t, base, "deaf0000000000000000000000000001", "panjin")
	w := awaitMessage(t, c, "welcome")
	epoch := w["map_epoch"]
	admission := w["admission_id"]
	c.WriteJSON(map[string]any{"type": "change_map", "request_id": 1, "campus": "eda"})
	p := awaitMessage(t, c, "map_prepare")
	c.WriteJSON(map[string]any{"type": "change_map", "request_id": 2, "campus": "lingshui"})
	if e := awaitMessage(t, c, "map_error"); e["error"] != "busy" {
		t.Fatal(e)
	}
	c.WriteJSON(map[string]any{"type": "map_ready", "transfer_id": p["transfer_id"]})
	entered := awaitMessage(t, c, "map_entered")
	if entered["campus"] != "eda" || entered["map_epoch"] == epoch {
		t.Fatal(entered)
	}
	c.WriteJSON(map[string]any{"type": "map_cancel", "transfer_id": p["transfer_id"]})
	again := awaitMessage(t, c, "map_entered")
	if again["map_epoch"] != entered["map_epoch"] {
		t.Fatal("late cancellation changed epoch")
	}
	c.WriteJSON(map[string]any{"type": "change_map", "request_id": 3, "campus": "panjin"})
	p = awaitMessage(t, c, "map_prepare")
	c.WriteJSON(map[string]any{"type": "map_cancel", "transfer_id": p["transfer_id"]})
	cancel := awaitMessage(t, c, "map_cancelled")
	if cancel["campus"] != "eda" {
		t.Fatal(cancel)
	}
	c.WriteJSON(map[string]any{"type": "map_resume", "transfer_id": p["transfer_id"]})
	awaitMessage(t, c, "map_cancelled")
	if admission == nil {
		t.Fatal("missing admission")
	}
	// A replaced connection must terminate; it cannot remove its successor.
	time.Sleep(time.Second)
	replacement := connectGame(t, base, "deaf0000000000000000000000000001", "panjin")
	awaitMessage(t, replacement, "welcome")
	c.SetReadDeadline(time.Now().Add(5 * time.Second))
	for {
		_, _, e := c.ReadMessage()
		if e != nil {
			if !websocket.IsCloseError(e, 4001) {
				t.Fatal(e)
			}
			break
		}
	}
	replacement.WriteJSON(map[string]any{"type": "state", "position": []int{0, 0, 0}})
	replacement.SetReadDeadline(time.Now().Add(5 * time.Second))
	for {
		_, _, e := replacement.ReadMessage()
		if e != nil {
			if !websocket.IsCloseError(e, 4002) {
				t.Fatal(e)
			}
			break
		}
	}
}
func TestGameLoad(t *testing.T) {
	base := gameURL(t)
	seconds, _ := strconv.Atoi(os.Getenv("DO_TEST_LOAD_SECONDS"))
	if seconds == 0 {
		t.Skip("set DO_TEST_LOAD_SECONDS for sustained 50-player test")
	}
	peers := make([]*websocket.Conn, 50)
	epochs := make([]any, 50)
	for i := range peers {
		peers[i] = connectGame(t, base, fmt.Sprintf("%032x", 0xf000+i), "lingshui")
		epochs[i] = awaitMessage(t, peers[i], "welcome")["map_epoch"]
	}
	var receivedBytes atomic.Int64
	var wg sync.WaitGroup
	errCh := make(chan error, 100)
	done := make(chan struct{})
	for i, c := range peers {
		wg.Add(2)
		go func(c *websocket.Conn) {
			defer wg.Done()
			for {
				c.SetReadDeadline(time.Now().Add(20 * time.Second))
				_, payload, e := c.ReadMessage()
				receivedBytes.Add(int64(len(payload)))
				if e != nil {
					select {
					case <-done:
						return
					default:
						errCh <- e
						return
					}
				}
			}
		}(c)
		go func(i int, c *websocket.Conn) {
			defer wg.Done()
			ticker := time.NewTicker(100 * time.Millisecond)
			defer ticker.Stop()
			seq := 0
			for {
				select {
				case <-done:
					return
				case <-ticker.C:
					seq++
					axis := 1
					if seq%100 >= 50 {
						axis = -1
					}
					if e := c.WriteJSON(map[string]any{"type": "input", "seq": seq, "axis": []int{axis, 0}, "yaw": 0, "run": false, "jump": 0, "map_epoch": epochs[i]}); e != nil {
						errCh <- e
						return
					}
				}
			}
		}(i, c)
	}
	timer := time.NewTimer(time.Duration(seconds) * time.Second)
	defer timer.Stop()
	select {
	case e := <-errCh:
		t.Error(e)
	case <-timer.C:
	}
	t.Logf("received JSON payload: %.2f Mbps across 50 clients", float64(receivedBytes.Load())*8/float64(seconds)/1e6)
	close(done)
	for _, c := range peers {
		c.Close()
	}
	wg.Wait()
	if len(errCh) > 0 {
		t.Error(<-errCh)
	}
}

func TestGameFullCapacity(t *testing.T) {
	if os.Getenv("DO_TEST_CAPACITY") != "1" {
		t.Skip("run during the 50-player load")
	}
	base := gameURL(t)
	c := connectGame(t, base, "dead0000000000000000000000000000", "panjin")
	c.SetReadDeadline(time.Now().Add(5 * time.Second))
	_, _, e := c.ReadMessage()
	if !websocket.IsCloseError(e, 4004) {
		t.Fatal("expected full", e)
	}
}

func TestGameMapTimeout(t *testing.T) {
	if os.Getenv("DO_TEST_MAP_TIMEOUT") != "1" {
		t.Skip("180-second map timeout check")
	}
	base := gameURL(t)
	c := connectGame(t, base, "bada0000000000000000000000000001", "eda")
	awaitMessage(t, c, "welcome")
	c.WriteJSON(map[string]any{"type": "change_map", "request_id": 1, "campus": "panjin"})
	p := awaitMessage(t, c, "map_prepare")
	for i := 0; i < 37; i++ {
		c.WriteJSON(map[string]any{"type": "heartbeat"})
		awaitMessage(t, c, "heartbeat")
		time.Sleep(5 * time.Second)
	}
	c.WriteJSON(map[string]any{"type": "map_status", "transfer_id": p["transfer_id"]})
	m := awaitMessage(t, c, "map_cancelled")
	if m["campus"] != "eda" {
		t.Fatal(m)
	}
	c.WriteJSON(map[string]any{"type": "map_ready", "transfer_id": p["transfer_id"]})
	m = awaitMessage(t, c, "map_cancelled")
	if m["campus"] != "eda" {
		t.Fatal("late ready moved player")
	}
	c.WriteJSON(map[string]any{"type": "map_resume", "transfer_id": p["transfer_id"]})
	awaitMessage(t, c, "map_cancelled")
}

func TestGameSlowConnection(t *testing.T) {
	if os.Getenv("DO_TEST_SLOW") != "1" {
		t.Skip("requires empty game instance")
	}
	base := gameURL(t)
	peers := make([]*websocket.Conn, 50)
	for i := range peers {
		peers[i] = connectGame(t, base, fmt.Sprintf("%032x", 0xaa000+i), "eda")
		awaitMessage(t, peers[i], "welcome")
	}
	if tcp, ok := peers[0].UnderlyingConn().(interface{ SetReadBuffer(int) error }); ok {
		tcp.SetReadBuffer(1024)
	}
	var count atomic.Int64
	var snapshots atomic.Int64
	count.Store(50)
	done := make(chan struct{})
	var wg sync.WaitGroup
	for i, c := range peers {
		if i == 0 {
			continue
		}
		wg.Add(1)
		go func(c *websocket.Conn) {
			defer wg.Done()
			for {
				v := map[string]any{}
				if c.ReadJSON(&v) != nil {
					return
				}
				if v["type"] == "snapshot" {
					count.Store(int64(len(v["players"].([]any))))
					snapshots.Add(1)
				}
			}
		}(c)
	}
	for i, c := range peers {
		wg.Add(1)
		go func(i int, c *websocket.Conn) {
			defer wg.Done()
			ticker := time.NewTicker(time.Second)
			defer ticker.Stop()
			for {
				select {
				case <-done:
					return
				case <-ticker.C:
					if c.WriteJSON(map[string]any{"type": "heartbeat"}) != nil {
						return
					}
				}
			}
		}(i, c)
	}
	deadline := time.Now().Add(30 * time.Second)
	for time.Now().Before(deadline) && count.Load() == 50 {
		time.Sleep(time.Second)
	}
	if count.Load() < 49 || snapshots.Load() < 1000 {
		t.Errorf("slow peer stalled healthy connections: %d players, %d snapshots", count.Load(), snapshots.Load())
	}
	close(done)
	for _, c := range peers {
		c.Close()
	}
	wg.Wait()
}
