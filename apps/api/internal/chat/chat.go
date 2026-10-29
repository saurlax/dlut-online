package chat

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	"github.com/saurlax/dlut-online/apps/api/internal/guest"
)

type Event struct {
	Type string `json:"type"`
	Name string `json:"name"`
	Text string `json:"text,omitempty"`
}
type client struct {
	user   string
	name   string
	events chan Event
}
type Hub struct {
	mu      sync.Mutex
	clients map[*client]bool
	last    map[string]time.Time
}

func (h *Hub) broadcast(e Event) {
	for c := range h.clients {
		select {
		case c.events <- e:
		default:
		}
	}
}

func Register(e *core.ServeEvent, guests *guest.Service) *Hub {
	h := &Hub{clients: map[*client]bool{}, last: map[string]time.Time{}}
	e.Router.GET("/api/v1/chat/events", func(r *core.RequestEvent) error {
		identity, ok := guests.Resolve(r)
		if !ok {
			return r.UnauthorizedError("请先登录", nil)
		}
		if identity.Name == "" {
			profile, err := r.App.FindFirstRecordByFilter("profiles", "userId = {:id}", dbx.Params{"id": identity.ID})
			if err != nil {
				return r.BadRequestError("请先创建角色", nil)
			}
			identity.Name = profile.GetString("name")
		}
		c := &client{user: identity.ID, name: identity.Name, events: make(chan Event, 64)}
		r.Response.Header().Set("Content-Type", "text/event-stream")
		r.Response.Header().Set("Cache-Control", "no-cache")
		r.Response.Header().Set("X-Accel-Buffering", "no")
		h.mu.Lock()
		h.clients[c] = true
		h.broadcast(Event{Type: "join", Name: c.name})
		h.mu.Unlock()
		defer func() {
			h.mu.Lock()
			delete(h.clients, c)
			h.broadcast(Event{Type: "leave", Name: c.name})
			h.mu.Unlock()
		}()
		controller := http.NewResponseController(r.Response)
		ticker := time.NewTicker(15 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case msg := <-c.events:
				b, _ := json.Marshal(msg)
				if _, err := fmt.Fprintf(r.Response, "data: %s\n\n", b); err != nil {
					return nil
				}
				if controller.Flush() != nil {
					return nil
				}
			case <-ticker.C:
				if _, err := fmt.Fprint(r.Response, ": ping\n\n"); err != nil {
					return nil
				}
				if controller.Flush() != nil {
					return nil
				}
			case <-r.Request.Context().Done():
				return nil
			}
		}
	})
	e.Router.POST("/api/v1/chat/messages", func(r *core.RequestEvent) error {
		identity, ok := guests.Resolve(r)
		if !ok {
			return r.UnauthorizedError("请先登录", nil)
		}
		var body struct {
			Text string `json:"text"`
		}
		if err := r.BindBody(&body); err != nil {
			return r.BadRequestError("消息无效", nil)
		}
		text := strings.TrimSpace(body.Text)
		if text == "" || utf8.RuneCountInString(text) > 200 || strings.ContainsAny(text, "\r\n") {
			return r.BadRequestError("消息须为 1–200 个字符", nil)
		}
		h.mu.Lock()
		defer h.mu.Unlock()
		var connected *client
		for c := range h.clients {
			if c.user == identity.ID {
				connected = c
				break
			}
		}
		if connected == nil {
			return r.BadRequestError("请先连接游戏", nil)
		}
		now := time.Now()
		if now.Sub(h.last[identity.ID]) < time.Second {
			return r.TooManyRequestsError("发送太快，请稍后再试", nil)
		}
		h.last[identity.ID] = now
		h.broadcast(Event{Type: "message", Name: connected.name, Text: text})
		return r.JSON(http.StatusOK, map[string]bool{"sent": true})
	})
	return h
}

func (h *Hub) Join(user, name string) (<-chan Event, func()) {
	c := &client{user: user, name: name, events: make(chan Event, 64)}
	h.mu.Lock()
	h.clients[c] = true
	h.broadcast(Event{Type: "join", Name: name})
	h.mu.Unlock()
	return c.events, func() {
		h.mu.Lock()
		delete(h.clients, c)
		h.broadcast(Event{Type: "leave", Name: name})
		h.mu.Unlock()
	}
}

func (h *Hub) Send(user, text string) error {
	text = strings.TrimSpace(text)
	if text == "" || utf8.RuneCountInString(text) > 200 || strings.ContainsAny(text, "\r\n") {
		return fmt.Errorf("消息须为 1–200 个字符")
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	var connected *client
	for c := range h.clients {
		if c.user == user {
			connected = c
			break
		}
	}
	if connected == nil {
		return fmt.Errorf("请先连接游戏")
	}
	now := time.Now()
	if now.Sub(h.last[user]) < time.Second {
		return fmt.Errorf("发送太快，请稍后再试")
	}
	h.last[user] = now
	h.broadcast(Event{Type: "message", Name: connected.name, Text: text})
	return nil
}
