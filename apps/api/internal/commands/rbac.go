package commands

import (
	"database/sql"
	"errors"
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		roles := core.NewBaseCollection("roles")
		roles.Fields.Add(&core.TextField{Name: "name", Required: true})
		roles.AddIndex("idx_roles_name", true, "name", "")
		if err := app.Save(roles); err != nil {
			return err
		}
		permissions := core.NewBaseCollection("permissions")
		permissions.Fields.Add(&core.TextField{Name: "resource", Required: true})
		permissions.AddIndex("idx_permissions_resource", true, "resource", "")
		if err := app.Save(permissions); err != nil {
			return err
		}
		assignments := core.NewBaseCollection("user_roles")
		assignments.Fields.Add(&core.RelationField{Name: "userId", CollectionId: users.Id, Required: true, MaxSelect: 1, CascadeDelete: true}, &core.RelationField{Name: "roleId", CollectionId: roles.Id, Required: true, MaxSelect: 1, CascadeDelete: true})
		assignments.AddIndex("idx_user_roles", true, "userId, roleId", "")
		if err := app.Save(assignments); err != nil {
			return err
		}
		grants := core.NewBaseCollection("role_permissions")
		grants.Fields.Add(&core.RelationField{Name: "roleId", CollectionId: roles.Id, Required: true, MaxSelect: 1, CascadeDelete: true}, &core.RelationField{Name: "permissionId", CollectionId: permissions.Id, Required: true, MaxSelect: 1, CascadeDelete: true})
		grants.AddIndex("idx_role_permissions", true, "roleId, permissionId", "")
		if err := app.Save(grants); err != nil {
			return err
		}
		admin := core.NewRecord(roles)
		admin.Set("name", "admin")
		if err := app.Save(admin); err != nil {
			return err
		}
		for _, resource := range []string{"command.time", "command.weather"} {
			p := core.NewRecord(permissions)
			p.Set("resource", resource)
			if err := app.Save(p); err != nil {
				return err
			}
			g := core.NewRecord(grants)
			g.Set("roleId", admin.Id)
			g.Set("permissionId", p.Id)
			if err := app.Save(g); err != nil {
				return err
			}
		}
		user, err := app.FindAuthRecordByEmail("users", "saurlax@qq.com")
		if errors.Is(err, sql.ErrNoRows) {
			return nil
		}
		if err != nil {
			return err
		}
		assignment := core.NewRecord(assignments)
		assignment.Set("userId", user.Id)
		assignment.Set("roleId", admin.Id)
		return app.Save(assignment)
	}, nil)
}

func permitted(app core.App, user, resource string) (bool, error) {
	var total int
	err := app.DB().NewQuery(`SELECT COUNT(*) FROM user_roles u JOIN role_permissions r ON r.roleId=u.roleId JOIN permissions p ON p.id=r.permissionId WHERE u.userId={:user} AND p.resource={:resource}`).Bind(dbx.Params{"user": user, "resource": resource}).Row(&total)
	return total > 0, err
}
