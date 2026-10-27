package oidc

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"

	"github.com/pocketbase/pocketbase/core"
	"github.com/spf13/cobra"
)

func Command(app core.App) *cobra.Command {
	var file string
	command := &cobra.Command{
		Use:   "configure-oidc",
		Short: "Configure the users OIDC provider from a private JSON file",
		Args:  cobra.NoArgs,
		RunE: func(command *cobra.Command, _ []string) error {
			data, err := os.ReadFile(file)
			if err != nil {
				return err
			}
			var provider core.OAuth2ProviderConfig
			if err := json.Unmarshal(data, &provider); err != nil {
				return err
			}
			if err := Configure(app, provider); err != nil {
				return err
			}
			fmt.Fprintln(command.OutOrStdout(), "OIDC configured for users. Restart the running service to reload its collection cache.")
			return nil
		},
	}
	command.Flags().StringVar(&file, "file", "", "Private OIDC provider JSON file")
	command.MarkFlagRequired("file")
	return command
}

func Configure(app core.App, provider core.OAuth2ProviderConfig) error {
	if provider.Name != "oidc" {
		return errors.New("provider name must be oidc")
	}
	return app.RunInTransaction(func(tx core.App) error {
		users, err := tx.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		users.OAuth2.Enabled = true
		users.Fields.GetByName("email").(*core.EmailField).Required = false
		for i, existing := range users.OAuth2.Providers {
			if existing.Name == provider.Name {
				users.OAuth2.Providers[i] = provider
				return tx.Save(users)
			}
		}
		users.OAuth2.Providers = append(users.OAuth2.Providers, provider)
		return tx.Save(users)
	})
}
