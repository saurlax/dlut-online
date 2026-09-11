//go:build integration

package main

import (
	"bytes"
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

func TestCampusWeatherSync(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	app, handler := accountTestApp(t)
	users, _ := app.FindCollectionByNameOrId("users")
	record := core.NewRecord(users)
	record.SetEmail("weather@example.com")
	record.SetPassword(randomID())
	record.Set("username", "weather_test")
	record.Set("display_name", "Weather test")
	record.SetVerified(true)
	if err := app.Save(record); err != nil {
		t.Fatal(err)
	}
	token, err := record.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	reserved, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	address := reserved.LocalAddr().String()
	reserved.Close()
	_, port, _ := net.SplitHostPort(address)
	servers, _ := app.FindCollectionByNameOrId("servers")
	endpoint := core.NewRecord(servers)
	endpoint.Set("name", "weather-test")
	endpoint.Set("endpoint", "enet://"+address)
	endpoint.Set("enabled", true)
	if err := app.Save(endpoint); err != nil {
		t.Fatal(err)
	}
	service := strings.Repeat("s", 32)
	g := newGameAPI(gameConfig{apiKey: service})
	for id, entry := range g.weather.entries {
		cover := 10.0
		if id == "eda" {
			cover = 95
		}
		if id == "panjin" {
			cover = 55
		}
		entry.value = campusWeather{Status: "live", ObservedAt: time.Now().Unix(), FetchedAt: time.Now().Unix(), CloudCover: cover, WindSpeed: 4, WindDirection: 90}
		entry.next = time.Now().Add(time.Hour)
	}
	api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/api/v1/game/weather" {
			g.apiKeyAuth(g.weatherState)(w, r)
			return
		}
		handler.ServeHTTP(w, r)
	}))
	defer api.Close()
	project, _ := filepath.Abs("../game")
	server := exec.CommandContext(ctx, "godot", "--headless", "--path", project, "scenes/server.tscn")
	server.Env = append(os.Environ(), "DO_ENV=development", "DO_GAME_TLS_CERT=", "DO_GAME_TLS_KEY=", "DO_GAME_SERVER_PORT="+port, "DO_API_KEY="+service, "DO_API_SERVER_URL="+api.URL)
	if err := server.Start(); err != nil {
		t.Fatal(err)
	}
	defer func() { server.Process.Kill(); server.Wait() }()
	client := exec.CommandContext(ctx, "godot", "--headless", "--path", project, "--script", "tests/weather_sync.gd")
	client.Env = append(os.Environ(), "DO_ENV=development", "DO_API_SERVER_URL="+api.URL, "DO_TEST_ACCOUNT_TOKEN="+token, "DO_TEST_ACCOUNT_ID="+record.Id)
	output, err := client.CombinedOutput()
	if err != nil || bytes.Contains(output, []byte("SCRIPT ERROR")) || !bytes.Contains(output, []byte("PASS:")) {
		t.Fatalf("weather sync: %v\n%s", err, output)
	}
	t.Log(string(output))
}
