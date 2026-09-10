package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		collection := core.NewBaseCollection("game_servers")
		collection.Fields.Add(
			&core.TextField{
				Name:        "name",
				Required:    true,
				Min:         1,
				Max:         64,
				Presentable: true,
			},
			&core.TextField{
				Name:     "endpoint",
				Required: true,
				Min:      1,
				Max:      255,
			},
			&core.BoolField{
				Name: "enabled",
			},
		)
		collection.AddIndex("idx_game_servers_name", true, "name", "")
		collection.AddIndex("idx_game_servers_one_enabled", true, "enabled", "enabled = TRUE")
		return app.Save(collection)
	}, func(app core.App) error { return nil })
}
