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
	"testing/fstest"
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
	world, err := LoadWorld(fstest.MapFS{
		"campuses/eda/map.json":           {Data: []byte(`{"focus":[1,1],"chunkSize":4,"textures":["grass-0"],"chunks":[{"x":0,"y":0,"layers":[[16,0]]}]}`)},
		"campuses/eda/site-fixtures.json": {Data: []byte(`{"lamps":[],"noticeboards":[]}`)},
	}, "eda")
	if err != nil {
		t.Fatal(err)
	}
	otherWorld := testWorld(t)
	otherEnv := weather.NewAt(40.686319, 122.11917)
	otherEnv.SetWeather(63)
	Register(e, guests, hub, map[string]Campus{
		"lingshui": {World: world, Environment: env, Execute: commands.Register(e, env)},
		"panjin":   {World: otherWorld, Environment: otherEnv, Execute: commands.NewExecutor(otherEnv)},
	})
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
	unknown, _, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(server.URL, "http")+"/api/v1/game/socket", nil)
	if err != nil {
		t.Fatal(err)
	}
	defer unknown.Close()
	if err := unknown.WriteJSON(message{Type: "auth", Token: session.Token, Campus: "unknown"}); err != nil {
		t.Fatal(err)
	}
	if _, _, err := unknown.ReadMessage(); err == nil {
		t.Fatal("unknown campus accepted")
	} else if closeError, ok := err.(*websocket.CloseError); !ok || closeError.Code != 4002 {
		t.Fatal("unexpected campus rejection", err)
	}
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
	if err := socket.WriteJSON(message{Type: "ping", ID: "latency-probe"}); err != nil {
		t.Fatal(err)
	}
	for {
		var v envelope
		if err := socket.ReadJSON(&v); err != nil {
			t.Fatal(err)
		}
		if v.Type == "pong" {
			if v.ID != "latency-probe" {
				t.Fatalf("pong id = %q", v.ID)
			}
			break
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
	for {
		if err := socket.ReadJSON(&v); err != nil {
			t.Fatal("weather update missing", err)
		}
		if v.Type == "weather" && strings.Contains(string(v.Data), `"weather_code":73`) {
			break
		}
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
	other, _, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(server.URL, "http")+"/api/v1/game/socket", nil)
	if err != nil {
		t.Fatal(err)
	}
	defer other.Close()
	other.SetReadDeadline(time.Now().Add(5 * time.Second))
	if err := other.WriteJSON(message{Type: "auth", Token: session.Token, Campus: "panjin", Landmark: "library"}); err != nil {
		t.Fatal(err)
	}
	var otherReady, otherWeather bool
	for !otherReady || !otherWeather {
		var v struct {
			Type string          `json:"type"`
			Data json.RawMessage `json:"data"`
		}
		if err := other.ReadJSON(&v); err != nil {
			t.Fatal(err)
		}
		if v.Type == "ready" {
			var snapshot worldSnapshot
			if err := json.Unmarshal(v.Data, &snapshot); err != nil {
				t.Fatal(err)
			}
			if len(snapshot.Players) != 1 || snapshot.Players[0].ID != snapshot.SelfID {
				t.Fatal("players leaked across campus worlds")
			}
			if snapshot.Players[0].Revision != 1 {
				t.Fatal("cross-campus arrival did not travel to the requested landmark")
			}
			otherReady = true
		}
		if v.Type == "weather" {
			if !strings.Contains(string(v.Data), `"weather_code":63`) {
				t.Fatal("weather leaked across campuses")
			}
			otherWeather = true
		}
	}
}
