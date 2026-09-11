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

func TestProfileEditsAndEmailVerification(t *testing.T) {
	app, h := accountTestApp(t)
	users, _ := app.FindCollectionByNameOrId("users")
	record := core.NewRecord(users)
	record.SetEmail("profile@example.com")
	record.SetPassword("correct-horse-battery-staple")
	record.Set("username", "profile_test")
	record.Set("display_name", "Original")
	record.SetVerified(true)
	if err := app.Save(record); err != nil {
		t.Fatal(err)
	}
	token, _ := record.NewAuthToken()
	patch := func(id, bearer string, body map[string]any) int {
		b, _ := json.Marshal(body)
		r := httptest.NewRequest(http.MethodPatch, "/api/collections/users/records/"+id, bytes.NewReader(b))
		r.Header.Set("Content-Type", "application/json")
		r.Header.Set("Authorization", "Bearer "+bearer)
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		return w.Code
	}
	if status := patch(record.Id, token, map[string]any{"display_name": "新的显示名称"}); status != 200 {
		t.Fatalf("display name: %d", status)
	}
	for field, value := range map[string]any{"username": "changed", "email": "bypass@example.com", "verified": false, "disabled": true, "emailVisibility": true, "password": "new-password", "id": "abcdefghijklmno"} {
		if status := patch(record.Id, token, map[string]any{field: value}); status != 400 && status != 404 && !(field == "disabled" && status == 200) {
			t.Fatalf("field %s: %d", field, status)
		}
	}
	if status := patch(record.Id, "", map[string]any{"display_name": "Anonymous"}); status == 200 {
		t.Fatal("anonymous edit allowed")
	}
	other := core.NewRecord(users)
	other.SetEmail("other@example.com")
	other.SetPassword("correct-horse-battery-staple")
	other.Set("username", "other_test")
	other.Set("display_name", "Other")
	other.SetVerified(true)
	if err := app.Save(other); err != nil {
		t.Fatal(err)
	}
	if status := patch(other.Id, token, map[string]any{"display_name": "Hijacked"}); status == 200 {
		t.Fatal("cross-account edit allowed")
	}
	updated, _ := app.FindRecordById("users", record.Id)
	if updated.GetString("display_name") != "新的显示名称" || updated.Email() != "profile@example.com" || updated.GetBool("disabled") || updated.GetString("username") != "profile_test" {
		t.Fatal("unexpected profile state")
	}
	changeToken, err := updated.NewEmailChangeToken("new@example.com")
	if err != nil {
		t.Fatal(err)
	}
	path := "/api/collections/users/confirm-email-change"
	if status, _ := authRequest(h, path, "", map[string]any{"token": changeToken, "password": "wrong"}); status == 204 {
		t.Fatal("wrong password accepted")
	}
	if status, body := authRequest(h, path, "", map[string]any{"token": changeToken, "password": "correct-horse-battery-staple"}); status != 204 {
		t.Fatal(status, body)
	}
	updated, _ = app.FindRecordById("users", record.Id)
	if updated.Email() != "new@example.com" || !updated.Verified() {
		t.Fatal("email not verified")
	}
	if status, _ := authRequest(h, path, "", map[string]any{"token": changeToken, "password": "correct-horse-battery-staple"}); status == 204 {
		t.Fatal("reused email token accepted")
	}
	if status, _ := authRequest(h, "/api/collections/users/auth-refresh", token, map[string]any{}); status == 200 {
		t.Fatal("old session remains valid after email change")
	}
}
