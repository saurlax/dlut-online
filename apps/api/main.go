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
		campuses := map[string]realtime.Campus{}
		for _, campus := range []string{"eda", "lingshui", "panjin"} {
			world, err := realtime.LoadWorld(os.DirFS("public"), campus)
			if err != nil {
				return err
			}
			localEnvironment, execute := environment, executeCommand
			if campus != "eda" {
				latitude, longitude := 38.881499, 121.520186
				if campus == "panjin" {
					latitude, longitude = 40.686319, 122.11917
				}
				localEnvironment = weather.NewAt(latitude, longitude)
				localEnvironment.Start()
				execute = commands.NewExecutor(localEnvironment)
			}
			campuses[campus] = realtime.Campus{World: world, Environment: localEnvironment, Execute: execute}
		}
		realtime.Register(event, guests, hub, campuses)
		if err := site.Register(event, os.DirFS("public")); err != nil {
			return err
		}
		return event.Next()
	})
	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
