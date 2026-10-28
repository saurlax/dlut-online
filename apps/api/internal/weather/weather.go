package weather

import (
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type current struct {
	Time  int64 `json:"time"`
	Code  int   `json:"weather_code"`
	Cloud int   `json:"cloud_cover"`
}
type service struct {
	mu      sync.Mutex
	value   current
	fetched time.Time
	client  http.Client
}

func Register(e *core.ServeEvent) {
	s := &service{client: http.Client{Timeout: 8 * time.Second}}
	e.Router.GET("/api/v1/weather", func(r *core.RequestEvent) error {
		s.mu.Lock()
		defer s.mu.Unlock()
		if time.Since(s.fetched) >= 15*time.Minute {
			response, err := s.client.Get("https://api.open-meteo.com/v1/forecast?latitude=39.084522&longitude=121.816327&current=weather_code%2Ccloud_cover&timezone=Asia%2FShanghai&timeformat=unixtime&forecast_days=1")
			if err != nil {
				return r.InternalServerError("天气暂时不可用", nil)
			}
			defer response.Body.Close()
			var payload struct {
				Current current `json:"current"`
			}
			if response.StatusCode != http.StatusOK || json.NewDecoder(response.Body).Decode(&payload) != nil || payload.Current.Time == 0 {
				return r.InternalServerError("天气暂时不可用", nil)
			}
			s.value = payload.Current
			s.fetched = time.Now()
		}
		return r.JSON(http.StatusOK, map[string]any{"weather": s.value, "serverTime": time.Now().UnixMilli()})
	}).Bind(apis.RequireAuth("users"))
}
