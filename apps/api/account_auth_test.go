//go:build integration

package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

func accountTestApp(t *testing.T) (*pocketbase.PocketBase, http.Handler) {
	t.Helper()
	app := newApplication(t.TempDir(), gameConfig{apiKey: strings.Repeat("s", 32)})
	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = app.ResetBootstrapState() })
	if err := app.RunAllMigrations(); err != nil {
		t.Fatal(err)
	}
	r, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	e := &core.ServeEvent{App: app, Router: r}
	if err = app.OnServe().Trigger(e, func(e *core.ServeEvent) error { return nil }); err != nil {
		t.Fatal(err)
	}
	h, err := r.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	return app, h
}

func authRequest(h http.Handler, path, token string, body any) (int, map[string]any) {
	b, _ := json.Marshal(body)
	r := httptest.NewRequest("POST", path, bytes.NewReader(b))
	r.Header.Set("Content-Type", "application/json")
	if token != "" {
		r.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	v := map[string]any{}
	_ = json.Unmarshal(w.Body.Bytes(), &v)
	return w.Code, v
}

func TestPasswordAuthentication(t *testing.T) {
	app, h := accountTestApp(t)
	credentials := map[string]any{"email": "browser@example.com", "username": "browser_test", "display_name": "Browser player", "password": "correct-horse-battery-staple", "passwordConfirm": "correct-horse-battery-staple"}
	if status, body := authRequest(h, "/api/collections/users/records", "", credentials); status != 200 {
		t.Fatal(status, body)
	}
	login := map[string]any{"identity": credentials["email"], "password": credentials["password"]}
	if status, _ := authRequest(h, "/api/collections/users/auth-with-password", "", login); status == 200 {
		t.Fatal("unverified login")
	}
	record, err := app.FindAuthRecordByEmail("users", "browser@example.com")
	if err != nil {
		t.Fatal(err)
	}
	verification, err := record.NewVerificationToken()
	if err != nil {
		t.Fatal(err)
	}
	if status, body := authRequest(h, "/api/collections/users/confirm-verification", "", map[string]any{"token": verification}); status != 204 {
		t.Fatal(status, body)
	}
	status, session := authRequest(h, "/api/collections/users/auth-with-password", "", login)
	if status != 200 {
		t.Fatal(status, session)
	}
	if session["token"] == "" {
		t.Fatal("missing account token")
	}
	if status, _ := authRequest(h, "/api/collections/users/auth-with-password", "", map[string]any{"identity": credentials["email"], "password": "wrong-password"}); status == 200 {
		t.Fatal("wrong password accepted")
	}
	record, _ = app.FindAuthRecordByEmail("users", "browser@example.com")
	record.Set("disabled", true)
	if err := app.Save(record); err != nil {
		t.Fatal(err)
	}
	if status, _ := authRequest(h, "/api/collections/users/auth-with-password", "", login); status == 200 {
		t.Fatal("disabled account accepted")
	}
	for _, path := range []string{"/api/v1/auth/requests", "/api/v1/auth/approve", "/api/v1/auth/exchange"} {
		if status, _ := authRequest(h, path, "", map[string]any{}); status != 404 && status != 405 {
			t.Fatalf("removed callback route %s: %d", path, status)
		}
	}
}

func TestAccountTokenRefresh(t *testing.T) {
	app, handler := accountTestApp(t)
	users, _ := app.FindCollectionByNameOrId("users")
	record := core.NewRecord(users)
	record.SetEmail("refresh@example.com")
	record.SetPassword("correct-horse-battery-staple")
	record.Set("username", "refresh_test")
	record.Set("display_name", "Refresh player")
	record.SetVerified(true)
	if err := app.Save(record); err != nil {
		t.Fatal(err)
	}
	token, err := record.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	status, body := authRequest(handler, "/api/collections/users/auth-refresh", token, map[string]any{})
	if status != 200 || body["token"] == "" || body["record"] == nil {
		t.Fatalf("refresh failed: %d", status)
	}
	if _, exists := body["refreshToken"]; exists {
		t.Fatal("unexpected separate refresh token")
	}
	record.Set("disabled", true)
	if err := app.Save(record); err != nil {
		t.Fatal(err)
	}
	if status, _ := authRequest(handler, "/api/collections/users/auth-refresh", token, map[string]any{}); status == 200 {
		t.Fatal("disabled account refreshed")
	}
	if status, _ := authRequest(handler, "/api/collections/users/auth-refresh", "expired.invalid.token", map[string]any{}); status == 200 {
		t.Fatal("invalid token refreshed")
	}
}
