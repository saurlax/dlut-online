package main

import (
	"log"
	"os"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"

	"github.com/saurlax/dlut-online/apps/api/internal/characters"
	"github.com/saurlax/dlut-online/apps/api/internal/site"
)

func main() {
	app := pocketbase.New()
	app.OnServe().BindFunc(func(event *core.ServeEvent) error {
		characters.Register(event)
		root := os.Getenv("DO_WEB_ROOT")
		if root == "" {
			root = "./public"
		}
		if err := site.Register(event, os.DirFS(root)); err != nil {
			return err
		}
		return event.Next()
	})
	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
