//go:build integration

package characters

import (
	"testing"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
)

func TestInventoryCapacityAndAtomicEquipment(t *testing.T) {
	app := core.NewBaseApp(core.BaseAppConfig{DataDir: t.TempDir()})
	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { app.ResetBootstrapState() })
	if err := app.RunAllMigrations(); err != nil {
		t.Fatal(err)
	}
	users, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		t.Fatal(err)
	}
	user := core.NewRecord(users)
	user.SetEmail("inventory@example.com")
	user.SetPassword("inventory-test-password")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	collection, err := app.FindCollectionByNameOrId("inventory")
	if err != nil {
		t.Fatal(err)
	}
	add := func(key, slot string) *core.Record {
		t.Helper()
		definition, err := app.FindFirstRecordByFilter("items", "key = {:key}", dbx.Params{"key": key})
		if err != nil {
			t.Fatal(err)
		}
		item := core.NewRecord(collection)
		item.Set("userId", user.Id)
		item.Set("itemId", definition.Id)
		item.Set("slotId", slot)
		if err := app.Save(item); err != nil {
			t.Fatal(err)
		}
		return item
	}
	position := func(id, want string) {
		t.Helper()
		item, err := app.FindRecordById("inventory", id)
		if err != nil {
			t.Fatal(err)
		}
		if got := item.GetString("slotId"); got != want {
			t.Fatalf("position = %s, want %s", got, want)
		}
	}
	move := func(id, slot string) error {
		return app.RunInTransaction(func(tx core.App) error { return moveItem(tx, user.Id, id, slot) })
	}
	wear := func(id string) error {
		return app.RunInTransaction(func(tx core.App) error { return wearItem(tx, user.Id, id) })
	}
	pack := add("backpack_10", "hotbar:0")
	if err := move(pack.Id, "bag:0"); err == nil {
		t.Fatal("unequipped backpack unlocked storage")
	}
	if err := wear(pack.Id); err != nil {
		t.Fatal(err)
	}
	position(pack.Id, "backpack")
	shirt := add("shirt", "top")
	if err := wear(shirt.Id); err != nil {
		t.Fatal(err)
	}
	position(shirt.Id, "hotbar:0")
	if err := move(shirt.Id, "bag:0"); err != nil {
		t.Fatal(err)
	}
	if err := wear(pack.Id); err == nil {
		t.Fatal("removed backpack containing an item")
	}
	position(pack.Id, "backpack")
	position(shirt.Id, "bag:0")
	if err := move(shirt.Id, "hotbar:0"); err != nil {
		t.Fatal(err)
	}
	if err := wear(shirt.Id); err != nil {
		t.Fatal(err)
	}
	if err := wear(pack.Id); err != nil {
		t.Fatal(err)
	}
	position(pack.Id, "hotbar:0")
	if err := wear(pack.Id); err != nil {
		t.Fatal(err)
	}
	large := add("backpack_30", "hotbar:0")
	if err := wear(large.Id); err != nil {
		t.Fatal(err)
	}
	position(pack.Id, "hotbar:0")
	position(large.Id, "backpack")
	if err := move(pack.Id, "bag:29"); err != nil {
		t.Fatal(err)
	}
	if err := wear(pack.Id); err == nil {
		t.Fatal("smaller backpack trapped swapped large backpack in locked slot")
	}
	position(pack.Id, "bag:29")
	position(large.Id, "backpack")
	if err := move(pack.Id, "bag:0"); err != nil {
		t.Fatal(err)
	}
	if err := wear(pack.Id); err != nil {
		t.Fatal(err)
	}
	position(pack.Id, "backpack")
	position(large.Id, "bag:0")
	for _, slot := range []string{"bag:10", "bag:30", "bag:-1", "bag:01", "top", "swap:fake"} {
		if err := move(large.Id, slot); err == nil {
			t.Fatalf("accepted locked or invalid destination %s", slot)
		}
	}
	if err := app.RunInTransaction(func(tx core.App) error { return wearItem(tx, "another-user", pack.Id) }); err == nil {
		t.Fatal("accepted another player's item")
	}
	second := add("shirt", "bag:1")
	if err := wear(second.Id); err != nil {
		t.Fatal(err)
	}
	position(second.Id, "top")
	position(shirt.Id, "bag:1")
	if err := move(large.Id, "hotbar:0"); err != nil {
		t.Fatal(err)
	}
	position(large.Id, "hotbar:0")
	position(shirt.Id, "bag:1")
	if err := move(shirt.Id, "hotbar:0"); err != nil {
		t.Fatal(err)
	}
	position(shirt.Id, "hotbar:0")
	position(large.Id, "bag:1")
}
