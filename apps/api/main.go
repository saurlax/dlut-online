package main

import (
	"fmt"
	"log/slog"
	"os"
	"strconv"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"

	_ "dlut-online/server/migrations"
)

func listenAddress(port string) (string, error) {
	if port == "" {
		port = "8415"
	}
	n, err := strconv.Atoi(port)
	if err != nil || n < 1 || n > 65535 {
		return "", fmt.Errorf("invalid API server port %q: expected 1-65535", port)
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
		for _, route := range api.routes() {
			event.Router.Route(route.method, route.path, apis.WrapStdHandler(route.handler))
		}
		event.Router.GET("/{path...}", apis.WrapStdHandler(siteHandler()))
		return event.Next()
	})
	return app
}

func main() {
	port := os.Getenv("DO_API_SERVER_PORT")
	if port == "" {
		port = os.Getenv("PORT")
	}
	addr, err := listenAddress(port)
	if err != nil {
		slog.Error("Invalid listener configuration", "error", err)
		os.Exit(1)
	}
	config := gameConfig{environment: os.Getenv("DO_ENV"), apiKey: os.Getenv("DO_API_KEY")}
	if config.environment != "" && config.environment != "development" && config.environment != "production" {
		slog.Error("DO_ENV must be development or production")
		os.Exit(1)
	}
	if len(config.apiKey) < 32 {
		slog.Error("Set DO_API_KEY to a random value of at least 32 characters")
		os.Exit(1)
	}
	dataDir := os.Getenv("PB_DATA_DIR")
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
