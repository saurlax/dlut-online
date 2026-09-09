extends SceneTree
func _initialize() -> void:
	assert(ResourceLoader.exists("res://scenes/server.tscn"))
	assert(ResourceLoader.exists("res://scripts/server/game_server.gd"))
	assert(ResourceLoader.exists("res://scripts/server/data_service.gd"))
	assert(not ResourceLoader.exists("res://assets/fonts/CampusSans.ttf"))
	assert(not ResourceLoader.exists("res://scripts/player.gd"))
	assert(not ResourceLoader.exists("res://scripts/campus_hud.gd"))
	assert(not ResourceLoader.exists("res://assets/campuses/lingshui/models/lingshui_campus.tscn"))
	assert(FileAccess.get_file_as_string("res://scripts/player_network.gd").strip_edges() == "extends Node")
	for id in ["lingshui","eda","panjin"]:
		var world: Node = load("res://scenes/server/"+id+".scn").instantiate()
		assert(world.find_children("*","MeshInstance3D",true,false).is_empty())
		assert(world.get_child_count()>0)
		world.free()
	print("PASS: dedicated package has collision worlds and server logic, without client UI/visual assets")
	quit()
