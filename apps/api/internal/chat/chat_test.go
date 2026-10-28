//go:build integration

package chat

import (
	"bufio"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	_ "github.com/saurlax/dlut-online/apps/api/internal/characters"
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
	Register(&core.ServeEvent{App: app, Router: router})
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
