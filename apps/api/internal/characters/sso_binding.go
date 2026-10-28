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

var errSSOUnbound = errors.New("unbound SSO identity")

func resolveIdentity(app core.App, account *core.Record, collection *core.Collection, subject string) (*core.Record, *core.ExternalAuth, error) {
	link, err := app.FindFirstExternalAuthByExpr(dbx.HashExp{"collectionRef": collection.Id, "provider": "oidc", "providerId": subject})
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return nil, nil, err
	}
	if err == nil {
		if account != nil && (account.Collection().Id != collection.Id || account.Id != link.RecordRef()) {
			return nil, nil, apis.NewBadRequestError("该统一认证已绑定其他账号", nil)
		}
		account, err := app.FindRecordById(collection.Id, link.RecordRef())
		return account, link, err
	}
	if account == nil {
		return nil, nil, errSSOUnbound
	}
	if account.Collection().Id != collection.Id || account.Email() == "" {
		return nil, nil, apis.NewBadRequestError("请使用已注册的邮箱账号绑定统一认证", nil)
	}
	previous, err := app.FindFirstExternalAuthByExpr(dbx.HashExp{"collectionRef": collection.Id, "provider": "oidc", "recordRef": account.Id})
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return nil, nil, err
	}
	if previous != nil {
		return nil, nil, apis.NewBadRequestError("当前账号已绑定其他统一认证身份", nil)
	}
	return account, nil, nil
}

func saveIdentity(app core.App, account *core.Record, link *core.ExternalAuth, subject string, defaults CharacterDefaults) error {
	if account.Email() == "" {
		return apis.NewBadRequestError("该统一认证未绑定邮箱注册账号", nil)
	}
	account.Set("characterDefaults", defaults)
	if err := app.Save(account); err != nil {
		return err
	}
	if link == nil {
		link = core.NewExternalAuth(app)
		link.SetCollectionRef(account.Collection().Id)
		link.SetRecordRef(account.Id)
		link.SetProvider("oidc")
		link.SetProviderId(subject)
		return app.Save(link)
	}
	return nil
}

func registerAccount(e *core.ServeEvent) {
	registerOnboarding(e)
	e.Router.GET("/api/v1/account", func(r *core.RequestEvent) error {
		links, err := r.App.FindAllExternalAuthsByRecord(r.Auth)
		if err != nil {
			return err
		}
		bound := false
		subject := ""
		for _, link := range links {
			if link.Provider() == "oidc" {
				bound = true
				subject = link.ProviderId()
			}
		}
		return r.JSON(http.StatusOK, map[string]any{"email": r.Auth.Email(), "oidcBound": bound, "oidcSubject": subject})
	}).Bind(apis.RequireAuth("users"))
}
