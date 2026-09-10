package main

import (
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"

	_ "dlut-online/server/migrations"
)

func router(config gameConfig) http.Handler {
	r := chi.NewRouter()
	newGameAPI(config).routes(r)
	r.Get("/*", siteHandler().ServeHTTP)
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

func newApplication(dataDir string, config gameConfig) *pocketbase.PocketBase {
	app := pocketbase.NewWithConfig(pocketbase.Config{
		DefaultDataDir:       dataDir,
		DefaultEncryptionEnv: "PB_ENCRYPTION_KEY",
	})
	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{})
	api := newGameAPI(config, app)
	app.OnServe().BindFunc(func(event *core.ServeEvent) error {
		event.Router.Any("/{path...}", apis.WrapStdHandler(routerWithAPI(api)))
		return event.Next()
	})
	return app
}

func routerWithAPI(api *gameAPI) http.Handler {
	r := chi.NewRouter()
	api.routes(r)
	r.Get("/*", siteHandler().ServeHTTP)
	return r
}

func main() {
	addr, err := listenAddress(os.Getenv("PORT"))
	if err != nil {
		slog.Error("Invalid listener configuration", "error", err)
		os.Exit(1)
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
	dataDir := os.Getenv("DO_DATA_DIR")
	if dataDir == "" {
		dataDir = "pb_data"
	}
	app := newApplication(dataDir, config)
	if len(os.Args) == 1 {
		os.Args = append(os.Args, "serve", "--http=0.0.0.0"+addr)
	}
	if err := app.Start(); err != nil {
		slog.Error("HTTP server stopped", "error", err)
		os.Exit(1)
	}
}
