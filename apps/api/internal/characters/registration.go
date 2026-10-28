package characters

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"net/mail"
	"strings"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/mailer"
	"github.com/pocketbase/pocketbase/tools/security"
)

const registrationCookie = "do-registration-proof"

func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		users.CreateRule = nil
		if err := app.Save(users); err != nil {
			return err
		}
		codes := core.NewBaseCollection("registration_codes")
		codes.Fields.Add(&core.EmailField{Name: "email", Required: true}, &core.TextField{Name: "codeHash", Required: true}, &core.TextField{Name: "browserHash", Required: true}, &core.NumberField{Name: "expiresAt", Required: true, OnlyInt: true}, &core.NumberField{Name: "sentAt", Required: true, OnlyInt: true}, &core.NumberField{Name: "attempts", OnlyInt: true})
		codes.AddIndex("idx_registration_codes_email", true, "email", "")
		return app.Save(codes)
	}, nil)
}

func registrationHash(proof, email, code string) string {
	h := hmac.New(sha256.New, []byte(proof))
	h.Write([]byte(email + "|" + code))
	return hex.EncodeToString(h.Sum(nil))
}

func registrationEmail(email string) string {
	email = strings.ToLower(strings.TrimSpace(email))
	address, err := mail.ParseAddress(email)
	if err != nil || address.Address != email {
		return ""
	}
	return email
}

func sendRegistrationMail(app core.App, email, code string) error {
	settings := app.Settings()
	message := &mailer.Message{From: mail.Address{Address: settings.Meta.SenderAddress, Name: settings.Meta.SenderName}, To: []mail.Address{{Address: email}}, Subject: "DLUT Online 注册验证码", Text: "你的注册验证码是 " + code + "，10 分钟内有效。"}
	if !settings.SMTP.Enabled {
		return (&mailer.Sendmail{}).Send(message)
	}
	smtp := settings.SMTP
	return (&mailer.SMTPClient{Host: smtp.Host, Port: smtp.Port, Username: smtp.Username, Password: smtp.Password, TLS: smtp.TLS, AuthMethod: smtp.AuthMethod, LocalName: smtp.LocalName}).Send(message)
}

func registerRegistration(e *core.ServeEvent) {
	e.Router.POST("/api/v1/registration/code", func(r *core.RequestEvent) error {
		var body struct {
			Email string `json:"email"`
		}
		if err := r.BindBody(&body); err != nil {
			return r.BadRequestError("请输入有效邮箱", nil)
		}
		email := registrationEmail(body.Email)
		if email == "" {
			return r.BadRequestError("请输入有效邮箱", nil)
		}
		value, err := rand.Int(rand.Reader, big.NewInt(1000000))
		if err != nil {
			return err
		}
		code := fmt.Sprintf("%06d", value.Int64())
		proof := security.RandomString(48)
		var pending *core.Record
		rateLimited := false
		err = r.App.RunInTransaction(func(tx core.App) error {
			pending, err = tx.FindFirstRecordByFilter("registration_codes", "email = {:email}", dbx.Params{"email": email})
			if err != nil && !errors.Is(err, sql.ErrNoRows) {
				return err
			}
			if pending != nil && pending.GetInt("sentAt") > int(time.Now().Unix()-60) {
				rateLimited = true
				return nil
			}
			if pending == nil {
				collection, err := tx.FindCollectionByNameOrId("registration_codes")
				if err != nil {
					return err
				}
				pending = core.NewRecord(collection)
			}
			pending.Set("email", email)
			pending.Set("codeHash", registrationHash(proof, email, code))
			pending.Set("browserHash", credentialHash(proof))
			pending.Set("sentAt", time.Now().Unix())
			pending.Set("expiresAt", time.Now().Add(10*time.Minute).Unix())
			pending.Set("attempts", 0)
			return tx.Save(pending)
		})
		if err != nil {
			return err
		}
		if rateLimited {
			return r.TooManyRequestsError("请稍后再发送验证码", nil)
		}
		if err := sendRegistrationMail(r.App, email, code); err != nil {
			_ = r.App.Delete(pending)
			return r.InternalServerError("验证码发送失败", nil)
		}
		http.SetCookie(r.Response, &http.Cookie{Name: registrationCookie, Value: proof, Path: "/api/", MaxAge: 600, HttpOnly: true, Secure: r.Request.TLS != nil || r.Request.Header.Get("X-Forwarded-Proto") == "https", SameSite: http.SameSiteLaxMode})
		r.Response.Header().Set("Cache-Control", "no-store")
		return r.JSON(http.StatusOK, map[string]bool{"sent": true})
	})
	e.Router.POST("/api/v1/registration", func(r *core.RequestEvent) error {
		var body struct {
			Email           string `json:"email"`
			Password        string `json:"password"`
			PasswordConfirm string `json:"passwordConfirm"`
			Code            string `json:"code"`
		}
		if err := r.BindBody(&body); err != nil {
			return r.BadRequestError("注册信息无效", nil)
		}
		email := registrationEmail(body.Email)
		if email == "" || len(body.Password) < 8 || body.Password != body.PasswordConfirm {
			return r.BadRequestError("请检查邮箱及两次输入的密码", nil)
		}
		cookie, err := r.Request.Cookie(registrationCookie)
		if err != nil || len(cookie.Value) != 48 {
			return r.BadRequestError("验证码错误或已过期", nil)
		}
		invalid := false
		err = r.App.RunInTransaction(func(tx core.App) error {
			pending, err := tx.FindFirstRecordByFilter("registration_codes", "email = {:email}", dbx.Params{"email": email})
			if errors.Is(err, sql.ErrNoRows) {
				invalid = true
				return nil
			}
			if err != nil {
				return err
			}
			if pending.GetInt("expiresAt") <= int(time.Now().Unix()) || pending.GetInt("attempts") >= 5 || subtle.ConstantTimeCompare([]byte(pending.GetString("browserHash")), []byte(credentialHash(cookie.Value))) != 1 {
				invalid = true
				return nil
			}
			if subtle.ConstantTimeCompare([]byte(pending.GetString("codeHash")), []byte(registrationHash(cookie.Value, email, body.Code))) != 1 {
				pending.Set("attempts", pending.GetInt("attempts")+1)
				invalid = true
				return tx.Save(pending)
			}
			if _, err := tx.FindAuthRecordByEmail("users", email); err == nil {
				return r.BadRequestError("该邮箱已注册，请点击“已有账号”登录", nil)
			} else if !errors.Is(err, sql.ErrNoRows) {
				return err
			}
			users, err := tx.FindCollectionByNameOrId("users")
			if err != nil {
				return err
			}
			user := core.NewRecord(users)
			user.SetEmail(email)
			user.SetPassword(body.Password)
			user.SetVerified(true)
			if err := tx.Save(user); err != nil {
				return r.BadRequestError("注册失败，请检查邮箱和密码", err)
			}
			return tx.Delete(pending)
		})
		if err != nil {
			return err
		}
		if invalid {
			return r.BadRequestError("验证码错误或已过期", nil)
		}
		http.SetCookie(r.Response, &http.Cookie{Name: registrationCookie, Value: "", Path: "/api/", MaxAge: -1, HttpOnly: true, SameSite: http.SameSiteLaxMode})
		return r.JSON(http.StatusOK, map[string]bool{"registered": true})
	})
}
