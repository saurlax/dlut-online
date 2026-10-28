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

type event struct {
	Type string `json:"type"`
	Name string `json:"name"`
	Text string `json:"text,omitempty"`
}
type client struct {
	user   string
	name   string
	events chan event
}
type hub struct {
	mu      sync.Mutex
	clients map[*client]bool
	last    map[string]time.Time
}

func (h *hub) broadcast(e event) {
	for c := range h.clients {
		select {
		case c.events <- e:
		default:
		}
	}
}

func Register(e *core.ServeEvent, guests *guest.Service) {
	h := &hub{clients: map[*client]bool{}, last: map[string]time.Time{}}
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
		c := &client{user: identity.ID, name: identity.Name, events: make(chan event, 64)}
		r.Response.Header().Set("Content-Type", "text/event-stream")
		r.Response.Header().Set("Cache-Control", "no-cache")
		r.Response.Header().Set("X-Accel-Buffering", "no")
		h.mu.Lock()
		h.clients[c] = true
		h.broadcast(event{Type: "join", Name: c.name})
		h.mu.Unlock()
		defer func() {
			h.mu.Lock()
			delete(h.clients, c)
			h.broadcast(event{Type: "leave", Name: c.name})
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
		h.broadcast(event{Type: "message", Name: connected.name, Text: text})
		return r.JSON(http.StatusOK, map[string]bool{"sent": true})
	})
}
