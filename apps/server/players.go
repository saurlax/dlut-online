package main

import (
	"encoding/hex"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"strconv"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

type playerState struct {
	ID       string     `json:"id"`
	Username string     `json:"username"`
	Campus   string     `json:"campus"`
	Position [3]float64 `json:"position"`
	Yaw      float64    `json:"yaw"`
}
type playerMessage struct {
	Type     string    `json:"type"`
	ID       string    `json:"id"`
	Campus   string    `json:"campus"`
	Position []float64 `json:"position"`
	Yaw      float64   `json:"yaw"`
}
type playerConnection struct {
	conn     *websocket.Conn
	state    playerState
	replaced chan struct{}
}
type playerHub struct {
	mu      sync.Mutex
	players map[string]*playerConnection
}

func newPlayerHub() *playerHub { return &playerHub{players: make(map[string]*playerConnection)} }
func validPosition(m playerMessage) bool {
	if len(m.Position) != 3 || math.IsNaN(m.Yaw) || math.IsInf(m.Yaw, 0) || math.Abs(m.Yaw) > math.Pi*2 {
		return false
	}
	for _, v := range m.Position {
		if math.IsNaN(v) || math.IsInf(v, 0) || math.Abs(v) > 10000 {
			return false
		}
	}
	return true
}
func guestName(id string) (string, bool) {
	if len(id) != 32 {
		return "", false
	}
	b, err := hex.DecodeString(id)
	if err != nil || hex.EncodeToString(b) != id {
		return "", false
	}
	n, _ := strconv.ParseUint(id[:8], 16, 32)
	return fmt.Sprintf("游客%06d", n%1000000), true
}
func (h *playerHub) snapshot(campus string) []playerState {
	h.mu.Lock()
	defer h.mu.Unlock()
	states := make([]playerState, 0)
	for _, p := range h.players {
		if p.state.Campus == campus {
			states = append(states, p.state)
		}
	}
	return states
}
func (h *playerHub) serve(w http.ResponseWriter, r *http.Request) {
	upgrader := websocket.Upgrader{CheckOrigin: func(r *http.Request) bool {
		origin := r.Header.Get("Origin")
		if origin == "" {
			return true
		}
		u, err := url.Parse(origin)
		return err == nil && (u.Scheme == "http" || u.Scheme == "https") && u.Host == r.Host && u.User == nil && u.RawQuery == "" && u.Fragment == "" && u.Path == ""
	}}
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()
	conn.SetReadLimit(1024)
	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	var hello playerMessage
	if conn.ReadJSON(&hello) != nil {
		return
	}
	username, valid := guestName(hello.ID)
	if !valid || hello.Type != "hello" || !validPosition(hello) || (hello.Campus != "lingshui" && hello.Campus != "eda" && hello.Campus != "panjin") {
		return
	}
	p := &playerConnection{conn: conn, state: playerState{ID: hello.ID, Username: username, Campus: hello.Campus, Position: [3]float64(hello.Position), Yaw: hello.Yaw}, replaced: make(chan struct{})}
	h.mu.Lock()
	if old := h.players[hello.ID]; old != nil {
		close(old.replaced)
	}
	h.players[hello.ID] = p
	h.mu.Unlock()
	defer func() {
		h.mu.Lock()
		if h.players[hello.ID] == p {
			delete(h.players, hello.ID)
		}
		h.mu.Unlock()
	}()
	write := func(value any) error {
		conn.SetWriteDeadline(time.Now().Add(3 * time.Second))
		return conn.WriteJSON(value)
	}
	if write(map[string]any{"type": "welcome", "id": hello.ID, "username": username}) != nil {
		return
	}
	done := make(chan struct{})
	go func() {
		defer close(done)
		window := time.Now()
		count := 0
		for {
			conn.SetReadDeadline(time.Now().Add(15 * time.Second))
			var message playerMessage
			if conn.ReadJSON(&message) != nil {
				return
			}
			if time.Since(window) >= time.Second {
				window = time.Now()
				count = 0
			}
			count++
			if count > 40 || message.Type != "state" || !validPosition(message) {
				return
			}
			h.mu.Lock()
			p.state.Position = [3]float64(message.Position)
			p.state.Yaw = message.Yaw
			h.mu.Unlock()
		}
	}()
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case <-done:
			return
		case <-p.replaced:
			conn.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(4001, "session replaced"), time.Now().Add(time.Second))
			return
		case <-ticker.C:
			if write(map[string]any{"type": "snapshot", "players": h.snapshot(hello.Campus)}) != nil {
				return
			}
		}
	}
}
