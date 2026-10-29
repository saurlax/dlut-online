package guest

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math/big"
	"net/http"
	"sync"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

type Identity struct {
	ID, Name string
	Expires  time.Time
}
type Service struct {
	mu       sync.Mutex
	sessions map[[32]byte]Identity
}

func New() *Service { return &Service{sessions: map[[32]byte]Identity{}} }
func (s *Service) Resolve(r *core.RequestEvent) (Identity, bool) {
	if r.Auth != nil && r.Auth.Collection().Name == "users" {
		return Identity{ID: r.Auth.Id}, true
	}
	return s.ResolveToken(r.Request.Header.Get("Authorization"))
}
func (s *Service) ResolveToken(token string) (Identity, bool) {
	hash := sha256.Sum256([]byte(token))
	s.mu.Lock()
	defer s.mu.Unlock()
	identity, ok := s.sessions[hash]
	if !ok || time.Now().After(identity.Expires) {
		delete(s.sessions, hash)
		return Identity{}, false
	}
	return identity, true
}
func (s *Service) Register(e *core.ServeEvent) {
	e.Router.POST("/api/v1/guest", func(r *core.RequestEvent) error {
		var secret [32]byte
		if _, err := rand.Read(secret[:]); err != nil {
			return err
		}
		number, err := rand.Int(rand.Reader, big.NewInt(1000000))
		if err != nil {
			return err
		}
		token := hex.EncodeToString(secret[:])
		id := fmt.Sprintf("游客%06d", number.Int64())
		expiry := time.Now().Add(12 * time.Hour)
		s.mu.Lock()
		for key, v := range s.sessions {
			if time.Now().After(v.Expires) {
				delete(s.sessions, key)
			}
		}
		s.sessions[sha256.Sum256([]byte(token))] = Identity{ID: token, Name: id, Expires: expiry}
		s.mu.Unlock()
		return r.JSON(http.StatusOK, map[string]any{"token": token, "name": id, "expiresAt": expiry.UnixMilli()})
	})
}
