package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"sync"
	"time"
)

// Official campus map centres, approximate source coordinates (see references/README.md).
var weatherLocations = map[string][2]float64{
	"lingshui": {38.879216, 121.526959},
	"eda":      {39.084522, 121.816327},
	"panjin":   {40.686249, 122.124453},
}

type weatherConfig struct {
	interval time.Duration
	apiKey   string
}

func readWeatherConfig() (weatherConfig, error) {
	minutes := 15
	if raw := os.Getenv("DO_WEATHER_REFRESH_MINUTES"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n < 5 || n > 180 {
			return weatherConfig{}, fmt.Errorf("DO_WEATHER_REFRESH_MINUTES must be 5-180")
		}
		minutes = n
	}
	return weatherConfig{time.Duration(minutes) * time.Minute, os.Getenv("DO_WEATHER_API_KEY")}, nil
}

type campusWeather struct {
	Status        string  `json:"status"`
	ObservedAt    int64   `json:"observed_at"`
	FetchedAt     int64   `json:"fetched_at"`
	CloudCover    float64 `json:"cloud_cover"`
	Code          int     `json:"weather_code"`
	WindSpeed     float64 `json:"wind_speed"`
	WindDirection float64 `json:"wind_direction"`
}
type weatherEntry struct {
	value campusWeather
	next  time.Time
	busy  bool
}
type weatherService struct {
	mu      sync.Mutex
	config  weatherConfig
	client  *http.Client
	entries map[string]*weatherEntry
	now     func() time.Time
}

func newWeatherService(config weatherConfig) *weatherService {
	if config.interval == 0 {
		config.interval = 15 * time.Minute
	}
	s := &weatherService{config: config, client: &http.Client{Timeout: 8 * time.Second}, entries: map[string]*weatherEntry{}, now: time.Now}
	for id := range weatherLocations {
		s.entries[id] = &weatherEntry{value: campusWeather{Status: "unavailable"}}
	}
	return s
}
func (s *weatherService) snapshot() map[string]campusWeather {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := s.now()
	result := map[string]campusWeather{}
	for id, entry := range s.entries {
		if !entry.busy && !now.Before(entry.next) {
			entry.busy = true
			go s.refresh(id)
		}
		value := entry.value
		if value.ObservedAt > 0 {
			value.Status = "live"
			if now.Sub(time.Unix(value.ObservedAt, 0)) > time.Hour {
				value.Status = "stale"
			}
		}
		result[id] = value
	}
	return result
}
func (s *weatherService) refresh(id string) {
	value, err := s.fetch(id)
	s.mu.Lock()
	defer s.mu.Unlock()
	entry := s.entries[id]
	entry.busy = false
	if err != nil {
		entry.next = s.now().Add(time.Minute)
		// Do not log the upstream URL, which can contain the commercial API key.
		slog.Warn("Weather refresh failed; keeping previous sample", "campus", id)
		return
	}
	entry.value = value
	entry.next = s.now().Add(s.config.interval)
}
func (s *weatherService) fetch(id string) (campusWeather, error) {
	location := weatherLocations[id]
	q := url.Values{"latitude": {strconv.FormatFloat(location[0], 'f', 6, 64)}, "longitude": {strconv.FormatFloat(location[1], 'f', 6, 64)},
		"current": {"cloud_cover,weather_code,wind_speed_10m,wind_direction_10m"}, "wind_speed_unit": {"ms"}, "timeformat": {"unixtime"}, "timezone": {"Asia/Shanghai"}, "forecast_days": {"1"}}
	endpoint := "https://api.open-meteo.com/v1/forecast"
	if s.config.apiKey != "" {
		endpoint = "https://customer-api.open-meteo.com/v1/forecast"
		q.Set("apikey", s.config.apiKey)
	}
	response, err := s.client.Get(endpoint + "?" + q.Encode())
	if err != nil {
		return campusWeather{}, fmt.Errorf("weather request failed")
	}
	defer response.Body.Close()
	if response.StatusCode != 200 {
		return campusWeather{}, fmt.Errorf("weather HTTP status %d", response.StatusCode)
	}
	var payload struct {
		Current struct {
			Time      int64    `json:"time"`
			Cloud     *float64 `json:"cloud_cover"`
			Code      *int     `json:"weather_code"`
			Speed     *float64 `json:"wind_speed_10m"`
			Direction *float64 `json:"wind_direction_10m"`
		} `json:"current"`
	}
	if err := json.NewDecoder(io.LimitReader(response.Body, 32768)).Decode(&payload); err != nil {
		return campusWeather{}, fmt.Errorf("invalid weather JSON")
	}
	c := payload.Current
	now := s.now()
	if c.Cloud == nil || c.Code == nil || c.Speed == nil || c.Direction == nil ||
		*c.Cloud < 0 || *c.Cloud > 100 || *c.Code < 0 || *c.Code > 99 || *c.Speed < 0 || *c.Speed > 150 || *c.Direction < 0 || *c.Direction > 360 ||
		c.Time <= 0 || c.Time > now.Add(15*time.Minute).Unix() || c.Time < now.Add(-2*time.Hour).Unix() {
		return campusWeather{}, fmt.Errorf("invalid or expired weather sample")
	}
	return campusWeather{Status: "live", ObservedAt: c.Time, FetchedAt: now.Unix(), CloudCover: *c.Cloud, Code: *c.Code, WindSpeed: *c.Speed, WindDirection: *c.Direction}, nil
}
func (g *gameAPI) weatherState(w http.ResponseWriter, r *http.Request) {
	respond(w, 200, map[string]any{"campuses": g.weather.snapshot(), "source": "Open-Meteo", "license": "CC BY 4.0"})
}
