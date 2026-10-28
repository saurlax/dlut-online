//go:build integration

package characters

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

func TestRegistrationRequiresVerifiedEmail(t *testing.T) {
	app := identityApp(t)
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	Register(&core.ServeEvent{App: app, Router: router})
	mux, err := router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	proof := strings.Repeat("a", 48)
	email := "register@example.com"
	code := "123456"
	collection, err := app.FindCollectionByNameOrId("registration_codes")
	if err != nil {
		t.Fatal(err)
	}
	pending := core.NewRecord(collection)
	pending.Set("email", email)
	pending.Set("codeHash", registrationHash(proof, email, code))
	pending.Set("browserHash", credentialHash(proof))
	pending.Set("expiresAt", time.Now().Add(time.Minute).Unix())
	pending.Set("sentAt", time.Now().Unix())
	if err := app.Save(pending); err != nil {
		t.Fatal(err)
	}
	call := func(path, confirm, suppliedCode, cookie string) int {
		body, _ := json.Marshal(map[string]string{"email": email, "password": "test-password", "passwordConfirm": confirm, "code": suppliedCode})
		req := httptest.NewRequest("POST", path, strings.NewReader(string(body)))
		req.Header.Set("Content-Type", "application/json")
		if cookie != "" {
			req.AddCookie(&http.Cookie{Name: registrationCookie, Value: cookie})
		}
		resp := httptest.NewRecorder()
		mux.ServeHTTP(resp, req)
		return resp.Code
	}
	if status := call("/api/collections/users/records", "test-password", code, proof); status == http.StatusOK || status == http.StatusCreated {
		t.Fatal("public PocketBase registration bypassed verification")
	}
	if status := call("/api/v1/registration", "wrong-password", code, proof); status != http.StatusBadRequest {
		t.Fatal("accepted mismatched passwords", status)
	}
	if status := call("/api/v1/registration", "test-password", "000000", proof); status != http.StatusBadRequest {
		t.Fatal("accepted incorrect code", status)
	}
	if status := call("/api/v1/registration", "test-password", code, strings.Repeat("b", 48)); status != http.StatusBadRequest {
		t.Fatal("accepted another browser", status)
	}
	if status := call("/api/v1/registration", "test-password", code, proof); status != http.StatusOK {
		t.Fatal("valid registration failed", status)
	}
	if status := call("/api/v1/registration", "test-password", code, proof); status != http.StatusBadRequest {
		t.Fatal("accepted reused code", status)
	}
	user, err := app.FindAuthRecordByEmail("users", email)
	if err != nil || !user.Verified() || !user.ValidatePassword("test-password") {
		t.Fatal("verified account was not created", err)
	}
}
