package site

import (
	"errors"
	"fmt"
	"io/fs"
	"strings"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/router"
)

// Register serves Next.js static exports without a single-page-app fallback.
func Register(event *core.ServeEvent, public fs.FS) error {
	info, err := fs.Stat(public, "index.html")
	if err != nil {
		return fmt.Errorf("static frontend missing; build apps/web and set DO_WEB_ROOT: %w", err)
	}
	if info.IsDir() {
		return fmt.Errorf("static frontend index.html must be a file")
	}
	notFound, err := fs.ReadFile(public, "404.html")
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return fmt.Errorf("read static 404 page: %w", err)
	}
	static := apis.Static(public, false)
	event.Router.GET("/{path...}", func(e *core.RequestEvent) error {
		err := static(e)
		path := e.Request.URL.Path
		reserved := path == "/api" || strings.HasPrefix(path, "/api/") || strings.HasPrefix(path, "/_")
		if errors.Is(err, router.ErrFileNotFound) && !reserved && len(notFound) > 0 {
			return e.HTML(404, string(notFound))
		}
		return err
	})
	return nil
}
