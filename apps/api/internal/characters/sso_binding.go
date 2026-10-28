package characters

import (
	"database/sql"
	"errors"
	"net/http"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		users.Fields.GetByName("email").(*core.EmailField).Required = true
		return app.Save(users)
	}, nil)
}

func boundAccount(app core.App, e *core.RecordAuthWithOAuth2RequestEvent) (*core.Record, *core.ExternalAuth, error) {
	link, err := app.FindFirstExternalAuthByExpr(dbx.HashExp{"collectionRef": e.Collection.Id, "provider": "oidc", "providerId": e.OAuth2User.Id})
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return nil, nil, err
	}
	if err == nil {
		if e.Auth != nil && (e.Auth.Collection().Id != e.Collection.Id || e.Auth.Id != link.RecordRef()) {
			return nil, nil, e.BadRequestError("该统一认证已绑定其他账号", nil)
		}
		account, err := app.FindRecordById(e.Collection.Id, link.RecordRef())
		return account, link, err
	}
	if e.Auth == nil || e.Auth.Collection().Id != e.Collection.Id || e.Auth.Email() == "" {
		return nil, nil, e.BadRequestError("统一认证尚未绑定，请先用邮箱注册或登录，再绑定统一认证", nil)
	}
	previous, err := app.FindFirstExternalAuthByExpr(dbx.HashExp{"collectionRef": e.Collection.Id, "provider": "oidc", "recordRef": e.Auth.Id})
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return nil, nil, err
	}
	if previous != nil {
		return nil, nil, e.BadRequestError("当前账号已绑定其他统一认证身份", nil)
	}
	return e.Auth, nil, nil
}

func registerAccount(e *core.ServeEvent) {
	e.Router.GET("/api/v1/account", func(r *core.RequestEvent) error {
		links, err := r.App.FindAllExternalAuthsByRecord(r.Auth)
		if err != nil {
			return err
		}
		bound := false
		for _, link := range links {
			if link.Provider() == "oidc" {
				bound = true
			}
		}
		return r.JSON(http.StatusOK, map[string]any{"email": r.Auth.Email(), "oidcBound": bound})
	}).Bind(apis.RequireAuth("users"))
}
