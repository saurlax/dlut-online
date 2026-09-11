@tool
extends EditorPlugin

const Config = preload("res://scripts/client/desktop_config.gd")

class DesktopExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "DODesktopConfig"

	func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		if features.has("dedicated_server"): return
		if not features.has("windows") and not features.has("macos") and not features.has("linux"):
			return
		var config := Config.resolve(
			{"environment": "production", "server_url": Config.DEFAULT_URLS.production},
			OS.get_environment("DO_ENV"), OS.get_environment("DO_API_SERVER_URL"))
		if config.is_empty():
			get_export_platform().add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR,
				"Desktop configuration", "Invalid DO_ENV or DO_API_SERVER_URL.")
			return
		if features.has("windows"):
			add_file("res://scripts/client/credential_store.ps1", FileAccess.get_file_as_bytes("res://scripts/client/credential_store.ps1"), false)
		add_file(Config.CONFIG_PATH, JSON.stringify(config).to_utf8_buffer(), false)

var exporter: DesktopExport

func _enter_tree() -> void:
	exporter = DesktopExport.new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
