package realtime

import (
	"github.com/gorilla/websocket"
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	"github.com/saurlax/dlut-online/apps/api/internal/chat"
	"github.com/saurlax/dlut-online/apps/api/internal/commands"
	"github.com/saurlax/dlut-online/apps/api/internal/guest"
	"github.com/saurlax/dlut-online/apps/api/internal/weather"
	"time"
)

type message struct {
	Type  string `json:"type"`
	Token string `json:"token,omitempty"`
	Text  string `json:"text,omitempty"`
	ID    string `json:"id,omitempty"`
}
type envelope struct {
	Type  string `json:"type"`
	Data  any    `json:"data,omitempty"`
	ID    string `json:"id,omitempty"`
	Error string `json:"error,omitempty"`
}

func Register(e *core.ServeEvent, guests *guest.Service, hub *chat.Hub, environment *weather.Service, execute commands.Executor) {
	upgrader := websocket.Upgrader{}
	e.Router.GET("/api/v1/game/socket", func(r *core.RequestEvent) error {
		conn, err := upgrader.Upgrade(r.Response, r.Request, nil)
		if err != nil {
			return nil
		}
		defer conn.Close()
		conn.SetReadLimit(4096)
		_ = conn.SetReadDeadline(time.Now().Add(10 * time.Second))
		var auth message
		if err := conn.ReadJSON(&auth); err != nil || auth.Type != "auth" {
			return nil
		}
		identity, ok := guests.ResolveToken(auth.Token)
		if !ok {
			record, err := r.App.FindAuthRecordByToken(auth.Token, core.TokenTypeAuth)
			if err != nil || record.Collection().Name != "users" {
				_ = conn.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(4001, "authentication failed"), time.Now().Add(time.Second))
				return nil
			}
			identity = guest.Identity{ID: record.Id}
		}
		if identity.Name == "" {
			profile, err := r.App.FindFirstRecordByFilter("profiles", "userId = {:id}", dbx.Params{"id": identity.ID})
			if err != nil {
				_ = conn.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(4001, "character required"), time.Now().Add(time.Second))
				return nil
			}
			identity.Name = profile.GetString("name")
		}
		chatEvents, leave := hub.Join(identity.ID, identity.Name)
		defer leave()
		weatherEvents, unsubscribe := environment.Subscribe()
		defer unsubscribe()
		outgoing := make(chan envelope, 16)
		done := make(chan struct{})
		conn.SetPongHandler(func(string) error { return conn.SetReadDeadline(time.Now().Add(35 * time.Second)) })
		_ = conn.SetReadDeadline(time.Now().Add(35 * time.Second))
		go func() {
			defer close(done)
			for {
				var m message
				if conn.ReadJSON(&m) != nil {
					return
				}
				if m.Type == "chat" || m.Type == "command" {
					result := envelope{Type: "result", ID: m.ID}
					if m.Type == "chat" {
						if err := hub.Send(identity.ID, m.Text); err != nil {
							result.Error = err.Error()
						}
					} else {
						value, err := execute(r.App, identity.ID, m.Text)
						if err != nil {
							result.Error = err.Error()
						} else {
							result.Data = value
						}
					}
					select {
					case outgoing <- result:
					case <-r.Request.Context().Done():
						return
					}
				}
			}
		}()
		ticker := time.NewTicker(10 * time.Second)
		defer ticker.Stop()
		write := func(value envelope) error {
			if err := conn.SetWriteDeadline(time.Now().Add(5 * time.Second)); err != nil {
				return err
			}
			return conn.WriteJSON(value)
		}
		if err := write(envelope{Type: "ready"}); err != nil {
			return nil
		}
		for {
			select {
			case event := <-chatEvents:
				if err := write(envelope{Type: "chat", Data: event}); err != nil {
					return nil
				}
			case event := <-weatherEvents:
				if err := write(envelope{Type: "weather", Data: event}); err != nil {
					return nil
				}
			case event := <-outgoing:
				if err := write(event); err != nil {
					return nil
				}
			case <-ticker.C:
				if err := conn.WriteControl(websocket.PingMessage, nil, time.Now().Add(5*time.Second)); err != nil {
					return nil
				}
			case <-done:
				return nil
			}
		}
	})
}
