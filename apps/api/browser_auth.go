package main

import (
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

type browserAuthorization struct {
	Challenge, Redirect, State, Account, Code string
	Expires                                   time.Time
}

// Only desktop loopback redirects are supported today. Mobile callbacks must be
// explicitly registered when those clients ship, never accepted as arbitrary URLs.
func validBrowserRedirect(raw string) bool {
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "http" || u.Hostname() != "127.0.0.1" || u.User != nil || u.Path != "/callback" || u.RawQuery != "" || u.Fragment != "" {
		return false
	}
	p, err := strconv.Atoi(u.Port())
	return err == nil && p >= 1024 && p <= 65535 && u.Host == "127.0.0.1:"+strconv.Itoa(p)
}

func (g *gameAPI) browserStart(w http.ResponseWriter, r *http.Request) {
	if !sameOrigin(r) {
		reject(w, 403, "origin_rejected")
		return
	}
	var q struct {
		Challenge string `json:"challenge"`
		Redirect  string `json:"redirect_uri"`
		State     string `json:"state"`
	}
	if !decode(w, r, &q, 2048) {
		return
	}
	challenge, err := hex.DecodeString(q.Challenge)
	if err != nil || len(challenge) != 32 || !validBrowserRedirect(q.Redirect) || len(q.State) != 64 {
		reject(w, 400, "invalid_authorization_request")
		return
	}
	if _, err = hex.DecodeString(q.State); err != nil {
		reject(w, 400, "invalid_state")
		return
	}
	g.mu.Lock()
	defer g.mu.Unlock()
	now := g.now()
	for id, a := range g.browserRequests {
		if !now.Before(a.Expires) {
			delete(g.browserRequests, id)
		}
	}
	for ip, until := range g.browserStarts {
		if !now.Before(until) {
			delete(g.browserStarts, ip)
		}
	}
	ip, _, _ := net.SplitHostPort(r.RemoteAddr)
	if len(g.browserRequests) >= 128 || len(g.browserStarts) >= 128 || now.Before(g.browserStarts[ip]) {
		reject(w, 429, "rate_limited")
		return
	}
	id := randomID()
	g.browserRequests[id] = browserAuthorization{Challenge: strings.ToLower(q.Challenge), Redirect: q.Redirect, State: q.State, Expires: now.Add(5 * time.Minute)}
	g.browserStarts[ip] = now.Add(time.Second)
	respond(w, 201, map[string]any{"request": id, "login_path": "/login?request=" + url.QueryEscape(id), "expires_in": 300})
}

func (g *gameAPI) browserApprove(w http.ResponseWriter, r *http.Request) {
	if !sameOrigin(r) {
		reject(w, 403, "origin_rejected")
		return
	}
	identity, ok := g.requestAccount(r)
	if !ok {
		reject(w, 401, "invalid_auth_token")
		return
	}
	var q struct {
		Request string `json:"request"`
	}
	if !decode(w, r, &q, 1024) {
		return
	}
	g.mu.Lock()
	defer g.mu.Unlock()
	a, ok := g.browserRequests[q.Request]
	if !ok || !g.now().Before(a.Expires) || a.Account != "" {
		reject(w, 400, "authorization_expired")
		return
	}
	a.Account = identity.ID
	code := randomID()
	hash := sha256.Sum256([]byte(code))
	a.Code = hex.EncodeToString(hash[:])
	a.Expires = g.now().Add(30 * time.Second)
	g.browserRequests[q.Request] = a
	u, _ := url.Parse(a.Redirect)
	u.RawQuery = url.Values{"code": {code}, "state": {a.State}, "request": {q.Request}}.Encode()
	respond(w, 200, map[string]string{"redirect_uri": u.String()})
}

func (g *gameAPI) browserExchange(w http.ResponseWriter, r *http.Request) {
	if !sameOrigin(r) {
		reject(w, 403, "origin_rejected")
		return
	}
	var q struct {
		Request  string `json:"request"`
		Code     string `json:"code"`
		Verifier string `json:"verifier"`
	}
	if !decode(w, r, &q, 2048) {
		return
	}
	if len(q.Verifier) != 64 {
		reject(w, 400, "invalid_verifier")
		return
	}
	challenge := sha256.Sum256([]byte(q.Verifier))
	code := sha256.Sum256([]byte(q.Code))
	g.mu.Lock()
	a, ok := g.browserRequests[q.Request]
	valid := ok && a.Account != "" && g.now().Before(a.Expires) && subtle.ConstantTimeCompare([]byte(a.Challenge), []byte(hex.EncodeToString(challenge[:]))) == 1 && subtle.ConstantTimeCompare([]byte(a.Code), []byte(hex.EncodeToString(code[:]))) == 1
	if valid {
		delete(g.browserRequests, q.Request)
	}
	g.mu.Unlock()
	if !valid || g.accountSession == nil {
		reject(w, 401, "invalid_authorization_code")
		return
	}
	session, ok := g.accountSession(a.Account)
	if !ok {
		reject(w, 401, "invalid_account")
		return
	}
	respond(w, 200, session)
}

func (g *gameAPI) requestAccount(r *http.Request) (admission, bool) {
	auth := r.Header.Get("Authorization")
	if !strings.HasPrefix(auth, "Bearer ") || g.resolveAccount == nil {
		return admission{}, false
	}
	return g.resolveAccount(strings.TrimSpace(strings.TrimPrefix(auth, "Bearer ")))
}
