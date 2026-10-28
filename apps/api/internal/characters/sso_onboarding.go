package characters

import (
	"crypto/sha256"
	"crypto/subtle"
	"database/sql"
	"encoding/hex"
	"errors"
	"net/http"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/security"
)

const onboardingCookie = "do-sso-onboarding"
const onboardingLifetime = 10 * time.Minute

func init() {
	m.Register(func(app core.App) error {
		pending := core.NewBaseCollection("sso_onboarding")
		pending.Fields.Add(
			&core.TextField{Name: "ticketHash", Required: true},
			&core.TextField{Name: "browserHash", Required: true},
			&core.TextField{Name: "subject", Required: true},
			&core.JSONField{Name: "defaults", Required: true},
			&core.NumberField{Name: "expiresAt", OnlyInt: true, Required: true},
		)
		pending.AddIndex("idx_sso_onboarding_ticket", true, "ticketHash", "")
		pending.AddIndex("idx_sso_onboarding_expiry", false, "expiresAt", "")
		return app.Save(pending)
	}, nil)
}

func credentialHash(value string) string {
	hash := sha256.Sum256([]byte(value))
	return hex.EncodeToString(hash[:])
}

func issueOnboarding(e *core.RecordAuthWithOAuth2RequestEvent, defaults CharacterDefaults) error {
	cookie, err := e.Request.Cookie(onboardingCookie)
	if err != nil || len(cookie.Value) != 48 {
		return e.BadRequestError("请从本站重新发起统一认证", nil)
	}
	ticket := security.RandomString(48)
	err = e.App.RunInTransaction(func(tx core.App) error {
		if _, err := tx.DB().NewQuery("DELETE FROM sso_onboarding WHERE expiresAt <= {:now} OR browserHash = {:browser}").Bind(dbx.Params{"now": time.Now().Unix(), "browser": credentialHash(cookie.Value)}).Execute(); err != nil {
			return err
		}
		collection, err := tx.FindCollectionByNameOrId("sso_onboarding")
		if err != nil {
			return err
		}
		pending := core.NewRecord(collection)
		pending.Set("ticketHash", credentialHash(ticket))
		pending.Set("browserHash", credentialHash(cookie.Value))
		pending.Set("subject", e.OAuth2User.Id)
		pending.Set("defaults", defaults)
		pending.Set("expiresAt", time.Now().Add(onboardingLifetime).Unix())
		return tx.Save(pending)
	})
	if err != nil {
		return err
	}
	e.Response.Header().Set("Cache-Control", "no-store")
	return e.JSON(http.StatusConflict, map[string]any{"code": "sso_onboarding_required", "message": "请完成注册或登录已有账号", "data": map[string]string{"ticket": ticket}})
}

func pendingIdentity(app core.App, r *core.RequestEvent, ticket string) (*core.Record, error) {
	invalid := apis.NewBadRequestError("注册引导已失效，请重新进行统一认证", nil)
	if len(ticket) != 48 {
		return nil, invalid
	}
	cookie, err := r.Request.Cookie(onboardingCookie)
	if err != nil {
		return nil, invalid
	}
	pending, err := app.FindFirstRecordByFilter("sso_onboarding", "ticketHash = {:hash}", dbx.Params{"hash": credentialHash(ticket)})
	if errors.Is(err, sql.ErrNoRows) {
		return nil, invalid
	}
	if err != nil {
		return nil, err
	}
	if int64(pending.GetInt("expiresAt")) <= time.Now().Unix() || subtle.ConstantTimeCompare([]byte(pending.GetString("browserHash")), []byte(credentialHash(cookie.Value))) != 1 {
		return nil, invalid
	}
	return pending, nil
}

func registerOnboarding(e *core.ServeEvent) {
	e.Router.POST("/api/v1/sso/onboarding/start", func(r *core.RequestEvent) error {
		http.SetCookie(r.Response, &http.Cookie{Name: onboardingCookie, Value: security.RandomString(48), Path: "/api/", MaxAge: int(onboardingLifetime.Seconds()), HttpOnly: true, Secure: r.Request.TLS != nil || r.Request.Header.Get("X-Forwarded-Proto") == "https", SameSite: http.SameSiteLaxMode})
		r.Response.Header().Set("Cache-Control", "no-store")
		return r.JSON(http.StatusOK, map[string]bool{"ready": true})
	})
	e.Router.POST("/api/v1/sso/onboarding/inspect", func(r *core.RequestEvent) error {
		var body struct {
			Ticket string `json:"ticket"`
		}
		if err := r.BindBody(&body); err != nil {
			return r.BadRequestError("无效注册引导", err)
		}
		pending, err := pendingIdentity(r.App, r, body.Ticket)
		if err != nil {
			return err
		}
		var defaults CharacterDefaults
		if err := pending.UnmarshalJSONField("defaults", &defaults); err != nil {
			return err
		}
		r.Response.Header().Set("Cache-Control", "no-store")
		return r.JSON(http.StatusOK, map[string]any{"defaults": defaults, "expiresAt": pending.GetInt("expiresAt")})
	})
	e.Router.POST("/api/v1/sso/onboarding/complete", func(r *core.RequestEvent) error {
		var body struct {
			Ticket string `json:"ticket"`
		}
		if err := r.BindBody(&body); err != nil {
			return r.BadRequestError("无效注册引导", err)
		}
		err := r.App.RunInTransaction(func(tx core.App) error {
			pending, err := pendingIdentity(tx, r, body.Ticket)
			if err != nil {
				return err
			}
			account, link, err := resolveIdentity(tx, r.Auth, r.Auth.Collection(), pending.GetString("subject"))
			if err != nil {
				return err
			}
			var defaults CharacterDefaults
			if err := pending.UnmarshalJSONField("defaults", &defaults); err != nil {
				return err
			}
			if err := saveIdentity(tx, account, link, pending.GetString("subject"), defaults); err != nil {
				return err
			}
			return tx.Delete(pending)
		})
		if err != nil {
			return err
		}
		http.SetCookie(r.Response, &http.Cookie{Name: onboardingCookie, Value: "", Path: "/api/", MaxAge: -1, HttpOnly: true, Secure: r.Request.TLS != nil || r.Request.Header.Get("X-Forwarded-Proto") == "https", SameSite: http.SameSiteLaxMode})
		r.Response.Header().Set("Cache-Control", "no-store")
		return r.JSON(http.StatusOK, map[string]bool{"bound": true})
	}).Bind(apis.RequireAuth("users"))
}
