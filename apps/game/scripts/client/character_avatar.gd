extends Node3D
## Reusable visual-only avatar. Movement and network authority remain external.

const SAMPLES := [
	preload("res://assets/characters/models/student_male.tscn"),
	preload("res://assets/characters/models/student_female.tscn"),
]
const FACE_PARAMETERS := [&"face_width", &"chin_width", &"nose_width", &"mouth_width"]

var sample_index := 0
var outfit_index := 0
var face_values: Dictionary = {}
var motion: StringName = &"idle"
var model: Node3D
var meshes: Array[MeshInstance3D] = []
var animation_player: AnimationPlayer

func _ready() -> void:
	set_sample(sample_index)

func set_sample(index: int) -> void:
	sample_index = clampi(index, 0, SAMPLES.size() - 1)
	if is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	meshes.clear()
	model = SAMPLES[sample_index].instantiate()
	add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	set_outfit(outfit_index)
	for key in FACE_PARAMETERS:
		set_face_parameter(key, float(face_values.get(key, 0.0)))
	set_motion(motion)

func set_face_parameter(parameter: StringName, value: float) -> void:
	if parameter not in FACE_PARAMETERS or not is_finite(value):
		return
	value = clampf(value, -1.0, 1.0)
	face_values[parameter] = value
	for mesh in meshes:
		for direction in ["decr", "incr"]:
			var index := mesh.find_blend_shape_by_name(String(parameter) + "_" + direction)
			if index >= 0:
				mesh.set_blend_shape_value(index, maxf(-value if direction == "decr" else value, 0.0))

func set_outfit(index: int) -> void:
	outfit_index = clampi(index, 0, 1)
	for mesh in meshes:
		if mesh.name in [&"Body0", &"Outfit0", &"Body1", &"Outfit1"]:
			mesh.visible = String(mesh.name).ends_with(str(outfit_index))

func set_motion(value: StringName) -> void:
	if value not in [&"idle", &"walk", &"run"]:
		return
	motion = value
	if not is_instance_valid(animation_player):
		return
	for clip in animation_player.get_animation_list():
		if clip == String(value) or clip.ends_with("/" + String(value)):
			animation_player.play(clip, 0.2)
			return

func reset_appearance() -> void:
	for key in FACE_PARAMETERS:
		set_face_parameter(key, 0.0)
	set_outfit(0)
	set_motion(&"idle")
