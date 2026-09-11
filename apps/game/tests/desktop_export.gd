extends SceneTree
func _initialize() -> void:
	assert(FileAccess.file_exists("res://desktop_config.json"))
	assert(ResourceLoader.exists("res://scripts/client/account_session.gd"))
	assert(ResourceLoader.exists("res://scripts/client/credential_store.gd"))
	assert(not ResourceLoader.exists("res://scripts/client/guest_session.gd"))
	assert(not ResourceLoader.exists("res://scripts/server/game_server.gd"))
	assert(not ResourceLoader.exists("res://scripts/campus_pack_loader.gd"))
	assert(not ResourceLoader.exists("res://scripts/campus_streamer.gd"))
	assert(not FileAccess.file_exists("res://campus_packs.json"))
	for id in ["lingshui","eda","panjin"]:
		var scene: Node = load("res://scenes/campuses/"+id+".tscn").instantiate()
		assert(scene.get_node("CampusModel").get_child_count()>0)
		scene.free()
	print("PASS: desktop package has three full local campuses, API config and no server or Web download code")
	quit()
