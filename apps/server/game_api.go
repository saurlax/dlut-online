package main

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strconv"
	"sync"
	"time"

	"github.com/go-chi/chi/v5"
)

type gameConfig struct{ upstream, serviceToken, adminToken string }
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
}

func randomID() string {
	var b [32]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic(err)
	}
	return base64.RawURLEncoding.EncodeToString(b[:])
}
func guestName(id string) (string, bool) {
	b, err := hex.DecodeString(id)
	if err != nil || len(b) != 16 || hex.EncodeToString(b) != id {
		return "", false
	}
	n, _ := strconv.ParseUint(id[:8], 16, 32)
	return fmt.Sprintf("游客%06d", n%1000000), true
}
func campusValid(s string) bool { return s == "lingshui" || s == "eda" || s == "panjin" }
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
func newGameAPI(c gameConfig) *gameAPI {
	return &gameAPI{config: c, tickets: make(map[[32]byte]admission), issued: make(map[string]time.Time), retired: make(map[string]bool), now: time.Now, seq: -1}
}
func (g *gameAPI) auth(token string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		got := r.Header.Get("Authorization")
		want := "Bearer " + token
		if token == "" || subtle.ConstantTimeCompare([]byte(got), []byte(want)) != 1 {
			reject(w, 401, "unauthorized")
			return
		}
		next(w, r)
	}
}
func (g *gameAPI) routes(r chi.Router) {
	r.Get("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = io.WriteString(w, `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>DLUT Online</title><body><h1>DLUT Online</h1><p><a href="/web/">进入游戏</a></p></body></html>`)
	})
	r.Post("/api/v1/game/tickets", g.issue)
	r.Post("/internal/v1/game/tickets/consume", g.auth(g.config.serviceToken, g.consume))
	r.Post("/internal/v1/game/register", g.auth(g.config.serviceToken, g.register))
	r.Post("/internal/v1/game/presence", g.auth(g.config.serviceToken, g.presence))
	r.Get("/api/v1/game/online", g.online)
	r.Get("/api/v1/admin/game/players", g.auth(g.config.adminToken, g.details))
	upstream, err := url.Parse(g.config.upstream)
	r.Get("/ws", func(w http.ResponseWriter, r *http.Request) {
		if !sameOrigin(r) {
			reject(w, 403, "origin_rejected")
			return
		}
		if err != nil || upstream.Host == "" {
			reject(w, 503, "game_unavailable")
			return
		}
		proxy := httputil.NewSingleHostReverseProxy(upstream)
		proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, e error) { reject(w, 502, "game_unavailable") }
		proxy.ServeHTTP(w, r)
	})
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
	name, ok := guestName(q.ID)
	if !ok || q.Version != 2 {
		reject(w, 400, "invalid_identity_or_version")
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
	if last, exists := g.issued[q.ID]; exists && now.Sub(last) < time.Second {
		reject(w, 429, "rate_limited")
		return
	}
	if len(g.tickets) >= 512 || len(g.issued) >= 100 {
		reject(w, 429, "rate_limited")
		return
	}
	ticket := randomID()
	g.tickets[sha256.Sum256([]byte(ticket))] = admission{ID: q.ID, Username: name, Kind: "guest", AdmissionID: randomID(), Expires: now.Add(30 * time.Second)}
	g.issued[q.ID] = now
	respond(w, 201, map[string]any{"ticket": ticket, "expires_in": 30, "ws_path": "/ws", "version": 2})
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
		name, ok := guestName(p.ID)
		if !ok || p.Kind != "guest" || name != p.Username || !campusValid(p.Campus) || seen[p.ID] || p.JoinedAt <= 0 {
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
