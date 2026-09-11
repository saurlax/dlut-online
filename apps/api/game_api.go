package main

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

type gameConfig struct{ environment, apiKey string }
type admission struct {
	ID          string    `json:"id"`
	Username    string    `json:"username"`
	Kind        string    `json:"kind"`
	AdmissionID string    `json:"admission_id"`
	Expires     time.Time `json:"-"`
}
type onlinePlayer struct {
	ID       string `json:"id"`
	Username string `json:"username"`
	Kind     string `json:"kind"`
	Campus   string `json:"campus"`
	JoinedAt int64  `json:"joined_at"`
}
type apiRoute struct {
	method  string
	path    string
	handler http.Handler
}
type gameAPI struct {
	mu                    sync.Mutex
	config                gameConfig
	tickets               map[[32]byte]admission
	issued                map[string]time.Time
	now                   func() time.Time
	instance, boot, epoch string
	retired               map[string]bool
	seq                   int64
	received              time.Time
	players               []onlinePlayer
	resolveAccount        func(string) (admission, bool)
	resolveGameEndpoint   func() (string, bool)
}

func randomID() string {
	var b [32]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic(err)
	}
	return base64.RawURLEncoding.EncodeToString(b[:])
}
func validPlayerID(id string) bool {
	if len(id) != 15 {
		return false
	}
	for _, c := range id {
		if (c < 'a' || c > 'z') && (c < '0' || c > '9') {
			return false
		}
	}
	return true
}
func campusValid(s string) bool { return s == "lingshui" || s == "eda" || s == "panjin" }
func validGameEndpoint(raw string) bool {
	u, err := url.Parse(raw)
	if err != nil || (u.Scheme != "enet" && u.Scheme != "enets") || u.Hostname() == "" || u.User != nil || u.Path != "" || u.RawQuery != "" || u.Fragment != "" {
		return false
	}
	p, err := strconv.Atoi(u.Port())
	return err == nil && p > 0 && p <= 65535
}
func sameOrigin(r *http.Request) bool {
	o := r.Header.Get("Origin")
	if o == "" {
		return true
	}
	u, e := url.Parse(o)
	return e == nil && (u.Scheme == "http" || u.Scheme == "https") && u.Host == r.Host && u.User == nil && u.Path == "" && u.RawQuery == "" && u.Fragment == ""
}
func respond(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
func reject(w http.ResponseWriter, status int, code string) {
	respond(w, status, map[string]string{"error": code})
}
func decode(w http.ResponseWriter, r *http.Request, v any, limit int64) bool {
	r.Body = http.MaxBytesReader(w, r.Body, limit)
	d := json.NewDecoder(r.Body)
	d.DisallowUnknownFields()
	if d.Decode(v) != nil {
		reject(w, 400, "invalid_request")
		return false
	}
	if d.Decode(new(any)) != io.EOF {
		reject(w, 400, "invalid_request")
		return false
	}
	return true
}
func newGameAPI(c gameConfig, apps ...core.App) *gameAPI {
	g := &gameAPI{config: c, tickets: make(map[[32]byte]admission), issued: make(map[string]time.Time), retired: make(map[string]bool), now: time.Now, seq: -1}
	if len(apps) > 0 && apps[0] != nil {
		app := apps[0]
		g.resolveGameEndpoint = func() (string, bool) {
			record, err := app.FindFirstRecordByFilter("servers", "enabled = true")
			if err != nil {
				return "", false
			}
			endpoint := strings.TrimSpace(record.GetString("endpoint"))
			if !validGameEndpoint(endpoint) || (c.environment == "production" && !strings.HasPrefix(endpoint, "enets://")) {
				return "", false
			}
			return endpoint, true
		}
		g.resolveAccount = func(token string) (admission, bool) {
			record, err := app.FindAuthRecordByToken(token, core.TokenTypeAuth)
			if err != nil || record.Collection().Name != "users" || !record.Verified() || record.GetBool("disabled") || !validPlayerID(record.Id) {
				return admission{}, false
			}
			name := strings.TrimSpace(record.GetString("display_name"))
			if name == "" || len([]rune(name)) > 64 {
				return admission{}, false
			}
			return admission{ID: record.Id, Username: name, Kind: "account"}, true
		}
	}
	return g
}
func (g *gameAPI) apiKeyAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		got := r.Header.Get("Authorization")
		want := "Bearer " + g.config.apiKey
		if g.config.apiKey == "" || subtle.ConstantTimeCompare([]byte(got), []byte(want)) != 1 {
			reject(w, 401, "unauthorized")
			return
		}
		next(w, r)
	}
}
func (g *gameAPI) routes() []apiRoute {
	return []apiRoute{
		{http.MethodPost, "/api/v1/game/tickets", http.HandlerFunc(g.issue)},
		{http.MethodPost, "/api/v1/game/tickets/consume", http.HandlerFunc(g.apiKeyAuth(g.consume))},
		{http.MethodPost, "/api/v1/game/register", http.HandlerFunc(g.apiKeyAuth(g.register))},
		{http.MethodPost, "/api/v1/game/presence", http.HandlerFunc(g.apiKeyAuth(g.presence))},
		{http.MethodGet, "/api/v1/game/online", http.HandlerFunc(g.online)},
		{http.MethodGet, "/api/v1/admin/game/players", http.HandlerFunc(g.apiKeyAuth(g.details))},
	}
}
func (g *gameAPI) issue(w http.ResponseWriter, r *http.Request) {
	if !sameOrigin(r) {
		reject(w, 403, "origin_rejected")
		return
	}
	var q struct {
		ID      string `json:"id"`
		Version int    `json:"version"`
	}
	if !decode(w, r, &q, 1024) {
		return
	}
	if q.Version != 4 {
		reject(w, 400, "invalid_identity_or_version")
		return
	}
	identity, authenticated := g.requestAccount(r)
	if !authenticated {
		reject(w, 401, "invalid_auth_token")
		return
	}
	if g.resolveGameEndpoint == nil {
		reject(w, 503, "game_server_unavailable")
		return
	}
	endpoint, ok := g.resolveGameEndpoint()
	if !ok {
		reject(w, 503, "game_server_unavailable")
		return
	}
	g.mu.Lock()
	defer g.mu.Unlock()
	now := g.now()
	for k, v := range g.tickets {
		if !now.Before(v.Expires) {
			delete(g.tickets, k)
		}
	}
	for k, v := range g.issued {
		if now.Sub(v) >= time.Second {
			delete(g.issued, k)
		}
	}
	if last, exists := g.issued[identity.ID]; exists && now.Sub(last) < time.Second {
		reject(w, 429, "rate_limited")
		return
	}
	if len(g.tickets) >= 512 || len(g.issued) >= 100 {
		reject(w, 429, "rate_limited")
		return
	}
	ticket := randomID()
	identity.AdmissionID = randomID()
	identity.Expires = now.Add(30 * time.Second)
	g.tickets[sha256.Sum256([]byte(ticket))] = identity
	g.issued[identity.ID] = now
	respond(w, 201, map[string]any{"ticket": ticket, "expires_in": 30, "game_server_url": endpoint, "version": 4})
}
func (g *gameAPI) consume(w http.ResponseWriter, r *http.Request) {
	var q struct {
		Ticket string `json:"ticket"`
	}
	if !decode(w, r, &q, 1024) {
		return
	}
	g.mu.Lock()
	defer g.mu.Unlock()
	key := sha256.Sum256([]byte(q.Ticket))
	a, ok := g.tickets[key]
	delete(g.tickets, key)
	if !ok || !g.now().Before(a.Expires) {
		reject(w, 401, "invalid_ticket")
		return
	}
	respond(w, 200, a)
}
func (g *gameAPI) register(w http.ResponseWriter, r *http.Request) {
	var q struct {
		Instance string `json:"instance_id"`
		Boot     string `json:"boot_id"`
	}
	if !decode(w, r, &q, 1024) {
		return
	}
	if len(q.Instance) == 0 || len(q.Instance) > 64 || len(q.Boot) < 16 || len(q.Boot) > 128 {
		reject(w, 400, "invalid_instance")
		return
	}
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.instance != "" && g.instance != q.Instance {
		reject(w, 409, "single_instance_only")
		return
	}
	if g.retired[q.Boot] {
		reject(w, 409, "retired_boot")
		return
	}
	if q.Boot != g.boot {
		if len(g.retired) >= 4096 {
			reject(w, 503, "registration_capacity")
			return
		}
		if g.boot != "" {
			g.retired[g.boot] = true
		}
		g.instance = q.Instance
		g.boot = q.Boot
		g.epoch = randomID()
		g.seq = -1
		g.received = time.Time{}
		g.players = nil
	}
	respond(w, 200, map[string]string{"epoch": g.epoch})
}
func (g *gameAPI) presence(w http.ResponseWriter, r *http.Request) {
	var q struct {
		Instance string         `json:"instance_id"`
		Epoch    string         `json:"epoch"`
		Seq      int64          `json:"seq"`
		Players  []onlinePlayer `json:"players"`
	}
	if !decode(w, r, &q, 32768) {
		return
	}
	if q.Seq < 0 || len(q.Players) > 50 {
		reject(w, 400, "invalid_presence")
		return
	}
	seen := map[string]bool{}
	for _, p := range q.Players {
		validIdentity := p.Kind == "account" && validPlayerID(p.ID) && strings.TrimSpace(p.Username) != "" && len([]rune(p.Username)) <= 64
		if !validIdentity || !campusValid(p.Campus) || seen[p.ID] || p.JoinedAt <= 0 {
			reject(w, 400, "invalid_player")
			return
		}
		seen[p.ID] = true
	}
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.epoch == "" || q.Instance != g.instance || q.Epoch != g.epoch {
		reject(w, 409, "registration_required")
		return
	}
	if q.Seq <= g.seq {
		reject(w, 409, "stale_sequence")
		return
	}
	g.seq = q.Seq
	g.received = g.now()
	g.players = append([]onlinePlayer{}, q.Players...)
	respond(w, 200, map[string]bool{"ok": true})
}
func (g *gameAPI) view() map[string]any {
	status := "live"
	if g.received.IsZero() {
		status = "unavailable"
	} else if g.now().Sub(g.received) > 15*time.Second {
		status = "stale"
	}
	out := map[string]any{"status": status, "total": nil, "campuses": nil, "received_at": nil}
	if !g.received.IsZero() {
		out["received_at"] = g.received.UTC()
		out["last_total"] = len(g.players)
	}
	if status == "live" {
		counts := map[string]int{"lingshui": 0, "eda": 0, "panjin": 0}
		for _, p := range g.players {
			counts[p.Campus]++
		}
		out["total"] = len(g.players)
		out["campuses"] = counts
	}
	return out
}
func (g *gameAPI) online(w http.ResponseWriter, r *http.Request) {
	g.mu.Lock()
	defer g.mu.Unlock()
	respond(w, 200, g.view())
}
func (g *gameAPI) details(w http.ResponseWriter, r *http.Request) {
	g.mu.Lock()
	defer g.mu.Unlock()
	v := g.view()
	v["players"] = nil
	if v["status"] == "live" {
		v["players"] = append([]onlinePlayer{}, g.players...)
	}
	respond(w, 200, v)
}

func (g *gameAPI) requestAccount(r *http.Request) (admission, bool) {
	auth := r.Header.Get("Authorization")
	if !strings.HasPrefix(auth, "Bearer ") || g.resolveAccount == nil {
		return admission{}, false
	}
	return g.resolveAccount(strings.TrimSpace(strings.TrimPrefix(auth, "Bearer ")))
}
