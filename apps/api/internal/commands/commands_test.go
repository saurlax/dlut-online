//go:build integration

package commands

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	_ "github.com/saurlax/dlut-online/apps/api/internal/characters"
	"github.com/saurlax/dlut-online/apps/api/internal/weather"
)

func TestCommandPermissionsAndArguments(t *testing.T) {
	app := core.NewBaseApp(core.BaseAppConfig{DataDir: t.TempDir()})
	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	defer app.ResetBootstrapState()
	if err := app.RunAllMigrations(); err != nil {
		t.Fatal(err)
	}
	users, _ := app.FindCollectionByNameOrId("users")
	u := core.NewRecord(users)
	u.SetEmail("commands@example.com")
	u.SetPassword("test-password")
	if err := app.Save(u); err != nil {
		t.Fatal(err)
	}
	token, err := u.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	env := weather.New()
	Register(&core.ServeEvent{App: app, Router: router}, env)
	mux, err := router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	call := func(command string) *httptest.ResponseRecorder {
		body, _ := json.Marshal(map[string]string{"command": command})
		req := httptest.NewRequest("POST", "/api/v1/commands", strings.NewReader(string(body)))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", token)
		resp := httptest.NewRecorder()
		mux.ServeHTTP(resp, req)
		return resp
	}
	if call("/time set day").Code != http.StatusForbidden {
		t.Fatal("unprivileged command accepted")
	}
	roles, err := app.FindFirstRecordByFilter("roles", "name='admin'", nil)
	if err != nil {
		t.Fatal(err)
	}
	collection, _ := app.FindCollectionByNameOrId("user_roles")
	assignment := core.NewRecord(collection)
	assignment.Set("userId", u.Id)
	assignment.Set("roleId", roles.Id)
	if err := app.Save(assignment); err != nil {
		t.Fatal(err)
	}
	if call("/time set 25:00").Code != http.StatusBadRequest {
		t.Fatal("invalid time accepted")
	}
	if call("/weather set snow").Code != http.StatusOK {
		t.Fatal("authorized command failed")
	}
	if call("/time set noon").Code != http.StatusOK {
		t.Fatal("noon command failed")
	}
	if !strings.Contains(call("/help").Body.String(), "/weather set") {
		t.Fatal("missing help")
	}
}
