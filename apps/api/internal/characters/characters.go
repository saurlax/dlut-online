package characters

import (
	"database/sql"
	"errors"
	"net/http"
	"strings"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

type Appearance struct {
	Brows     int `json:"brows"`
	Beard     int `json:"beard"`
	Freckles  int `json:"freckles"`
	Skin      int `json:"skin"`
	Hair      int `json:"hair"`
	HairColor int `json:"hairColor"`
	Eyes      int `json:"eyes"`
	Face      int `json:"face"`
	Nose      int `json:"nose"`
	Mouth     int `json:"mouth"`
}

func (a Appearance) valid() bool {
	return a.Brows >= 0 && a.Brows < 2 && a.Beard >= 0 && a.Beard < 2 && a.Freckles >= 0 && a.Freckles < 2 && a.Skin >= 0 && a.Skin < 4 && a.Hair >= 0 && a.Hair < 4 && a.HairColor >= 0 && a.HairColor < 4 && a.Eyes >= 0 && a.Eyes < 3 && a.Face >= 0 && a.Face < 2 && a.Nose >= 0 && a.Nose < 2 && a.Mouth >= 0 && a.Mouth < 2
}
func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		users.CreateRule = types.Pointer("")
		users.ViewRule = types.Pointer("id = @request.auth.id")
		users.UpdateRule = types.Pointer("id = @request.auth.id")
		if err := app.Save(users); err != nil {
			return err
		}
		profiles := core.NewBaseCollection("profiles")
		profiles.Fields.Add(&core.RelationField{Name: "userId", Required: true, MaxSelect: 1, CollectionId: users.Id, CascadeDelete: true}, &core.TextField{Name: "name", Required: true, Max: 20}, &core.JSONField{Name: "appearance", Required: true})
		profiles.AddIndex("idx_profiles_user", true, "userId", "")
		profiles.ViewRule = types.Pointer("userId = @request.auth.id")
		profiles.ListRule = profiles.ViewRule
		if err := app.Save(profiles); err != nil {
			return err
		}
		items := core.NewBaseCollection("items")
		items.Fields.Add(&core.TextField{Name: "key", Required: true}, &core.TextField{Name: "name", Required: true}, &core.TextField{Name: "slotId", Required: true})
		items.AddIndex("idx_items_key", true, "key", "")
		items.ListRule = types.Pointer("")
		items.ViewRule = types.Pointer("")
		if err := app.Save(items); err != nil {
			return err
		}
		for _, item := range []struct{ key, name, slot string }{{"shirt", "校园衬衫", "top"}, {"trousers", "长裤", "bottom"}, {"skirt", "短裙", "bottom"}, {"sneakers", "运动鞋", "feet"}, {"cap", "棒球帽", "head"}} {
			r := core.NewRecord(items)
			r.Set("key", item.key)
			r.Set("name", item.name)
			r.Set("slotId", item.slot)
			if err := app.Save(r); err != nil {
				return err
			}
		}
		inventory := core.NewBaseCollection("inventory")
		inventory.Fields.Add(&core.RelationField{Name: "userId", Required: true, MaxSelect: 1, CollectionId: users.Id, CascadeDelete: true}, &core.RelationField{Name: "itemId", Required: true, MaxSelect: 1, CollectionId: items.Id}, &core.TextField{Name: "slotId", Required: true}, &core.NumberField{Name: "color", OnlyInt: true})
		inventory.AddIndex("idx_inventory_position", true, "userId, slotId", "")
		inventory.ListRule = types.Pointer("userId = @request.auth.id")
		inventory.ViewRule = inventory.ListRule
		return app.Save(inventory)
	}, nil)
}

