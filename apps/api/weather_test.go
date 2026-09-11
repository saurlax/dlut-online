package main

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

type weatherTransport func(*http.Request) (*http.Response, error)

func (f weatherTransport) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }
func weatherResponse(body string) *http.Response {
	return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader(body))}
}
func TestWeatherSamples(t *testing.T) {
	now := time.Unix(1789122600, 0)
	good := fmt.Sprintf(`{"current":{"time":%d,"cloud_cover":96,"weather_code":3,"wind_speed_10m":3.16,"wind_direction_10m":235}}`, now.Unix())
	for _, body := range []string{`{}`, strings.Replace(good, `"cloud_cover":96`, `"cloud_cover":null`, 1), strings.Replace(good, `"cloud_cover":96`, `"cloud_cover":101`, 1), strings.Replace(good, fmt.Sprint(now.Unix()), fmt.Sprint(now.Add(-3*time.Hour).Unix()), 1), strings.Replace(good, `"wind_speed_10m":3.16`, `"wind_speed_10m":-1`, 1), `invalid`} {
		s := newWeatherService(weatherConfig{})
		s.now = func() time.Time { return now }
		s.client.Transport = weatherTransport(func(*http.Request) (*http.Response, error) { return weatherResponse(body), nil })
		if _, err := s.fetch("lingshui"); err == nil {
			t.Fatalf("accepted invalid weather: %s", body)
		}
	}
	s := newWeatherService(weatherConfig{apiKey: "private-test-key"})
	s.now = func() time.Time { return now }
	s.client.Transport = weatherTransport(func(r *http.Request) (*http.Response, error) {
		if r.URL.Host != "customer-api.open-meteo.com" || r.URL.Query().Get("apikey") != "private-test-key" || r.URL.Query().Get("timezone") != "Asia/Shanghai" || r.URL.Query().Get("latitude") != "40.686249" {
			t.Error("incorrect upstream configuration")
		}
		return weatherResponse(good), nil
	})
	if sample, err := s.fetch("panjin"); err != nil || sample.CloudCover != 96 || sample.ObservedAt != now.Unix() {
		t.Fatalf("valid weather rejected: %+v %v", sample, err)
	}
}
func TestWeatherCacheAndFailure(t *testing.T) {
	s := newWeatherService(weatherConfig{})
	now := time.Unix(1789122600, 0)
	s.now = func() time.Time { return now }
	// Isolate one campus and hold the upstream call to verify nonblocking single-flight reads.
	s.entries = map[string]*weatherEntry{"eda": {value: campusWeather{Status: "unavailable"}}}
	var calls atomic.Int32
	entered, release := make(chan struct{}, 1), make(chan struct{})
	s.client.Transport = weatherTransport(func(*http.Request) (*http.Response, error) {
		calls.Add(1)
		entered <- struct{}{}
		<-release
		return weatherResponse(fmt.Sprintf(`{"current":{"time":%d,"cloud_cover":75,"weather_code":3,"wind_speed_10m":2,"wind_direction_10m":90}}`, now.Unix())), nil
	})
	if s.snapshot()["eda"].Status != "unavailable" {
		t.Fatal("fabricated initial weather")
	}
	<-entered
	for i := 0; i < 20; i++ {
		s.snapshot()
	}
	if calls.Load() != 1 {
		t.Fatal("duplicate upstream calls")
	}
	close(release)
	deadline := time.Now().Add(time.Second)
	for {
		s.mu.Lock()
		busy := s.entries["eda"].busy
		s.mu.Unlock()
		if !busy {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("refresh did not finish")
		}
		time.Sleep(time.Millisecond)
	}
	if s.snapshot()["eda"].CloudCover != 75 || calls.Load() != 1 {
		t.Fatal("cache miss")
	}
	now = now.Add(65 * time.Minute)
	s.client.Transport = weatherTransport(func(*http.Request) (*http.Response, error) {
		return &http.Response{StatusCode: 429, Body: io.NopCloser(strings.NewReader("rate limit"))}, nil
	})
	s.refresh("eda")
	if value := s.snapshot()["eda"]; value.Status != "stale" || value.CloudCover != 75 {
		t.Fatalf("lost last good sample: %+v", value)
	}
	if !s.entries["eda"].next.Equal(now.Add(time.Minute)) {
		t.Fatal("incorrect failure backoff")
	}
}
func TestWeatherAuthAndConfig(t *testing.T) {
	g := newGameAPI(gameConfig{apiKey: "secret"})
	for _, entry := range g.weather.entries {
		entry.next = time.Now().Add(time.Hour)
	}
	for _, auth := range []string{"", "Bearer secret"} {
		r := httptest.NewRequest(http.MethodPost, "/api/v1/game/weather", strings.NewReader(`{}`))
		r.Header.Set("Authorization", auth)
		w := httptest.NewRecorder()
		apiHandler(g, false).ServeHTTP(w, r)
		want := 401
		if auth != "" {
			want = 200
		}
		if w.Code != want {
			t.Fatal(w.Code)
		}
	}
	for _, raw := range []string{"", "5", "15", "180", "0", "4", "181", "bad"} {
		t.Setenv("DO_WEATHER_REFRESH_MINUTES", raw)
		c, err := readWeatherConfig()
		valid := raw == "" || raw == "5" || raw == "15" || raw == "180"
		if valid != (err == nil) {
			t.Fatalf("configuration %q: %v", raw, err)
		}
		if raw == "" && c.interval != 15*time.Minute {
			t.Fatal("wrong default")
		}
	}
}
