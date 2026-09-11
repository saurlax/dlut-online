extends SceneTree

const Config = preload("res://scripts/client/desktop_config.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var actual := Config.read()
		if actual.get("environment") != args[0] or actual.get("server_url") != args[1]:
			printerr("Unexpected desktop configuration: ", actual)
			quit(1)
			return
		print("PASS: desktop configuration ", actual)
		quit()
		return
	var production := {"environment": "production", "server_url": "https://dlut.online"}
	assert(Config.resolve(production, "", "") == production)
	assert(Config.resolve(production, "development", "").server_url == "http://localhost:8415")
	assert(Config.resolve(production, "development", "http://localhost:9000/").server_url == "http://localhost:9000")
	var custom := {"environment": "production", "server_url": "https://test.example.com"}
	assert(Config.resolve(custom, "", "") == custom)
	assert(Config.resolve(custom, "development", "").server_url == "http://localhost:8415")
	assert(Config.resolve(custom, "", "https://override.example.com").server_url == "https://override.example.com")
	assert(Config.resolve(production, "invalid", "").is_empty())
	for invalid in ["http://dlut.online", "/", "dlut.online", "https://dlut.online/api/v1", "https://user:pass@dlut.online", "https://dlut.online?x=1", "http://localhost:0", "http://localhost:65536"]:
		assert(Config.resolve(production, "", invalid).is_empty(), invalid)
	if OS.has_feature("editor"):
		check_editor_profiles()
	print("PASS: environment defaults, editor profiles, process isolation, overrides and invalid configuration")
	quit()

func check_editor_profiles() -> void:
	var existed := FileAccess.file_exists(Config.EDITOR_PROFILE_PATH)
	var saved := FileAccess.get_file_as_bytes(Config.EDITOR_PROFILE_PATH) if existed else PackedByteArray()
	var environment := OS.get_environment("DO_ENV")
	var server_url := OS.get_environment("DO_API_SERVER_URL")
	OS.set_environment("DO_ENV", "")
	OS.set_environment("DO_API_SERVER_URL", "")
	var config := ConfigFile.new()
	config.set_value("run", "profile", "local")
	assert(config.save(Config.EDITOR_PROFILE_PATH) == OK)
	assert(Config.read().server_url == "http://localhost:8415")
	config.set_value("run", "profile", "dev")
	assert(config.save(Config.EDITOR_PROFILE_PATH) == OK)
	assert(Config.editor_defaults().server_url == "https://dlut.online")
	assert(Config.read().server_url == "http://localhost:8415", "Existing process must keep its API")
	Config.editor_run_defaults = null # Simulate the next process.
	assert(Config.read() == {"environment": "development", "server_url": "https://dlut.online"})
	OS.set_environment("DO_ENV", "development")
	assert(Config.read().server_url == "http://localhost:8415")
	OS.set_environment("DO_API_SERVER_URL", "http://localhost:9000")
	assert(Config.read().server_url == "http://localhost:9000")
	config.set_value("run", "profile", "invalid")
	assert(config.save(Config.EDITOR_PROFILE_PATH) == OK)
	assert(Config.editor_defaults().is_empty())
	if existed:
		var file := FileAccess.open(Config.EDITOR_PROFILE_PATH, FileAccess.WRITE)
		file.store_buffer(saved)
		file.close()
	else:
		DirAccess.remove_absolute(Config.EDITOR_PROFILE_PATH)
	Config.editor_run_defaults = null
	OS.set_environment("DO_ENV", environment)
	OS.set_environment("DO_API_SERVER_URL", server_url)
