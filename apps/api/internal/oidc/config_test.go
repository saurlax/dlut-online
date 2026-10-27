//go:build integration

package oidc

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	_ "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

func TestConfigurePreservesOtherAuthAndRotatesOnlyOIDC(t *testing.T) {
	app := core.NewBaseApp(core.BaseAppConfig{DataDir: t.TempDir()})
	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { app.ResetBootstrapState() })
	if err := app.RunAllMigrations(); err != nil {
		t.Fatal(err)
	}
	users, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		t.Fatal(err)
	}
	passwordEnabled := users.PasswordAuth.Enabled
	users.OAuth2.Providers = []core.OAuth2ProviderConfig{{Name: "github", ClientId: "existing", ClientSecret: "existing-test-secret"}}
	if err := app.Save(users); err != nil {
		t.Fatal(err)
	}
	provider := core.OAuth2ProviderConfig{Name: "oidc", ClientId: "game-test", ClientSecret: "test-client-secret", AuthURL: "https://sso.example.com/authorize", TokenURL: "https://sso.example.com/token", UserInfoURL: "https://sso.example.com/userinfo"}
	for _, secret := range []string{"test-client-secret", "rotated-test-secret"} {
		provider.ClientSecret = secret
		if err := Configure(app, provider); err != nil {
			t.Fatal(err)
		}
		current, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			t.Fatal(err)
		}
		if !current.OAuth2.Enabled || len(current.OAuth2.Providers) != 2 || current.PasswordAuth.Enabled != passwordEnabled {
			t.Fatal("changed another authentication method or duplicated OIDC")
		}
		if current.OAuth2.Providers[0].Name != "github" || current.OAuth2.Providers[0].ClientSecret != "existing-test-secret" {
			t.Fatal("overwrote another provider")
		}
		if current.OAuth2.Providers[1].ClientSecret != secret {
			t.Fatal("OIDC credentials were not updated")
		}
	}
	provider.ClientId = ""
	if err := Configure(app, provider); err == nil {
		t.Fatal("accepted invalid OIDC configuration")
	}
	current, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		t.Fatal(err)
	}
	if current.OAuth2.Providers[1].ClientId != "game-test" {
		t.Fatal("failed configuration changed persisted credentials")
	}
}

func TestOIDCWithoutEmailCreatesAndReusesUser(t *testing.T) {
	app := core.NewBaseApp(core.BaseAppConfig{DataDir: t.TempDir()})
	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { app.ClearBootstrap() })
	if err := app.RunAllMigrations(); err != nil {
		t.Fatal(err)
	}
	users, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		t.Fatal(err)
	}
	users.CreateRule = types.Pointer("")
	users.Fields.GetByName("email").(*core.EmailField).Required = true
	if err := app.Save(users); err != nil {
		t.Fatal(err)
	}
	provider := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/token":
			json.NewEncoder(w).Encode(map[string]any{"access_token": "test-access-token", "token_type": "Bearer", "expires_in": 3600})
		case "/userinfo":
			json.NewEncoder(w).Encode(map[string]any{"sub": "cas-test-student", "name": "Test Student"})
		default:
			http.NotFound(w, r)
		}
	}))
	defer provider.Close()
	if err := Configure(app, core.OAuth2ProviderConfig{Name: "oidc", ClientId: "test-game", ClientSecret: "test-secret", AuthURL: provider.URL + "/authorize", TokenURL: provider.URL + "/token", UserInfoURL: provider.URL + "/userinfo"}); err != nil {
		t.Fatal(err)
	}
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	mux, err := router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	var firstID string
	for i := 0; i < 2; i++ {
		request := httptest.NewRequest("POST", "/api/collections/users/auth-with-oauth2", strings.NewReader(`{"provider":"oidc","code":"test-code","codeVerifier":"abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGH","redirectUrl":"http://localhost/api/oauth2-redirect"}`))
		request.Header.Set("Content-Type", "application/json")
		response := httptest.NewRecorder()
		mux.ServeHTTP(response, request)
		if response.Code != http.StatusOK {
			t.Fatalf("OAuth2 without email returned %d: %s", response.Code, response.Body.String())
		}
		var auth struct {
			Token  string `json:"token"`
			Record struct {
				ID    string `json:"id"`
				Email string `json:"email"`
			} `json:"record"`
		}
		if err := json.Unmarshal(response.Body.Bytes(), &auth); err != nil {
			t.Fatal(err)
		}
		if auth.Token == "" || auth.Record.ID == "" || auth.Record.Email != "" {
			t.Fatal("expected an authenticated account without a fabricated email")
		}
		if i == 0 {
			firstID = auth.Record.ID
		} else if auth.Record.ID != firstID {
			t.Fatal("the same OIDC subject created another account")
		}
	}
}
