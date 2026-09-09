package main

import (
	"github.com/gorilla/websocket"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func dialPlayer(t *testing.T, server, id, campus string) *websocket.Conn {
	t.Helper()
	c, _, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(server, "http")+"/ws", nil)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.Close() })
	if err = c.WriteJSON(playerMessage{Type: "hello", ID: id, Campus: campus, Position: []float64{0, 0, 0}}); err != nil {
		t.Fatal(err)
	}
	c.SetReadDeadline(time.Now().Add(2 * time.Second))
	var welcome map[string]any
	if err = c.ReadJSON(&welcome); err != nil {
		t.Fatal(err)
	}
	want, _ := guestName(id)
	if welcome["type"] != "welcome" || welcome["id"] != id || welcome["username"] != want {
		t.Fatalf("bad welcome: %v", welcome)
	}
	return c
}
func awaitPlayers(t *testing.T, c *websocket.Conn, check func([]playerState) bool) {
	t.Helper()
	c.SetReadDeadline(time.Now().Add(3 * time.Second))
	for {
		var m struct {
			Type    string        `json:"type"`
			Players []playerState `json:"players"`
		}
		if err := c.ReadJSON(&m); err != nil {
			t.Fatal(err)
		}
		if m.Type == "snapshot" && check(m.Players) {
			return
		}
	}
}
func TestPlayersSyncAndIsolation(t *testing.T) {
	s := httptest.NewServer(router(t.TempDir()))
	defer s.Close()
	a := dialPlayer(t, s.URL, strings.Repeat("a", 32), "lingshui")
	b := dialPlayer(t, s.URL, strings.Repeat("b", 32), "lingshui")
	c := dialPlayer(t, s.URL, strings.Repeat("c", 32), "panjin")
	awaitPlayers(t, a, func(p []playerState) bool { return len(p) == 2 })
	awaitPlayers(t, c, func(p []playerState) bool { return len(p) == 1 && p[0].Campus == "panjin" })
	b.WriteJSON(playerMessage{Type: "state", Position: []float64{12, 1, 4}, Yaw: 1.25})
	awaitPlayers(t, a, func(p []playerState) bool {
		for _, v := range p {
			if v.ID == strings.Repeat("b", 32) && v.Position[0] == 12 && v.Yaw == 1.25 {
				return true
			}
		}
		return false
	})
	b.Close()
	awaitPlayers(t, a, func(p []playerState) bool { return len(p) == 1 })
	dialPlayer(t, s.URL, strings.Repeat("b", 32), "panjin")
	awaitPlayers(t, c, func(p []playerState) bool { return len(p) == 2 })
	replacement := dialPlayer(t, s.URL, strings.Repeat("a", 32), "lingshui")
	a.SetReadDeadline(time.Now().Add(2 * time.Second))
	for {
		_, _, err := a.ReadMessage()
		if err != nil {
			if !websocket.IsCloseError(err, 4001) {
				t.Fatalf("expected replacement close: %v", err)
			}
			break
		}
	}
	awaitPlayers(t, replacement, func(p []playerState) bool { return len(p) == 1 })
}
func TestPlayersRejectInvalidInput(t *testing.T) {
	s := httptest.NewServer(router(t.TempDir()))
	defer s.Close()
	for _, m := range []playerMessage{
		{Type: "hello", ID: "bad", Campus: "lingshui", Position: []float64{0, 0, 0}},
		{Type: "hello", ID: strings.Repeat("a", 32), Campus: "invalid", Position: []float64{0, 0, 0}},
		{Type: "hello", ID: strings.Repeat("a", 32), Campus: "eda", Position: []float64{0, 0}},
		{Type: "hello", ID: strings.Repeat("a", 32), Campus: "eda", Position: []float64{10001, 0, 0}},
	} {
		c, _, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(s.URL, "http")+"/ws", nil)
		if err != nil {
			t.Fatal(err)
		}
		c.WriteJSON(m)
		c.SetReadDeadline(time.Now().Add(time.Second))
		_, _, err = c.ReadMessage()
		c.Close()
		if err == nil {
			t.Fatal("accepted invalid hello")
		}
	}
	for _, payload := range []string{strings.Repeat("x", 2048), `{"type":"state","position":[1e999,0,0]}`, `{"type":"state","position":[0,0,0],"yaw":99}`} {
		c := dialPlayer(t, s.URL, strings.Repeat("d", 32), "eda")
		c.WriteMessage(websocket.TextMessage, []byte(payload))
		c.SetReadDeadline(time.Now().Add(time.Second))
		for {
			_, _, err := c.ReadMessage()
			if err != nil {
				if e, ok := err.(interface{ Timeout() bool }); ok && e.Timeout() {
					t.Fatal("invalid state was not rejected")
				}
				break
			}
		}
	}
	_, response, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(s.URL, "http")+"/ws", http.Header{"Origin": []string{"https://untrusted.example"}})
	if err == nil || response.StatusCode != http.StatusForbidden {
		t.Fatal("accepted foreign origin")
	}
}
