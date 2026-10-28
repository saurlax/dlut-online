//go:build integration

package chat

import (
	"bufio"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	_ "github.com/saurlax/dlut-online/apps/api/internal/characters"
	"github.com/saurlax/dlut-online/apps/api/internal/guest"
)

func TestChatPresenceAndRateLimit(t *testing.T) {
	app := core.NewBaseApp(core.BaseAppConfig{DataDir: t.TempDir()})
	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	defer app.ResetBootstrapState()
	if err := app.RunAllMigrations(); err != nil {
		t.Fatal(err)
	}
	users, _ := app.FindCollectionByNameOrId("users")
	user := core.NewRecord(users)
	user.SetEmail("chat@example.com")
	user.SetPassword("test-password")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	profiles, _ := app.FindCollectionByNameOrId("profiles")
	profile := core.NewRecord(profiles)
	profile.Set("userId", user.Id)
	profile.Set("name", "Player")
	profile.Set("gender", "unspecified")
	profile.Set("appearance", map[string]int{"skin": 0})
	if err := app.Save(profile); err != nil {
		t.Fatal(err)
	}
	token, err := user.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	Register(&core.ServeEvent{App: app, Router: router}, guest.New())
	mux, err := router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(mux)
	defer server.Close()
	req, _ := http.NewRequest("GET", server.URL+"/api/v1/chat/events", nil)
	req.Header.Set("Authorization", token)
	client := &http.Client{Timeout: 5 * time.Second}
	res, err := client.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	reader := bufio.NewReader(res.Body)
	line, err := reader.ReadString('\n')
	if err != nil || !strings.Contains(line, `"type":"join"`) {
		t.Fatal("missing join event", err)
	}
	reader.ReadString('\n')
	send := func() int {
		req, _ := http.NewRequest("POST", server.URL+"/api/v1/chat/messages", strings.NewReader(`{"text":"hello"}`))
		req.Header.Set("Authorization", token)
		req.Header.Set("Content-Type", "application/json")
		r, err := client.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer r.Body.Close()
		return r.StatusCode
	}
	if send() != http.StatusOK || send() != http.StatusTooManyRequests {
		t.Fatal("chat rate limit failed")
	}
	line, err = reader.ReadString('\n')
	if err != nil || !strings.Contains(line, `"text":"hello"`) {
		t.Fatal("missing message", err)
	}
}

func TestGuestChatDoesNotCreateAccount(t *testing.T) {
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
	guests := guest.New()
	event := &core.ServeEvent{App: app, Router: router}
	guests.Register(event)
	Register(event, guests)
	mux, err := router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(mux)
	defer server.Close()
	client := &http.Client{Timeout: 5 * time.Second}
	response, err := client.Post(server.URL+"/api/v1/guest", "application/json", strings.NewReader(`{}`))
	if err != nil {
		t.Fatal(err)
	}
	var session struct {
		Token string `json:"token"`
		Name  string `json:"name"`
	}
	if err := json.NewDecoder(response.Body).Decode(&session); err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if !regexp.MustCompile(`^游客[0-9]{6}$`).MatchString(session.Name) {
		t.Fatal("unexpected guest name")
	}
	users, err := app.FindRecordsByFilter("users", "", "", 0, 0)
	if err != nil || len(users) != 0 {
		t.Fatal("guest created a user", err)
	}
	req, _ := http.NewRequest("GET", server.URL+"/api/v1/chat/events", nil)
	req.Header.Set("Authorization", session.Token)
	stream, err := client.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer stream.Body.Close()
	reader := bufio.NewReader(stream.Body)
	line, err := reader.ReadString('\n')
	if err != nil || !strings.Contains(line, session.Name) {
		t.Fatal("guest did not join chat", err)
	}
	req, _ = http.NewRequest("POST", server.URL+"/api/v1/chat/messages", strings.NewReader(`{"text":"hello"}`))
	req.Header.Set("Authorization", session.Token)
	req.Header.Set("Content-Type", "application/json")
	sent, err := client.Do(req)
	if err != nil || sent.StatusCode != http.StatusOK {
		t.Fatal("guest chat failed", err)
	}
	sent.Body.Close()
	req, _ = http.NewRequest("POST", server.URL+"/api/collections/users/records", strings.NewReader(`{}`))
	req.Header.Set("Authorization", session.Token)
	req.Header.Set("Content-Type", "application/json")
	blocked, err := client.Do(req)
	if err != nil || blocked.StatusCode == http.StatusOK || blocked.StatusCode == http.StatusCreated {
		t.Fatal("guest gained account permission", err)
	}
	blocked.Body.Close()
}
