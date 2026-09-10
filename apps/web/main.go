package main

import (
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
)

func router(config gameConfig) http.Handler {
	r := chi.NewRouter()
	newGameAPI(config).routes(r)
	return r
}

func listenAddress(port string) (string, error) {
	if port == "" {
		port = "8415"
	}
	n, err := strconv.Atoi(port)
	if err != nil || n < 1 || n > 65535 {
		return "", fmt.Errorf("invalid PORT %q: expected 1-65535", port)
	}
	return ":" + strconv.Itoa(n), nil
}

func main() {
	addr := flag.String("addr", "", "HTTP listen address (overrides PORT)")
	flag.Parse()
	if *addr == "" {
		var err error
		*addr, err = listenAddress(os.Getenv("PORT"))
		if err != nil {
			slog.Error("Invalid listener configuration", "error", err)
			os.Exit(1)
		}
	}
	config := gameConfig{endpoint: os.Getenv("DO_GAME_SERVER_URL"), serviceToken: os.Getenv("DO_GAME_SERVICE_TOKEN"), adminToken: os.Getenv("DO_ADMIN_API_TOKEN")}
	if config.endpoint == "" {
		config.endpoint = "enet://127.0.0.1:1949"
	}
	if !validGameEndpoint(config.endpoint) || (os.Getenv("DO_ENV") == "production" && !strings.HasPrefix(config.endpoint, "enets://")) {
		slog.Error("DO_GAME_SERVER_URL must be an enet:// or enets:// host:port; production requires enets://")
		os.Exit(1)
	}
	if len(config.serviceToken) < 32 || len(config.adminToken) < 32 || config.serviceToken == config.adminToken {
		slog.Error("Set distinct DO_GAME_SERVICE_TOKEN and DO_ADMIN_API_TOKEN, at least 32 characters each")
		os.Exit(1)
	}
	server := &http.Server{Addr: *addr, Handler: router(config), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, MaxHeaderBytes: 16 * 1024, IdleTimeout: 60 * time.Second}
	slog.Info("DLUT Online HTTP server", "address", *addr)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		slog.Error("HTTP server stopped", "error", err)
		os.Exit(1)
	}
}
