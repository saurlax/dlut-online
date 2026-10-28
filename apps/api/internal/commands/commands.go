package commands

import (
	"fmt"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/saurlax/dlut-online/apps/api/internal/weather"
	"net/http"
	"strconv"
	"strings"
)

type command struct {
	resource, usage string
	run             func([]string) (string, error)
}

func Register(e *core.ServeEvent, environment *weather.Service) {
	commands := map[string]command{
		"time": {resource: "command.time", usage: "/time set day|night|noon|HH:MM", run: func(args []string) (string, error) {
			if len(args) != 2 || args[0] != "set" {
				return "", fmt.Errorf("用法：/time set day|night|noon|HH:MM")
			}
			hour, minute := 0, 0
			switch args[1] {
			case "day":
				hour = 8
			case "night":
				hour = 22
			case "noon":
				hour = 12
			default:
				parts := strings.Split(args[1], ":")
				if len(parts) != 2 || len(parts[0]) != 2 || len(parts[1]) != 2 {
					return "", fmt.Errorf("时间格式须为 HH:MM")
				}
				var err error
				hour, err = strconv.Atoi(parts[0])
				if err != nil {
					return "", fmt.Errorf("时间格式须为 HH:MM")
				}
				minute, err = strconv.Atoi(parts[1])
				if err != nil || hour > 23 || minute > 59 || hour < 0 || minute < 0 {
					return "", fmt.Errorf("时间格式须为 HH:MM")
				}
			}
			environment.SetTime(hour, minute)
			return fmt.Sprintf("时间已设置为 %02d:%02d", hour, minute), nil
		}},
		"weather": {resource: "command.weather", usage: "/weather set clear|rain|snow|fog", run: func(args []string) (string, error) {
			if len(args) != 2 || args[0] != "set" {
				return "", fmt.Errorf("用法：/weather set clear|rain|snow|fog")
			}
			codes := map[string]int{"clear": 0, "rain": 63, "snow": 73, "fog": 45}
			code, ok := codes[args[1]]
			if !ok {
				return "", fmt.Errorf("天气须为 clear、rain、snow 或 fog")
			}
			environment.SetWeather(code)
			return "天气已设置为 " + args[1], nil
		}},
	}
	e.Router.POST("/api/v1/commands", func(r *core.RequestEvent) error {
		var body struct {
			Command string `json:"command"`
		}
		if err := r.BindBody(&body); err != nil {
			return r.BadRequestError("指令无效", nil)
		}
		fields := strings.Fields(body.Command)
		if len(fields) == 0 || !strings.HasPrefix(fields[0], "/") {
			return r.BadRequestError("指令须以 / 开头", nil)
		}
		name := strings.TrimPrefix(fields[0], "/")
		if name == "help" {
			var lines []string
			for _, key := range []string{"time", "weather"} {
				c := commands[key]
				allowed, err := permitted(r.App, r.Auth.Id, c.resource)
				if err != nil {
					return err
				}
				if allowed {
					lines = append(lines, c.usage)
				}
			}
			if len(lines) == 0 {
				lines = append(lines, "没有可用指令")
			}
			return r.JSON(http.StatusOK, map[string]any{"message": strings.Join(lines, "\n")})
		}
		c, ok := commands[name]
		if !ok {
			return r.BadRequestError("未知指令，输入 /help 查看", nil)
		}
		allowed, err := permitted(r.App, r.Auth.Id, c.resource)
		if err != nil {
			return err
		}
		if !allowed {
			return r.ForbiddenError("没有权限使用此指令", nil)
		}
		message, err := c.run(fields[1:])
		if err != nil {
			return r.BadRequestError(err.Error(), nil)
		}
		return r.JSON(http.StatusOK, map[string]any{"message": message})
	}).Bind(apis.RequireAuth("users"))
}
