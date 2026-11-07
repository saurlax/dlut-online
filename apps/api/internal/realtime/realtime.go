package realtime

import (
	"github.com/gorilla/websocket"
	"github.com/pocketbase/pocketbase/core"
	"github.com/saurlax/dlut-online/apps/api/internal/chat"
	"github.com/saurlax/dlut-online/apps/api/internal/commands"
	"github.com/saurlax/dlut-online/apps/api/internal/guest"
	"github.com/saurlax/dlut-online/apps/api/internal/weather"
	"time"
)

type message struct {
	Type     string          `json:"type"`
	Token    string          `json:"token,omitempty"`
	Text     string          `json:"text,omitempty"`
	ID       string          `json:"id,omitempty"`
	Inputs   []movementInput `json:"inputs,omitempty"`
	Revision int             `json:"revision,omitempty"`
	Landmark string          `json:"landmark,omitempty"`
}
type envelope struct {
	Type  string `json:"type"`
	Data  any    `json:"data,omitempty"`
	ID    string `json:"id,omitempty"`
	Error string `json:"error,omitempty"`
}

func Register(e *core.ServeEvent, guests *guest.Service, hub *chat.Hub, environment *weather.Service, execute commands.Executor, world *World) {
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
		look, err := lookFor(r.App, identity)
		if err != nil {
			_ = conn.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(4001, "character required"), time.Now().Add(time.Second))
			return nil
		}
		playerID, err := world.join(look)
		if err != nil {
			return err
		}
		defer world.leave(playerID)
		lookIdentity := identity
		identity.Name = look.Name
		chatEvents, leave := hub.Join(identity.ID, identity.Name)
		defer leave()
		weatherEvents, unsubscribe := environment.Subscribe()
		defer unsubscribe()
		outgoing := make(chan envelope, 16)
		done := make(chan struct{})
		stopping := make(chan struct{})
		conn.SetPongHandler(func(string) error { return conn.SetReadDeadline(time.Now().Add(35 * time.Second)) })
		_ = conn.SetReadDeadline(time.Now().Add(35 * time.Second))
		go func() {
			defer close(done)
			var lastAppearance, lastTravel time.Time
			for {
				var m message
				if conn.ReadJSON(&m) != nil {
					return
				}
				switch m.Type {
				case "ping":
					select {
					case outgoing <- envelope{Type: "pong", ID: m.ID}:
					case <-stopping:
						return
					}
					continue
				case "input":
					if world.input(playerID, m.Revision, m.Inputs, time.Now()) != nil {
						return
					}
					continue
				case "appearance":
					if time.Since(lastAppearance) < 200*time.Millisecond {
						continue
					}
					lastAppearance = time.Now()
					look, err := lookFor(r.App, lookIdentity)
					if err != nil {
						return
					}
					world.appearance(playerID, look)
					continue
				case "travel":
					if time.Since(lastTravel) < time.Second {
						continue
					}
					lastTravel = time.Now()
					world.travel(playerID, m.Landmark)
					continue
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
					case <-stopping:
						return
					}
				}
			}
		}()
		defer func() { close(stopping); conn.Close(); <-done }()
		snapshots := time.NewTicker(100 * time.Millisecond)
		defer snapshots.Stop()
		ticker := time.NewTicker(10 * time.Second)
		defer ticker.Stop()
		write := func(value envelope) error {
			if err := conn.SetWriteDeadline(time.Now().Add(5 * time.Second)); err != nil {
				return err
			}
			return conn.WriteJSON(value)
		}
		if err := write(envelope{Type: "ready", Data: world.snapshot(playerID)}); err != nil {
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
			case <-snapshots.C:
				if err := write(envelope{Type: "world", Data: world.snapshot(playerID)}); err != nil {
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
