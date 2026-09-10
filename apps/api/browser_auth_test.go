package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"testing"
	"time"

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

func TestBrowserAuthorization(t *testing.T) {
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
	token := session["token"].(string)
	verifier := strings.Repeat("a", 64)
	sum := sha256.Sum256([]byte(verifier))
	start := map[string]any{"challenge": hex.EncodeToString(sum[:]), "state": strings.Repeat("b", 64), "redirect_uri": "http://127.0.0.1:54321/callback"}
	status, pending := authRequest(h, "/api/v1/auth/requests", "", start)
	if status != 201 {
		t.Fatal(status, pending)
	}
	approve := map[string]any{"request": pending["request"]}
	if status, _ = authRequest(h, "/api/v1/auth/approve", "", approve); status != 401 {
		t.Fatal("anonymous approval", status)
	}
	status, approved := authRequest(h, "/api/v1/auth/approve", token, approve)
	if status != 200 {
		t.Fatal(status, approved)
	}
	u, _ := url.Parse(approved["redirect_uri"].(string))
	if u.Query().Get("state") != start["state"] || strings.Contains(u.String(), token) {
		t.Fatal("unsafe callback")
	}
	exchange := map[string]any{"request": pending["request"], "code": u.Query().Get("code"), "verifier": strings.Repeat("c", 64)}
	if status, _ = authRequest(h, "/api/v1/auth/exchange", "", exchange); status != 401 {
		t.Fatal("incorrect proof accepted", status)
	}
	exchange["verifier"] = verifier
	var wg sync.WaitGroup
	results := make(chan int, 2)
	for i := 0; i < 2; i++ {
		wg.Go(func() {
			s, v := authRequest(h, "/api/v1/auth/exchange", "", exchange)
			if s == 200 {
				if _, err := app.FindAuthRecordByToken(v["token"].(string), core.TokenTypeAuth); err != nil {
					t.Error(err)
				}
			}
			results <- s
		})
	}
	wg.Wait()
	close(results)
	total := 0
	for s := range results {
		total += s
	}
	if total != 601 {
		t.Fatal("not atomic single use", total)
	}
	// Existing authorization must not revive an account disabled after approval.
	game := newGameAPI(gameConfig{}, app)
	challenge := sha256.Sum256([]byte(verifier))
	code := sha256.Sum256([]byte("approved-code"))
	game.browserRequests["pending"] = browserAuthorization{Challenge: hex.EncodeToString(challenge[:]), Code: hex.EncodeToString(code[:]), Account: record.Id, Expires: time.Now().Add(time.Minute)}
	record, _ = app.FindRecordById("users", record.Id)
	record.Set("disabled", true)
	if err = app.Save(record); err != nil {
		t.Fatal(err)
	}
	if status, _ = authRequest(h, "/api/v1/auth/approve", token, approve); status != 401 {
		t.Fatal("disabled approval", status)
	}
	if status, _ = authRequest(apiHandler(game, false), "/api/v1/auth/exchange", "", map[string]any{"request": "pending", "code": "approved-code", "verifier": verifier}); status != 401 {
		t.Fatal("disabled account exchanged authorization", status)
	}
}

func TestBrowserAuthorizationBoundaries(t *testing.T) {
	g := testGameAPI(gameConfig{}, "")
	now := time.Now()
	g.now = func() time.Time { return now }
	g.accountSession = func(id string) (map[string]any, bool) { return map[string]any{"id": id}, true }
	h := apiHandler(g, false)
	for _, uri := range []string{"https://evil.example/callback", "http://localhost:4000/callback", "http://127.0.0.1:4000/callback?x=1", "http://127.0.0.1:4000/callback#x", "http://127.0.0.1:80/callback", "http://user@127.0.0.1:4000/callback"} {
		if validBrowserRedirect(uri) {
			t.Fatal(uri)
		}
	}
	verifier := strings.Repeat("a", 64)
	sum := sha256.Sum256([]byte(verifier))
	create := func() map[string]any {
		now = now.Add(2 * time.Second)
		s, v := authRequest(h, "/api/v1/auth/requests", "", map[string]any{"challenge": hex.EncodeToString(sum[:]), "state": strings.Repeat("b", 64), "redirect_uri": "http://127.0.0.1:54321/callback"})
		if s != 201 {
			t.Fatal(s, v)
		}
		return v
	}
	pending := create()
	now = now.Add(301 * time.Second)
	if s, _ := authRequest(h, "/api/v1/auth/approve", "account12345678", map[string]any{"request": pending["request"]}); s != 400 {
		t.Fatal("expired request", s)
	}
	pending = create()
	_, approved := authRequest(h, "/api/v1/auth/approve", "account12345678", map[string]any{"request": pending["request"]})
	u, _ := url.Parse(approved["redirect_uri"].(string))
	now = now.Add(31 * time.Second)
	if s, _ := authRequest(h, "/api/v1/auth/exchange", "", map[string]any{"request": pending["request"], "code": u.Query().Get("code"), "verifier": verifier}); s != 401 {
		t.Fatal("expired code", s)
	}
	for _, token := range []string{"", "forged"} {
		if s, _ := authRequest(h, "/api/v1/game/tickets", token, map[string]any{"version": 4, "id": "0123456789ABCDE"}); s != 401 {
			t.Fatal("guest accepted", s)
		}
	}
}
