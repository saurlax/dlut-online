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
	for invalid in ["/", "dlut.online", "https://dlut.online/api/v1", "https://user:pass@dlut.online", "https://dlut.online?x=1", "http://localhost:0", "http://localhost:65536"]:
		assert(Config.resolve(production, "", invalid).is_empty(), invalid)
	print("PASS: environment defaults, URL overrides, normalization and invalid configuration")
	quit()
