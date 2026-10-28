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
	"github.com/pocketbase/pocketbase/tools/security"
)

func TestOnboardingBrowserProofExpiryReplayAndBinding(t *testing.T) {
	app := identityApp(t)
	users, _ := app.FindCollectionByNameOrId("users")
	user := core.NewRecord(users)
	user.SetEmail("onboarding@example.com")
	user.SetPassword("onboarding-test-password")
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
	browser := strings.Repeat("a", 48)
	seed := func(subject string, expiry time.Time) (string, *core.Record) {
		t.Helper()
		ticket := security.RandomString(48)
		collection, _ := app.FindCollectionByNameOrId("sso_onboarding")
		record := core.NewRecord(collection)
		record.Set("ticketHash", credentialHash(ticket))
		record.Set("browserHash", credentialHash(browser))
		record.Set("subject", subject)
		record.Set("defaults", CharacterDefaults{Name: "SSO preferred name", Gender: "female"})
		record.Set("expiresAt", expiry.Unix())
		if err := app.Save(record); err != nil {
			t.Fatal(err)
		}
		return ticket, record
	}
	call := func(path, ticket, cookie, auth string) *httptest.ResponseRecorder {
		t.Helper()
		body, _ := json.Marshal(map[string]string{"ticket": ticket, "subject": "untrusted-subject"})
		request := httptest.NewRequest("POST", path, strings.NewReader(string(body)))
		request.Header.Set("Content-Type", "application/json")
		request.Header.Set("Authorization", auth)
		if cookie != "" {
			request.AddCookie(&http.Cookie{Name: onboardingCookie, Value: cookie})
		}
		response := httptest.NewRecorder()
		mux.ServeHTTP(response, request)
		return response
	}
	ticket, _ := seed("verified-subject", time.Now().Add(onboardingLifetime))
	for _, cookie := range []string{"", strings.Repeat("b", 48)} {
		if response := call("/api/v1/sso/onboarding/inspect", ticket, cookie, ""); response.Code != http.StatusBadRequest {
			t.Fatal("accepted wrong browser")
		}
	}
	if response := call("/api/v1/sso/onboarding/inspect", ticket, browser, ""); response.Code != http.StatusOK {
		t.Fatal("valid ticket cannot be inspected")
	}
	if response := call("/api/v1/sso/onboarding/complete", ticket, browser, ""); response.Code != http.StatusUnauthorized {
		t.Fatal("ticket became an account login token")
	}
	if response := call("/api/v1/sso/onboarding/complete", ticket, strings.Repeat("b", 48), token); response.Code != http.StatusBadRequest {
		t.Fatal("completed in another browser")
	}
	if response := call("/api/v1/sso/onboarding/complete", ticket, browser, token); response.Code != http.StatusOK {
		t.Fatalf("completion failed HTTP %d", response.Code)
	}
	if response := call("/api/v1/sso/onboarding/complete", ticket, browser, token); response.Code != http.StatusBadRequest {
		t.Fatal("accepted replay")
	}
	links, err := app.FindAllExternalAuthsByRecord(user)
	if err != nil || len(links) != 1 || links[0].ProviderId() != "verified-subject" {
		t.Fatal("trusted client subject instead of verified ticket identity", err)
	}
	accountRequest := httptest.NewRequest("GET", "/api/v1/account", nil)
	accountRequest.Header.Set("Authorization", token)
	accountResponse := httptest.NewRecorder()
	mux.ServeHTTP(accountResponse, accountRequest)
	var accountInfo struct {
		Email       string `json:"email"`
		OIDCBound   bool   `json:"oidcBound"`
		OIDCSubject string `json:"oidcSubject"`
	}
	if accountResponse.Code != http.StatusOK || json.Unmarshal(accountResponse.Body.Bytes(), &accountInfo) != nil || accountInfo.Email != user.Email() || !accountInfo.OIDCBound || accountInfo.OIDCSubject != "verified-subject" {
		t.Fatal("account details do not contain the bound identity")
	}
	current, _ := app.FindRecordById("users", user.Id)
	if current.Email() != user.Email() || !current.ValidatePassword("onboarding-test-password") || current.Verified() {
		t.Fatal("binding changed local credentials")
	}
	var defaults CharacterDefaults
	if err := current.UnmarshalJSONField("characterDefaults", &defaults); err != nil || defaults.Gender != "female" {
		t.Fatal("lost SSO defaults", err)
	}
	expired, _ := seed("expired-subject", time.Now().Add(-time.Second))
	if response := call("/api/v1/sso/onboarding/complete", expired, browser, token); response.Code != http.StatusBadRequest {
		t.Fatal("accepted expired ticket")
	}
	conflict, pending := seed("another-subject", time.Now().Add(onboardingLifetime))
	if response := call("/api/v1/sso/onboarding/complete", conflict, browser, token); response.Code != http.StatusBadRequest {
		t.Fatal("replaced existing binding")
	}
	if _, err := app.FindRecordById("sso_onboarding", pending.Id); err != nil {
		t.Fatal("failed transaction consumed ticket")
	}
	for _, path := range []string{"/api/collections/sso_onboarding/records", "/api/collections/sso_onboarding/records/" + pending.Id} {
		request := httptest.NewRequest("GET", path, nil)
		request.Header.Set("Authorization", token)
		response := httptest.NewRecorder()
		mux.ServeHTTP(response, request)
		if response.Code == http.StatusOK {
			t.Fatal("exposed private onboarding collection")
		}
	}
}
