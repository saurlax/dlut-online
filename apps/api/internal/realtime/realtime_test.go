//go:build integration

package realtime

import (
	"encoding/json"
	"github.com/gorilla/websocket"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	_ "github.com/saurlax/dlut-online/apps/api/internal/characters"
	"github.com/saurlax/dlut-online/apps/api/internal/chat"
	"github.com/saurlax/dlut-online/apps/api/internal/commands"
	"github.com/saurlax/dlut-online/apps/api/internal/guest"
	"github.com/saurlax/dlut-online/apps/api/internal/weather"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestGuestSocketChatWeatherAndAuthorization(t *testing.T) {
	app := core.NewBaseApp(core.BaseAppConfig{DataDir: t.TempDir()})
	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	defer app.ResetBootstrapState()
	if err := app.RunAllMigrations(); err != nil {
		t.Fatal(err)
	}
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	e := &core.ServeEvent{App: app, Router: router}
	guests := guest.New()
	guests.Register(e)
	hub := chat.Register(e, guests)
	env := weather.New()
	Register(e, guests, hub, env, commands.Register(e, env))
	mux, err := router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(mux)
	defer server.Close()
	res, err := http.Post(server.URL+"/api/v1/guest", "application/json", strings.NewReader(`{}`))
	if err != nil {
		t.Fatal(err)
	}
	var session struct {
		Token string `json:"token"`
		Name  string `json:"name"`
	}
	if err := json.NewDecoder(res.Body).Decode(&session); err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	socket, _, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(server.URL, "http")+"/api/v1/game/socket", nil)
	if err != nil {
		t.Fatal(err)
	}
	defer socket.Close()
	socket.SetReadDeadline(time.Now().Add(5 * time.Second))
	if err := socket.WriteJSON(message{Type: "auth", Token: session.Token}); err != nil {
		t.Fatal(err)
	}
	var gotReady, gotJoin, gotWeather bool
	for !gotReady || !gotJoin || !gotWeather {
		var v struct {
			Type string          `json:"type"`
			Data json.RawMessage `json:"data"`
		}
		if err := socket.ReadJSON(&v); err != nil {
			t.Fatal(err)
		}
		switch v.Type {
		case "ready":
			gotReady = true
		case "chat":
			gotJoin = strings.Contains(string(v.Data), session.Name)
		case "weather":
			gotWeather = true
		}
	}
	if err := socket.WriteJSON(message{Type: "chat", ID: "1", Text: "hello"}); err != nil {
		t.Fatal(err)
	}
	var gotMessage, gotResult bool
	for !gotMessage || !gotResult {
		var v struct {
			Type string          `json:"type"`
			ID   string          `json:"id"`
			Data json.RawMessage `json:"data"`
		}
		if err := socket.ReadJSON(&v); err != nil {
			t.Fatal(err)
		}
		if v.Type == "chat" && strings.Contains(string(v.Data), "hello") {
			gotMessage = true
		}
		if v.Type == "result" && v.ID == "1" {
			gotResult = true
		}
	}
	if err := socket.WriteJSON(message{Type: "command", ID: "2", Text: "/time set day"}); err != nil {
		t.Fatal(err)
	}
	for {
		var result struct {
			Type  string `json:"type"`
			ID    string `json:"id"`
			Error string `json:"error"`
		}
		if err := socket.ReadJSON(&result); err != nil {
			t.Fatal(err)
		}
		if result.Type == "result" && result.ID == "2" {
			if !strings.Contains(result.Error, "没有权限") {
				t.Fatal("guest command was not denied")
			}
			break
		}
	}
	env.SetWeather(73)
	var v struct {
		Type string          `json:"type"`
		Data json.RawMessage `json:"data"`
	}
	if err := socket.ReadJSON(&v); err != nil || v.Type != "weather" || !strings.Contains(string(v.Data), `"weather_code":73`) {
		t.Fatal("weather update missing", err)
	}
	bad, _, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(server.URL, "http")+"/api/v1/game/socket", nil)
	if err != nil {
		t.Fatal(err)
	}
	defer bad.Close()
	bad.WriteJSON(message{Type: "auth", Token: "invalid"})
	_, _, err = bad.ReadMessage()
	closeErr, ok := err.(*websocket.CloseError)
	if !ok || closeErr.Code != 4001 {
		t.Fatal("invalid token accepted", err)
	}
}
