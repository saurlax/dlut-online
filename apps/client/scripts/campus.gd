extends Node3D

@export_enum("lingshui", "eda", "panjin") var campus_id := "eda"
@export var spawn_position := Vector3(12,0.35,387)

const Catalog = preload("res://scripts/campus_catalog.gd")

var roads: Array = []
var manifest: Dictionary
var model: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var streamer: Node3D

func _ready() -> void:
	Engine.max_fps = 60
	_setup_input()
	var entry: Dictionary = Catalog.CAMPUSES[campus_id]
	manifest = JSON.parse_string(FileAccess.get_file_as_string(entry.manifest)) if entry.has("manifest") else {"features":[]}
	roads = JSON.parse_string(FileAccess.get_file_as_string(entry.roads)).roads if entry.has("roads") else []
	model = $CampusModel
	_add_collisions()
	player = preload("res://scripts/player.gd").new()
	player.spawn_position = spawn_position
	add_child(player)
	hud = preload("res://scripts/campus_hud.gd").new()
	add_child(hud)
	streamer = preload("res://scripts/campus_streamer.gd").new()
	add_child(streamer)
	streamer.configure(player, campus_id)
	hud.build(player, self)

func _setup_input() -> void:
	var keys := {"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"run":KEY_SHIFT,"jump":KEY_SPACE}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		if not InputMap.action_has_event(action,event):
			InputMap.action_add_event(action,event)

func _add_collisions() -> void:
	preload("res://scripts/shared/campus_collision.gd").build(self, model, manifest, campus_id)
