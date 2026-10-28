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
	"github.com/saurlax/dlut-online/apps/api/internal/characters"
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

func TestOIDCRequiresExplicitBindingAndIgnoresEmail(t *testing.T) {
	app := core.NewBaseApp(core.BaseAppConfig{DataDir: t.TempDir()})
	characters.BindIdentity(app)
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
	account := func(email string) (*core.Record, string) {
		t.Helper()
		record := core.NewRecord(users)
		record.SetEmail(email)
		record.SetPassword("binding-test-password")
		if err := app.Save(record); err != nil {
			t.Fatal(err)
		}
		token, err := record.NewAuthToken()
		if err != nil {
			t.Fatal(err)
		}
		return record, token
	}
	alice, aliceToken := account("alice@example.com")
	bob, bobToken := account("bob@example.com")
	other := core.NewExternalAuth(app)
	other.SetCollectionRef(users.Id)
	other.SetRecordRef(alice.Id)
	other.SetProvider("github")
	other.SetProviderId("existing-github-account")
	if err := app.Save(other); err != nil {
		t.Fatal(err)
	}
	providerEmail := "alice@example.com"
	provider := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/token":
			r.ParseForm()
			json.NewEncoder(w).Encode(map[string]any{"access_token": r.Form.Get("code"), "token_type": "Bearer", "expires_in": 3600})
		case "/userinfo":
			subject := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
			if subject == "missing-sub" {
				subject = ""
			}
			json.NewEncoder(w).Encode(map[string]any{"sub": subject, "email": providerEmail, "email_verified": true, "name": "Real Name", "preferred_username": "preferred-student", "gender": "female"})
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
	characters.Register(&core.ServeEvent{App: app, Router: router})
	mux, err := router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	call := func(subject, token string, wantStatus int, wantID string) {
		t.Helper()
		body, _ := json.Marshal(map[string]any{"provider": "oidc", "code": subject, "codeVerifier": "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGH", "redirectURL": "http://localhost/api/oauth2-redirect"})
		request := httptest.NewRequest("POST", "/api/collections/users/auth-with-oauth2", strings.NewReader(string(body)))
		request.Header.Set("Content-Type", "application/json")
		request.Header.Set("Authorization", token)
		response := httptest.NewRecorder()
		mux.ServeHTTP(response, request)
		if response.Code != wantStatus {
			t.Fatalf("subject %q returned HTTP %d, want %d", subject, response.Code, wantStatus)
		}
		if wantStatus == http.StatusOK {
			var auth struct {
				Token  string
				Record struct {
					ID, Email string
					Verified  bool
				}
				Meta map[string]any
			}
			if err := json.Unmarshal(response.Body.Bytes(), &auth); err != nil {
				t.Fatal(err)
			}
			if auth.Token == "" || auth.Record.ID != wantID || auth.Record.Verified {
				t.Fatal("incorrect bound account or trusted the provider email verification")
			}
			if wantID == alice.Id {
				aliceToken = auth.Token
			} else {
				bobToken = auth.Token
			}
			expectedEmail := alice.Email()
			if wantID == bob.Id {
				expectedEmail = bob.Email()
			}
			if auth.Record.Email != expectedEmail {
				t.Fatal("provider replaced the registered email")
			}
			if raw, ok := auth.Meta["rawUser"].(map[string]any); ok {
				if _, exists := raw["email"]; exists {
					t.Fatal("provider email leaked into auth metadata")
				}
			}
			record, err := app.FindRecordById("users", wantID)
			if err != nil {
				t.Fatal(err)
			}
			var defaults characters.CharacterDefaults
			if err := record.UnmarshalJSONField("characterDefaults", &defaults); err != nil {
				t.Fatal(err)
			}
			if !record.ValidatePassword("binding-test-password") {
				t.Fatal("SSO changed the registered password")
			}
			if defaults.Name != "preferred-student" || defaults.Gender != "female" {
				t.Fatal("lost character defaults")
			}
		}
	}
	call("student-one", "", http.StatusBadRequest, "") // Matching verified email must not log in or auto-link.
	call("student-one", aliceToken, http.StatusOK, alice.Id)
	providerEmail = "bob@example.com"
	call("student-one", "", http.StatusOK, alice.Id) // Subject remains authoritative when provider email changes.
	call("student-one", bobToken, http.StatusBadRequest, "")
	call("student-two", aliceToken, http.StatusBadRequest, "")
	call("student-two", "", http.StatusBadRequest, "")
	call("student-two", bobToken, http.StatusOK, bob.Id)
	call("student-one", aliceToken, http.StatusOK, alice.Id)
	call("missing-sub", aliceToken, http.StatusBadRequest, "")
	start := httptest.NewRecorder()
	mux.ServeHTTP(start, httptest.NewRequest("POST", "/api/v1/sso/onboarding/start", strings.NewReader(`{}`)))
	cookies := start.Result().Cookies()
	if start.Code != http.StatusOK || len(cookies) != 1 || !cookies[0].HttpOnly {
		t.Fatal("missing browser proof cookie")
	}
	firstSSO := httptest.NewRequest("POST", "/api/collections/users/auth-with-oauth2", strings.NewReader(`{"provider":"oidc","code":"unbound-student","codeVerifier":"abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGH","redirectURL":"http://localhost/api/oauth2-redirect"}`))
	firstSSO.Header.Set("Content-Type", "application/json")
	firstSSO.AddCookie(cookies[0])
	guide := httptest.NewRecorder()
	mux.ServeHTTP(guide, firstSSO)
	var pending struct {
		Code  string
		Token string
		Data  struct{ Ticket string }
	}
	if err := json.Unmarshal(guide.Body.Bytes(), &pending); err != nil {
		t.Fatal(err)
	}
	if guide.Code != http.StatusConflict || pending.Code != "sso_onboarding_required" || len(pending.Data.Ticket) != 48 || pending.Token != "" {
		t.Fatal("unbound SSO did not issue an onboarding-only ticket")
	}
	all, err := app.FindAllRecords("users")
	if err != nil || len(all) != 2 {
		t.Fatal("SSO created an account", err)
	}
	for _, record := range []*core.Record{alice, bob} {
		links, err := app.FindAllExternalAuthsByRecord(record)
		expected := 1
		if record.Id == alice.Id {
			expected = 2
		}
		if err != nil || len(links) != expected {
			t.Fatal("invalid binding cardinality", err)
		}
	}
	request := httptest.NewRequest("GET", "/api/v1/account", nil)
	request.Header.Set("Authorization", aliceToken)
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	var details struct {
		OIDCBound bool `json:"oidcBound"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &details); err != nil {
		t.Fatal(err)
	}
	if response.Code != http.StatusOK || !details.OIDCBound {
		t.Fatalf("missing account binding status (HTTP %d)", response.Code)
	}
}
