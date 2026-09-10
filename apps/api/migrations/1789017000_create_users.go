package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

func init() {
	m.Register(func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		collection.Fields.RemoveByName("name")
		collection.Fields.RemoveByName("avatar")
		collection.ListRule = nil
		collection.ViewRule = types.Pointer("@request.auth.id = id")
		collection.CreateRule = types.Pointer("@request.body.disabled:isset = false")
		collection.UpdateRule = types.Pointer("@request.auth.id = id && @request.body.disabled:changed = false")
		collection.DeleteRule = nil
		collection.AuthRule = types.Pointer("verified = true && disabled = false")

		collection.Fields.Add(
			&core.TextField{
				Name:        "username",
				Required:    true,
				Min:         1,
				Max:         64,
				Pattern:     `^[0-9A-Za-z_-]+$`,
				Presentable: true,
			},
			&core.TextField{
				Name:     "display_name",
				Required: true,
				Min:      1,
				Max:      64,
			},
			&core.BoolField{
				Name:   "disabled",
				Hidden: true,
			},
		)
		collection.AddIndex("idx_users_username_ci", true, "lower(`username`)", "")

		return app.Save(collection)
	}, func(app core.App) error { return nil })
}
