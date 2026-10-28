//go:build integration

package characters

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

func identityApp(t *testing.T) core.App {
	t.Helper()
	app := core.NewBaseApp(core.BaseAppConfig{DataDir: t.TempDir()})
	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { app.ResetBootstrapState() })
	if err := app.RunAllMigrations(); err != nil {
		t.Fatal(err)
	}
	return app
}

func TestIdentityMigrationPreservesCharacterName(t *testing.T) {
	app := identityApp(t)
	profiles, _ := app.FindCollectionByNameOrId("profiles")
	profiles.Fields.RemoveByName("gender")
	if err := app.Save(profiles); err != nil {
		t.Fatal(err)
	}
	users, _ := app.FindCollectionByNameOrId("users")
	users.Fields.RemoveByName("characterDefaults")
	users.Fields.Add(&core.TextField{Name: "name"})
	if err := app.Save(users); err != nil {
		t.Fatal(err)
	}
	user := core.NewRecord(users)
	user.SetEmail("migration@example.com")
	user.SetPassword("migration-test-password")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	profile := core.NewRecord(profiles)
	profile.Set("userId", user.Id)
	profile.Set("name", "已有角色")
	profile.Set("appearance", Appearance{Hair: 2})
	if err := app.Save(profile); err != nil {
		t.Fatal(err)
	}
	if err := app.RunInTransaction(migratePlayerIdentity); err != nil {
		t.Fatal(err)
	}
	users, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		t.Fatal(err)
	}
	if users.Fields.GetByName("name") != nil || users.Fields.GetByName("username") != nil || len(users.PasswordAuth.IdentityFields) != 1 || users.PasswordAuth.IdentityFields[0] != "email" {
		t.Fatal("duplicate display-name field or non-email password identity")
	}
	current, err := app.FindRecordById("profiles", profile.Id)
	if err != nil {
		t.Fatal(err)
	}
	if current.GetString("name") != "已有角色" || current.GetString("gender") != "unspecified" || current.GetString("userId") != user.Id {
		t.Fatal("migration lost identity or invented a gender")
	}
	var appearance Appearance
	if err := current.UnmarshalJSONField("appearance", &appearance); err != nil || appearance.Hair != 2 {
		t.Fatal("migration changed appearance", err)
	}
}

func TestCharacterIdentityValidationAndGenderOverride(t *testing.T) {
	app := identityApp(t)
	users, _ := app.FindCollectionByNameOrId("users")
	user := core.NewRecord(users)
	user.SetEmail("identity@example.com")
	user.SetPassword("identity-test-password")
	user.Set("characterDefaults", CharacterDefaults{Name: "preferred-student", Gender: "female"})
	if err := app.Save(user); err != nil {
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
	call := func(method, body string) *httptest.ResponseRecorder {
		t.Helper()
		request := httptest.NewRequest(method, "/api/v1/character", strings.NewReader(body))
		request.Header.Set("Content-Type", "application/json")
		request.Header.Set("Authorization", token)
		response := httptest.NewRecorder()
		mux.ServeHTTP(response, request)
		return response
	}
	defaults := call("GET", "")
	if defaults.Code != http.StatusOK || !strings.Contains(defaults.Body.String(), `"gender":"female"`) {
		t.Fatal("missing SSO default", defaults.Body.String())
	}
	for _, identity := range []struct{ username, gender string }{
		{strings.Repeat("名", 21), "male"}, {"\n", "male"}, {"a\nb", "male"}, {"valid", "invalid"},
	} {
		body, _ := json.Marshal(map[string]any{"name": identity.username, "gender": identity.gender, "appearance": Appearance{}, "bottom": "trousers"})
		if response := call("POST", string(body)); response.Code != http.StatusBadRequest {
			t.Fatal("accepted invalid identity", response.Body.String())
		}
	}
	username := strings.Repeat("😀", 20)
	body, _ := json.Marshal(map[string]any{"name": username, "gender": "male", "appearance": Appearance{}, "bottom": "trousers"})
	response := call("POST", string(body))
	if response.Code != http.StatusOK {
		t.Fatal(response.Body.String())
	}
	var state struct {
		Profile   struct{ Name, Gender string }
		Inventory []any
	}
	if err := json.Unmarshal(response.Body.Bytes(), &state); err != nil {
		t.Fatal(err)
	}
	if state.Profile.Name != username || state.Profile.Gender != "male" || len(state.Inventory) != 4 {
		t.Fatal("did not honor gender override or initial outfit")
	}
	user.Set("characterDefaults", CharacterDefaults{Name: "preferred-student", Gender: "female"})
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	if current := call("GET", ""); !strings.Contains(current.Body.String(), `"gender":"male"`) {
		t.Fatal("default gender overwrote character")
	}
}
