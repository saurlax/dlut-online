package characters

import (
	"errors"
	"strings"
	"unicode"
	"unicode/utf8"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(migratePlayerIdentity, nil)
}

func migratePlayerIdentity(app core.App) error {
	profiles, err := app.FindCollectionByNameOrId("profiles")
	if err != nil {
		return err
	}
	profiles.Fields.Add(&core.SelectField{Name: "gender", Values: []string{"male", "female", "unspecified"}, MaxSelect: 1})
	if err := app.Save(profiles); err != nil {
		return err
	}
	if _, err := app.DB().NewQuery("UPDATE profiles SET gender = 'unspecified'").Execute(); err != nil {
		return err
	}
	profiles.Fields.GetByName("gender").(*core.SelectField).Required = true
	if err := app.Save(profiles); err != nil {
		return err
	}
	users, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		return err
	}
	users.Fields.RemoveByName("name")
	users.Fields.RemoveByName("username")
	users.Fields.Add(&core.JSONField{Name: "characterDefaults"})
	users.PasswordAuth.IdentityFields = []string{"email"}
	users.OAuth2.MappedFields.Name = ""
	users.OAuth2.MappedFields.Username = ""
	return app.Save(users)
}

func normalizeGender(value any) string {
	gender, _ := value.(string)
	switch strings.ToLower(strings.TrimSpace(gender)) {
	case "male", "m", "男":
		return "male"
	case "female", "f", "女":
		return "female"
	default:
		return "unspecified"
	}
}

type CharacterDefaults struct {
	Name   string `json:"name"`
	Gender string `json:"gender"`
}

func validUsername(username string) bool {
	length := utf8.RuneCountInString(username)
	return length > 0 && length <= 20 && !strings.ContainsFunc(username, func(r rune) bool {
		return unicode.IsControl(r) || r == '\u2028' || r == '\u2029'
	})
}

// OIDC supplies a creation preference; it never changes an existing character.
func BindIdentity(app core.App) {
	app.OnRecordAuthWithOAuth2Request("users").BindFunc(func(e *core.RecordAuthWithOAuth2RequestEvent) error {
		if e.ProviderName != "oidc" {
			return e.Next()
		}
		preferred, _ := e.OAuth2User.RawUser["preferred_username"].(string)
		defaults := CharacterDefaults{Name: strings.TrimSpace(preferred), Gender: normalizeGender(e.OAuth2User.RawUser["gender"])}
		var account *core.Record
		err := e.App.RunInTransaction(func(tx core.App) error {
			record, link, err := resolveIdentity(tx, e.Auth, e.Collection, e.OAuth2User.Id)
			if err != nil {
				return err
			}
			if err := saveIdentity(tx, record, link, e.OAuth2User.Id, defaults); err != nil {
				return err
			}

			account = record
			return nil
		})
		if errors.Is(err, errSSOUnbound) {
			return issueOnboarding(e, defaults)
		}
		if err != nil {
			return err
		}
		// Explicit bindings preserve the local password instead of using OAuth auto-merge.
		return apis.RecordAuthResponse(e.RequestEvent, account, core.MFAMethodOAuth2, map[string]any{"isNew": false})
	})
}