func state(app core.App, user string) (map[string]any, error) {
	p, err := app.FindFirstRecordByFilter("profiles", "userId = {:u}", dbx.Params{"u": user})
	if errors.Is(err, sql.ErrNoRows) {
		account, err := app.FindRecordById("users", user)
		if err != nil {
			return nil, err
		}
		defaults := CharacterDefaults{Gender: "unspecified"}
		if err := account.UnmarshalJSONField("characterDefaults", &defaults); err != nil {
			return nil, err
		}
		return map[string]any{"profile": nil, "inventory": []any{}, "capacity": 0, "defaults": defaults}, nil
	}
	if err != nil {
		return nil, err
	}
	items, err := app.FindRecordsByFilter("inventory", "userId = {:u}", "slotId", 0, 0, dbx.Params{"u": user})
	if err != nil {
		return nil, err
	}
	capacity, err := inventoryCapacity(app, items)
	return map[string]any{"profile": p, "inventory": items, "capacity": capacity}, err
}
func Register(e *core.ServeEvent) {
	registerAccount(e)
	e.Router.GET("/api/v1/character", func(r *core.RequestEvent) error {
		s, err := state(r.App, r.Auth.Id)
		if err != nil {
			return err
		}
		return r.JSON(http.StatusOK, s)
	}).Bind(apis.RequireAuth("users"))
	e.Router.POST("/api/v1/character", func(r *core.RequestEvent) error {
		var b struct {
			Name       string     `json:"name"`
			Gender     string     `json:"gender"`
			Appearance Appearance `json:"appearance"`
			Bottom     string     `json:"bottom"`
			Hat        bool       `json:"hat"`
			Color      int        `json:"color"`
		}
		if err := r.BindBody(&b); err != nil {
			return r.BadRequestError("无效角色数据", err)
		}
		b.Name = strings.TrimSpace(b.Name)
		if !validUsername(b.Name) {
			return r.BadRequestError("用户名须为 1–20 个字符，不能包含换行或控制字符", nil)
		}
		if b.Gender != "male" && b.Gender != "female" && b.Gender != "unspecified" {
			return r.BadRequestError("无效角色性别", nil)
		}
		if !b.Appearance.valid() || b.Color < 0 || b.Color > 3 || (b.Bottom != "trousers" && b.Bottom != "skirt") {
			return r.BadRequestError("无效外观选项", nil)
		}
		err := r.App.RunInTransaction(func(tx core.App) error {
			_, err := tx.FindFirstRecordByFilter("profiles", "userId = {:u}", dbx.Params{"u": r.Auth.Id})
			if err == nil {
				return nil
			}
			if !errors.Is(err, sql.ErrNoRows) {
				return err
			}
			c, err := tx.FindCollectionByNameOrId("profiles")
			if err != nil {
				return err
			}
			p := core.NewRecord(c)
			p.Set("userId", r.Auth.Id)
			p.Set("name", b.Name)
			p.Set("gender", b.Gender)
			p.Set("appearance", b.Appearance)
			if err = tx.Save(p); err != nil {
				return err
			}
			inv, err := tx.FindCollectionByNameOrId("inventory")
			if err != nil {
				return err
			}
			keys := []string{"shirt", b.Bottom, "sneakers", "backpack_10"}
			if b.Hat {
				keys = append(keys, "cap")
			}
			for _, key := range keys {
				item, err := tx.FindFirstRecordByFilter("items", "key = {:k}", dbx.Params{"k": key})
				if err != nil {
					return err
				}
				owned := core.NewRecord(inv)
				owned.Set("userId", r.Auth.Id)
				owned.Set("itemId", item.Id)
				owned.Set("slotId", item.GetString("slotId"))
				owned.Set("color", b.Color)
				if err = tx.Save(owned); err != nil {
					return err
				}
			}
			return nil
		})
		if err != nil {
			return r.BadRequestError("无法创建角色", err)
		}
		s, err := state(r.App, r.Auth.Id)
		if err != nil {
			return err
		}
		return r.JSON(200, s)
	}).Bind(apis.RequireAuth("users"))
	e.Router.POST("/api/v1/character/wear", func(r *core.RequestEvent) error {
		var b struct {
			Id string `json:"id"`
		}
		if err := r.BindBody(&b); err != nil {
			return r.BadRequestError("无效物品", err)
		}
		err := r.App.RunInTransaction(func(tx core.App) error {
			return wearItem(tx, r.Auth.Id, b.Id)
		})
		if err != nil {
			return err
		}
		s, err := state(r.App, r.Auth.Id)
		if err != nil {
			return err
		}
		return r.JSON(200, s)
	}).Bind(apis.RequireAuth("users"))
	e.Router.POST("/api/v1/character/move", func(r *core.RequestEvent) error {
		var b struct {
			Id     string `json:"id"`
			SlotId string `json:"slotId"`
		}
		if err := r.BindBody(&b); err != nil {
			return r.BadRequestError("无效物品位置", err)
		}
		err := r.App.RunInTransaction(func(tx core.App) error { return moveItem(tx, r.Auth.Id, b.Id, b.SlotId) })
		if err != nil {
			return err
		}
		s, err := state(r.App, r.Auth.Id)
		if err != nil {
			return err
		}
		return r.JSON(http.StatusOK, s)
	}).Bind(apis.RequireAuth("users"))

}
