//go:build integration

package main

import (
	"bytes"
	"encoding/json"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/core"
)

func TestPocketBaseUsersCollection(t *testing.T) {
	app := newApplication(t.TempDir(), gameConfig{})
	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = app.ResetBootstrapState() })
	if err := app.RunAllMigrations(); err != nil {
		t.Fatal(err)
	}

	users, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		t.Fatal(err)
	}
	for _, field := range []string{"email", "password", "verified", "username", "display_name", "disabled"} {
		if users.Fields.GetByName(field) == nil {
			t.Fatalf("missing users field %q", field)
		}
	}
	if users.AuthRule == nil || *users.AuthRule != "verified = true && disabled = false" {
		t.Fatalf("unexpected auth rule: %v", users.AuthRule)
	}
	if users.CreateRule == nil || !strings.Contains(*users.CreateRule, "disabled:isset = false") || users.UpdateRule == nil || !strings.Contains(*users.UpdateRule, "disabled:changed = false") {
		t.Fatal("disabled field is not protected by API rules")
	}
	servers, err := app.FindCollectionByNameOrId("servers")
	if err != nil {
		t.Fatal(err)
	}
	for _, field := range []string{"name", "endpoint", "enabled"} {
		if servers.Fields.GetByName(field) == nil {
			t.Fatalf("missing servers field %q", field)
		}
	}

	create := func(email, username string) error {
		record := core.NewRecord(users)
		record.Set("email", email)
		record.SetPassword("correct-horse-battery-staple")
		record.Set("username", username)
		record.Set("display_name", "王同学")
		return app.Save(record)
	}
	if err := create("one@example.com", "Student_1"); err != nil {
		t.Fatal(err)
	}
	if err := create("two@example.com", "student_1"); err == nil {
		t.Fatal("case-insensitive duplicate username was accepted")
	}
	if err := create("three@example.com", "student-2"); err != nil {
		t.Fatal("duplicate display_name should be accepted:", err)
	}
}

func TestPocketBaseAccountTicket(t *testing.T) {
	app := newApplication(t.TempDir(), gameConfig{})
	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = app.ResetBootstrapState() })
	if err := app.RunAllMigrations(); err != nil {
		t.Fatal(err)
	}

	users, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		t.Fatal(err)
	}
	record := core.NewRecord(users)
	record.Set("email", "player@example.com")
	record.SetPassword("correct-horse-battery-staple")
	record.Set("verified", true)
	record.Set("username", "20260001")
	record.Set("display_name", "测试玩家")
	if err := app.Save(record); err != nil {
		t.Fatal(err)
	}
	servers, err := app.FindCollectionByNameOrId("servers")
	if err != nil {
		t.Fatal(err)
	}
	server := core.NewRecord(servers)
	server.Set("name", "main")
	server.Set("endpoint", "enet://game.example.com:1949")
	server.Set("enabled", true)
	if err := app.Save(server); err != nil {
		t.Fatal(err)
	}
	token, err := record.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}

	api := newGameAPI(gameConfig{apiKey: "service"}, app)
	router := apiHandler(api, false)
	request := func(path, bearer string, body any) (int, map[string]any) {
		payload, _ := json.Marshal(body)
		req := httptest.NewRequest("POST", path, bytes.NewReader(payload))
		if bearer != "" {
			req.Header.Set("Authorization", "Bearer "+bearer)
		}
		res := httptest.NewRecorder()
		router.ServeHTTP(res, req)
		value := map[string]any{}
		_ = json.Unmarshal(res.Body.Bytes(), &value)
		return res.Code, value
	}

	status, issued := request("/api/v1/game/tickets", token, map[string]any{
		"id":      "FORGED000000000",
		"version": 5,
	})
	if status != 201 {
		t.Fatal(status, issued)
	}
	status, identity := request("/api/v1/game/tickets/consume", "service", map[string]any{"ticket": issued["ticket"]})
	if status != 200 || identity["id"] != record.Id || identity["username"] != "测试玩家" || identity["kind"] != "account" {
		t.Fatal(status, identity)
	}
	record.Set("verified", false)
	if err := app.Save(record); err != nil {
		t.Fatal(err)
	}
	if status, _ := request("/api/v1/game/tickets", token, map[string]any{"version": 5}); status != 401 {
		t.Fatal("unverified account received ticket", status)
	}
	record.Set("verified", true)

	record.Set("disabled", true)
	if err := app.Save(record); err != nil {
		t.Fatal(err)
	}
	status, _ = request("/api/v1/game/tickets", token, map[string]any{"version": 5})
	if status != 401 {
		t.Fatalf("disabled account ticket status = %d", status)
	}
}
