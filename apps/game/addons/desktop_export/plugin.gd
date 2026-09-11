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
var run_toolbar: HBoxContainer
var run_label: Label
var run_profile: OptionButton
var selected_profile := 0

func _enter_tree() -> void:
	exporter = DesktopExport.new()
	add_export_plugin(exporter)
	run_toolbar = HBoxContainer.new()
	run_toolbar.name = "DOEnvironmentToolbar"
	run_label = Label.new()
	run_toolbar.add_child(run_label)
	run_profile = OptionButton.new()
	run_profile.name = "DOEnvironmentProfile"
	run_profile.add_item("Local")
	run_profile.add_item("Dev")
	selected_profile = 1 if Config.editor_defaults().get("server_url") == Config.DEFAULT_URLS.production else 0
	run_profile.select(selected_profile)
	run_profile.item_selected.connect(_select_profile)
	run_toolbar.add_child(run_profile)
	add_control_to_container(CONTAINER_TOOLBAR, run_toolbar)
	_update_tooltip()

func _select_profile(index: int) -> void:
	var config := ConfigFile.new()
	config.set_value("run", "profile", "dev" if index == 1 else "local")
	if config.save(Config.EDITOR_PROFILE_PATH) != OK:
		run_profile.select(selected_profile)
		push_error("Could not save the editor environment profile.")
		return
	selected_profile = index
	_update_tooltip()

func _update_tooltip() -> void:
	var environment := OS.get_environment("DO_ENV")
	var server_url := OS.get_environment("DO_API_SERVER_URL")
	var overridden := not environment.strip_edges().is_empty() or not server_url.strip_edges().is_empty()
	run_label.text = "Env*:" if overridden else "Env:"
	var defaults := Config.editor_defaults()
	var effective := Config.resolve(defaults, environment, server_url) if not defaults.is_empty() else {}
	run_profile.tooltip_text = "Next F5/F6: %s\nLocal: %s\nDev: %s\nSaved on this machine only; exports are unchanged." % [
		effective.get("server_url", "Invalid configuration"), Config.DEFAULT_URLS.development, Config.DEFAULT_URLS.production]
	if overridden:
		run_profile.tooltip_text += "\nEnv*: DO_ENV / DO_API_SERVER_URL overrides the selected profile."
	run_label.tooltip_text = run_profile.tooltip_text

func _build() -> bool:
	var defaults := Config.editor_defaults()
	if defaults.is_empty() or Config.resolve(defaults, OS.get_environment("DO_ENV"), OS.get_environment("DO_API_SERVER_URL")).is_empty():
		push_error("Invalid environment configuration. Select Local / Dev and check DO_ENV / DO_API_SERVER_URL.")
		return false
	return true

func _exit_tree() -> void:
	remove_control_from_container(CONTAINER_TOOLBAR, run_toolbar)
	run_toolbar.queue_free()
	remove_export_plugin(exporter)
