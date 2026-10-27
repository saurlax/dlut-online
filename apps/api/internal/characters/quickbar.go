package characters

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		_, err := app.DB().NewQuery("UPDATE inventory SET slotId = 'hotbar:0' WHERE slotId = 'hand'").Execute()
		return err
	}, nil)
}
