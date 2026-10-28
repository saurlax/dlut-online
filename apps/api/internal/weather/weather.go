package weather

import (
	"encoding/json"
	"fmt"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"net/http"
	"sync"
	"time"
)

type current struct {
	Time  int64 `json:"time"`
	Code  int   `json:"weather_code"`
	Cloud int   `json:"cloud_cover"`
}
type Snapshot struct {
	Weather    current `json:"weather"`
	ServerTime int64   `json:"serverTime"`
	Available  bool    `json:"available"`
}
type Service struct {
	mu         sync.Mutex
	value      current
	timeOffset time.Duration
	listeners  map[chan Snapshot]bool
	client     http.Client
}

func New() *Service {
	return &Service{client: http.Client{Timeout: 8 * time.Second}, listeners: map[chan Snapshot]bool{}}
}
func (s *Service) snapshot() Snapshot {
	return Snapshot{Weather: s.value, ServerTime: time.Now().Add(s.timeOffset).UnixMilli(), Available: s.value.Time != 0}
}
func (s *Service) broadcast() {
	v := s.snapshot()
	for c := range s.listeners {
		select {
		case c <- v:
		default:
		}
	}
}
func (s *Service) SetTime(hour, minute int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	local := now.In(time.FixedZone("CST", 8*3600))
	target := time.Date(local.Year(), local.Month(), local.Day(), hour, minute, 0, 0, local.Location())
	s.timeOffset = target.Sub(now)
	s.broadcast()
}
func (s *Service) SetWeather(code int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.value = current{Time: time.Now().Unix(), Code: code}
	s.broadcast()
}
func (s *Service) sync() {
	response, err := s.client.Get("https://api.open-meteo.com/v1/forecast?latitude=39.084522&longitude=121.816327&current=weather_code%2Ccloud_cover&timezone=Asia%2FShanghai&timeformat=unixtime&forecast_days=1")
	var v current
	if err == nil {
		defer response.Body.Close()
		var p struct {
			Current current `json:"current"`
		}
		if response.StatusCode == http.StatusOK && json.NewDecoder(response.Body).Decode(&p) == nil {
			v = p.Current
		}
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.timeOffset = 0
	if v.Time != 0 {
		s.value = v
	}
	s.broadcast()
}
func (s *Service) Start() {
	go func() {
		s.sync()
		ticker := time.NewTicker(15 * time.Minute)
		defer ticker.Stop()
		for range ticker.C {
			s.sync()
		}
	}()
}
func (s *Service) Register(e *core.ServeEvent) {
	e.Router.GET("/api/v1/weather", func(r *core.RequestEvent) error {
		s.mu.Lock()
		v := s.snapshot()
		s.mu.Unlock()
		return r.JSON(http.StatusOK, v)
	}).Bind(apis.RequireAuth("users"))
	e.Router.GET("/api/v1/weather/events", func(r *core.RequestEvent) error {
		c := make(chan Snapshot, 16)
		s.mu.Lock()
		s.listeners[c] = true
		c <- s.snapshot()
		s.mu.Unlock()
		defer func() { s.mu.Lock(); delete(s.listeners, c); s.mu.Unlock() }()
		r.Response.Header().Set("Content-Type", "text/event-stream")
		r.Response.Header().Set("Cache-Control", "no-cache")
		r.Response.Header().Set("X-Accel-Buffering", "no")
		controller := http.NewResponseController(r.Response)
		ticker := time.NewTicker(15 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case v := <-c:
				b, _ := json.Marshal(v)
				if _, err := fmt.Fprintf(r.Response, "data: %s\n\n", b); err != nil {
					return nil
				}
				if controller.Flush() != nil {
					return nil
				}
			case <-ticker.C:
				if _, err := fmt.Fprint(r.Response, ": ping\n\n"); err != nil {
					return nil
				}
				if controller.Flush() != nil {
					return nil
				}
			case <-r.Request.Context().Done():
				return nil
			}
		}
	}).Bind(apis.RequireAuth("users"))
}
