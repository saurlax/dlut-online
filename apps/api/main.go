package main

import (
	"log"
	"os"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"

	"github.com/saurlax/dlut-online/apps/api/internal/characters"
	"github.com/saurlax/dlut-online/apps/api/internal/chat"
	"github.com/saurlax/dlut-online/apps/api/internal/commands"
	"github.com/saurlax/dlut-online/apps/api/internal/guest"
	"github.com/saurlax/dlut-online/apps/api/internal/oidc"
	"github.com/saurlax/dlut-online/apps/api/internal/realtime"
	"github.com/saurlax/dlut-online/apps/api/internal/site"
	"github.com/saurlax/dlut-online/apps/api/internal/weather"
)

func main() {
	app := pocketbase.New()
	characters.BindIdentity(app)
	environment := weather.New()
	guests := guest.New()
	environment.Start()
	app.RootCmd.AddCommand(oidc.Command(app))
	app.OnServe().BindFunc(func(event *core.ServeEvent) error {
		characters.Register(event)
		guests.Register(event)
		hub := chat.Register(event, guests)
		environment.Register(event, guests)
		executeCommand := commands.Register(event, environment)
		world, err := realtime.LoadWorld(os.DirFS("public"))
		if err != nil {
			return err
		}
		realtime.Register(event, guests, hub, environment, executeCommand, world)
		if err := site.Register(event, os.DirFS("public")); err != nil {
			return err
		}
		return event.Next()
	})
	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
