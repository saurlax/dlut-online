package oidc

import (
	"errors"
	"github.com/pocketbase/pocketbase/tools/auth"
	"golang.org/x/oauth2"
)

// Remove email before PocketBase considers its built-in email matching path.
func init() {
	factory := auth.Providers[auth.NameOIDC]
	auth.Providers[auth.NameOIDC] = func() auth.Provider {
		return &subjectProvider{Provider: factory()}
	}
}

type subjectProvider struct{ auth.Provider }

func (p *subjectProvider) FetchAuthUser(token *oauth2.Token) (*auth.AuthUser, error) {
	user, err := p.Provider.FetchAuthUser(token)
	if err != nil {
		return nil, err
	}
	if user.Id == "" {
		return nil, errors.New("OIDC UserInfo is missing sub")
	}
	user.Email = ""
	delete(user.RawUser, "email")
	delete(user.RawUser, "email_verified")
	return user, nil
}
