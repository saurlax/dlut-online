extends Node3D

@export_enum("lingshui", "eda", "panjin") var campus_id := "eda"
@export var spawn_position := Vector3(12,0.35,387)

const Catalog = preload("res://scripts/campus_catalog.gd")

var roads: Array = []
var manifest: Dictionary
var model: Node3D
var player: CharacterBody3D
var hud: CanvasLayer

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
	hud.build(player, self)

func _setup_input() -> void:
	var keys := {"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"run":KEY_SHIFT}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		if not InputMap.action_has_event(action,event):
			InputMap.action_add_event(action,event)

func _collider(mesh: MeshInstance3D) -> void:
	mesh.create_trimesh_collision()
	for child in mesh.get_children():
		if child is StaticBody3D:
			for shape in child.get_children():
				if shape is CollisionShape3D and shape.shape is ConcavePolygonShape3D:
					shape.shape.backface_collision = true

func _add_collisions() -> void:
	_collider(model.get_node("CampusBase"))
	for child in model.get_children():
		if child is MeshInstance3D and child.get_meta("walk_collision",false):
			_collider(child)
	for feature in manifest.features:
		if feature.kind not in ["building","hill","gate"]:
			continue
		var group := model.get_node("Feature_"+feature.id)
		for child in group.get_children():
			if child is MeshInstance3D and (child.get_meta("walk_collision",false) or child.name in ["Building", "Roof", "HillBase", "SchematicTerrain", "GateFootprint", "Gate"]):
				_collider(child)
	var boundaries := [
		[Vector3(-635,80,55),Vector3(2,160,930)],
		[Vector3(635,80,55),Vector3(2,160,930)],
		[Vector3(0,80,-405),Vector3(1280,160,2)],
		[Vector3(0,80,515),Vector3(1280,160,2)],
	]
	if campus_id != "eda":
		boundaries = [
			[Vector3(-89,20,0),Vector3(2,40,180)],
			[Vector3(89,20,0),Vector3(2,40,180)],
			[Vector3(0,20,-89),Vector3(180,40,2)],
			[Vector3(0,20,89),Vector3(180,40,2)],
		]
	for entry in boundaries:
		var body := StaticBody3D.new()
		body.name = "CampusBoundary"
		body.position = entry[0]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = entry[1]
		shape.shape = box
		body.add_child(shape)
		add_child(body)
