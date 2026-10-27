package main

import (
	"log"
	"os"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"

	"github.com/saurlax/dlut-online/apps/api/internal/characters"
	"github.com/saurlax/dlut-online/apps/api/internal/oidc"
	"github.com/saurlax/dlut-online/apps/api/internal/site"
)

func main() {
	app := pocketbase.New()
	app.RootCmd.AddCommand(oidc.Command(app))
	app.OnServe().BindFunc(func(event *core.ServeEvent) error {
		characters.Register(event)
		if err := site.Register(event, os.DirFS("public")); err != nil {
			return err
		}
		return event.Next()
	})
	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
