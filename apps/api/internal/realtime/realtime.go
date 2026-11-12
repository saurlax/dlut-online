package realtime

import (
	"fmt"
	"time"

	"github.com/gorilla/websocket"
	"github.com/pocketbase/pocketbase/core"
	"github.com/saurlax/dlut-online/apps/api/internal/chat"
	"github.com/saurlax/dlut-online/apps/api/internal/commands"
	"github.com/saurlax/dlut-online/apps/api/internal/guest"
	"github.com/saurlax/dlut-online/apps/api/internal/weather"
)

type message struct {
	Type     string          `json:"type"`
	Token    string          `json:"token,omitempty"`
	Text     string          `json:"text,omitempty"`
	ID       string          `json:"id,omitempty"`
	Inputs   []movementInput `json:"inputs,omitempty"`
	Revision int             `json:"revision,omitempty"`
	Landmark string          `json:"landmark,omitempty"`
	Campus   string          `json:"campus,omitempty"`
	Entity   string          `json:"entity,omitempty"`
}
type envelope struct {
	Type  string `json:"type"`
	Data  any    `json:"data,omitempty"`
	ID    string `json:"id,omitempty"`
	Error string `json:"error,omitempty"`
}

type Campus struct {
	World       *World
	Environment *weather.Service
	Execute     commands.Executor
}

func Register(e *core.ServeEvent, guests *guest.Service, hub *chat.Hub, campuses map[string]Campus) {
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
		campus := auth.Campus
		if campus == "" {
			campus = "lingshui"
		}
		selected, ok := campuses[campus]
		if !ok {
			_ = conn.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(4002, "campus unavailable"), time.Now().Add(time.Second))
			return nil
		}
		world, environment, execute := selected.World, selected.Environment, selected.Execute
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
		if (auth.Landmark != "" && !world.travel(playerID, auth.Landmark)) ||
			(auth.Entity != "" && !world.travelToEntity(playerID, auth.Entity)) {
			_ = conn.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(4002, "landmark unavailable"), time.Now().Add(time.Second))
			return nil
		}
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
				case "interact":
					world.petAnimal(playerID, m.Entity, time.Now())
					continue
				}
				if m.Type == "chat" || m.Type == "command" {
					result := envelope{Type: "result", ID: m.ID}
					var transfer *campusEntity
					if m.Type == "chat" {
						if err := hub.Send(identity.ID, m.Text); err != nil {
							result.Error = err.Error()
						}
					} else {
						value, err := execute(r.App, identity.ID, m.Text, &commands.WorldCommands{
							Entities: func() string { return entityList(campuses) },
							Teleport: func(target string) (string, error) {
								if time.Since(lastTravel) < time.Second {
									return "", fmt.Errorf("传送过于频繁")
								}
								entity, err := resolveEntity(campuses, target)
								if err != nil {
									return "", err
								}
								if entity.ID == playerID {
									return "", fmt.Errorf("目标是你自己")
								}
								lastTravel = time.Now()
								if entity.Campus != campus {
									transfer = &entity
									return "正在前往 " + entityName(entity.entityState), nil
								}
								if !world.travelToEntity(playerID, entity.ID) {
									return "", fmt.Errorf("目标已离开或附近没有可站立位置")
								}
								return "已传送到 " + entityName(entity.entityState) + " 附近", nil
							},
						})
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
					if transfer != nil {
						select {
						case outgoing <- envelope{Type: "transfer", Data: map[string]string{"campus": transfer.Campus, "entity": transfer.ID}}:
						case <-stopping:
							return
						}
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
