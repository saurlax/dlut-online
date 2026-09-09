@tool
extends RefCounted

const CONFIG_PATH := "res://desktop_config.json"
const DEFAULT_URLS := {
	"development": "http://localhost:8060",
	"production": "https://dlut.online",
}

# Explicit environment selection resets the URL; an explicit URL wins over both.
static func resolve(defaults: Dictionary, environment: String, server_url: String) -> Dictionary:
	var selected_env: String = environment.strip_edges()
	if selected_env.is_empty():
		selected_env = defaults.environment
	if not DEFAULT_URLS.has(selected_env):
		return {}
	var selected_url := server_url.strip_edges()
	if selected_url.is_empty():
		selected_url = DEFAULT_URLS[selected_env] if not environment.strip_edges().is_empty() else defaults.server_url
	selected_url = selected_url.trim_suffix("/")
	var pattern := RegEx.new()
	pattern.compile("^https?://(?:[A-Za-z0-9.-]+|\\[[0-9A-Fa-f:]+\\])(?::([0-9]+))?$")
	var matched := pattern.search(selected_url)
	if matched == null:
		return {}
	var port := matched.get_string(1)
	if not port.is_empty() and (port.to_int() < 1 or port.to_int() > 65535):
		return {}
	return {"environment": selected_env, "server_url": selected_url}

static func read() -> Dictionary:
	if OS.has_feature("web"):
		return {}
	var defaults := {"environment": "development", "server_url": DEFAULT_URLS.development}
	if not OS.has_feature("editor"):
		if not FileAccess.file_exists(CONFIG_PATH):
			push_error("Desktop configuration is missing; enable the desktop export plugin.")
			return {}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if not parsed is Dictionary or not parsed.get("environment") is String or not parsed.get("server_url") is String:
			push_error("Invalid packaged desktop configuration.")
			return {}
		defaults = parsed
	var result := resolve(defaults, OS.get_environment("DO_ENV"), OS.get_environment("DO_SERVER_URL"))
	if result.is_empty():
		push_error("Invalid DO_ENV or DO_SERVER_URL: expected development/production and an HTTP(S) server root.")
	return result
