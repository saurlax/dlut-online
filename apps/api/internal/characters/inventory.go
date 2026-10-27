package characters

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		catalog, err := app.FindCollectionByNameOrId("items")
		if err != nil {
			return err
		}
		catalog.Fields.Add(&core.NumberField{Name: "capacity", OnlyInt: true, Min: number(0), Max: number(30)})
		if err := app.Save(catalog); err != nil {
			return err
		}
		packs := map[int]string{}
		for _, size := range []int{10, 20, 30} {
			item := core.NewRecord(catalog)
			item.Set("key", fmt.Sprintf("backpack_%d", size))
			item.Set("name", map[int]string{10: "校园背包", 20: "旅行背包", 30: "登山背包"}[size])
			item.Set("slotId", "backpack")
			item.Set("capacity", size)
			if err := app.Save(item); err != nil {
				return err
			}
			packs[size] = item.Id
		}
		profiles, err := app.FindAllRecords("profiles")
		if err != nil {
			return err
		}
		inventory, err := app.FindCollectionByNameOrId("inventory")
		if err != nil {
			return err
		}
		for _, profile := range profiles {
			owned, err := app.FindRecordsByFilter("inventory", "userId = {:u}", "", 0, 0, dbx.Params{"u": profile.GetString("userId")})
			if err != nil {
				return err
			}
			size := 10
			for _, item := range owned {
				if index, ok := bagIndex(item.GetString("slotId")); ok {
					if needed := (index/10 + 1) * 10; needed > size {
						size = needed
					}
				}
			}
			pack := core.NewRecord(inventory)
			pack.Set("userId", profile.GetString("userId"))
			pack.Set("itemId", packs[size])
			pack.Set("slotId", "backpack")
			if err := app.Save(pack); err != nil {
				return err
			}
		}
		return nil
	}, nil)
}

func number(v float64) *float64 { return &v }

func bagIndex(slot string) (int, bool) {
	if !strings.HasPrefix(slot, "bag:") {
		return 0, false
	}
	i, err := strconv.Atoi(strings.TrimPrefix(slot, "bag:"))
	return i, err == nil && i >= 0 && i < 30 && slot == fmt.Sprintf("bag:%d", i)
}

func quickbarSlot(slot string) bool {
	return len(slot) == len("hotbar:0") && strings.HasPrefix(slot, "hotbar:") && slot[len(slot)-1] >= '0' && slot[len(slot)-1] <= '9'
}

func inventoryCapacity(app core.App, owned []*core.Record) (int, error) {
	for _, item := range owned {
		if item.GetString("slotId") == "backpack" {
			definition, err := app.FindRecordById("items", item.GetString("itemId"))
			if err != nil {
				return 0, err
			}
			return definition.GetInt("capacity"), nil
		}
	}
	return 0, nil
}

func validateCapacity(app core.App, owned []*core.Record) error {
	capacity, err := inventoryCapacity(app, owned)
	if err != nil {
		return err
	}
	for _, item := range owned {
		if i, ok := bagIndex(item.GetString("slotId")); ok && i >= capacity {
			return apis.NewBadRequestError("请先清空将锁定的背包格子", nil)
		}
	}
	return nil
}

func transfer(app core.App, owned []*core.Record, item *core.Record, target string) error {
	old := item.GetString("slotId")
	if old == target {
		return nil
	}
	var other *core.Record
	for _, v := range owned {
		if v.GetString("slotId") == target {
			other = v
			break
		}
	}
	if other != nil {
		other.Set("slotId", old)
	}
	item.Set("slotId", target)
	if err := validateCapacity(app, owned); err != nil {
		return err
	}
	if other != nil {
		other.Set("slotId", "swap:"+other.Id)
		if err := app.Save(other); err != nil {
			return err
		}
	}
	if err := app.Save(item); err != nil {
		return err
	}
	if other != nil {
		other.Set("slotId", old)
		return app.Save(other)
	}
	return nil
}

func playerInventory(app core.App, user, id string) ([]*core.Record, *core.Record, error) {
	owned, err := app.FindRecordsByFilter("inventory", "userId = {:u}", "slotId", 0, 0, dbx.Params{"u": user})
	if err != nil {
		return nil, nil, err
	}
	for _, item := range owned {
		if item.Id == id {
			return owned, item, nil
		}
	}
	return nil, nil, apis.NewBadRequestError("物品不属于当前玩家", nil)
}

func wearItem(app core.App, user, id string) error {
	owned, item, err := playerInventory(app, user, id)
	if err != nil {
		return err
	}
	definition, err := app.FindRecordById("items", item.GetString("itemId"))
	if err != nil {
		return err
	}
	target, old := definition.GetString("slotId"), item.GetString("slotId")
	if old == target {
		used := map[string]bool{}
		for _, v := range owned {
			used[v.GetString("slotId")] = true
		}
		target = ""
		capacity, err := inventoryCapacity(app, owned)
		if err != nil {
			return err
		}
		if old == "backpack" {
			capacity = 0
		}
		for _, slot := range storageSlots(capacity) {
			if !used[slot] {
				target = slot
				break
			}
		}
		if target == "" {
			return apis.NewBadRequestError("物品栏与背包已满", nil)
		}
	}
	return transfer(app, owned, item, target)
}

func storageSlots(capacity int) []string {
	slots := []string{}
	for i := 0; i < 10; i++ {
		slots = append(slots, fmt.Sprintf("hotbar:%d", i))
	}
	for i := 0; i < capacity; i++ {
		slots = append(slots, fmt.Sprintf("bag:%d", i))
	}
	return slots
}

func moveItem(app core.App, user, id, target string) error {
	owned, item, err := playerInventory(app, user, id)
	if err != nil {
		return err
	}
	capacity, err := inventoryCapacity(app, owned)
	if err != nil {
		return err
	}
	storage := quickbarSlot(target)
	if !storage {
		i, ok := bagIndex(target)
		storage = ok
		if ok && i >= capacity {
			return apis.NewBadRequestError("该背包格尚未解锁", nil)
		}
	}
	old := item.GetString("slotId")
	if !storage {
		definition, err := app.FindRecordById("items", item.GetString("itemId"))
		if err != nil {
			return err
		}
		if target != definition.GetString("slotId") {
			return apis.NewBadRequestError("该物品不能放入这个槽位", nil)
		}
	}
	if !quickbarSlot(old) && !strings.HasPrefix(old, "bag:") {
		for _, other := range owned {
			if other.Id == item.Id || other.GetString("slotId") != target {
				continue
			}
			definition, err := app.FindRecordById("items", other.GetString("itemId"))
			if err != nil {
				return err
			}
			if definition.GetString("slotId") != old {
				return apis.NewBadRequestError("请将装备放入空格或与同类装备交换", nil)
			}
		}
	}
	return transfer(app, owned, item, target)
}
