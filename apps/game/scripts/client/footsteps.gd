extends Node
## Local first-person foley. No networking or changes to world collision.

const SOUNDS := {
	"concrete": [preload("res://assets/audio/footsteps/footstep_concrete_000.ogg"), preload("res://assets/audio/footsteps/footstep_concrete_001.ogg"), preload("res://assets/audio/footsteps/footstep_concrete_002.ogg"), preload("res://assets/audio/footsteps/footstep_concrete_003.ogg"), preload("res://assets/audio/footsteps/footstep_concrete_004.ogg")],
	"grass": [preload("res://assets/audio/footsteps/footstep_grass_000.ogg"), preload("res://assets/audio/footsteps/footstep_grass_001.ogg"), preload("res://assets/audio/footsteps/footstep_grass_002.ogg"), preload("res://assets/audio/footsteps/footstep_grass_003.ogg"), preload("res://assets/audio/footsteps/footstep_grass_004.ogg")],
	"wood": [preload("res://assets/audio/footsteps/footstep_wood_000.ogg"), preload("res://assets/audio/footsteps/footstep_wood_001.ogg"), preload("res://assets/audio/footsteps/footstep_wood_002.ogg"), preload("res://assets/audio/footsteps/footstep_wood_003.ogg"), preload("res://assets/audio/footsteps/footstep_wood_004.ogg")],
}

var audio := AudioStreamPlayer.new()
var progress := 0.75
var last_take: Dictionary = {}
var random := RandomNumberGenerator.new()

func _ready() -> void:
	name = "Footsteps"
	random.randomize()
	add_child(audio)

func stop() -> void:
	progress = 0.75
	audio.stop()

func update(body: CharacterBody3D, displacement: Vector3, delta: float, active: bool, running: bool) -> void:
	var distance := Vector2(displacement.x, displacement.z).length()
	# Ignore respawns/teleports and wall pushing, not merely held movement keys.
	if not active or not body.is_on_floor() or distance < 0.001 or displacement.length() > 16.0 * delta + 0.1:
		stop()
		return
	progress += distance / (4.0 if running else 2.6)
	if progress < 1.0:
		return
	progress = fmod(progress, 1.0)
	var surface := ground_surface(body)
	var sounds: Array = SOUNDS[surface]
	var previous: int = last_take.get(surface, -1)
	var take := random.randi_range(0, sounds.size() - 1 if previous < 0 else sounds.size() - 2)
	if previous >= 0 and take >= previous: take += 1
	last_take[surface] = take
	audio.stream = sounds[take]
	audio.pitch_scale = random.randf_range(0.96, 1.04)
	audio.volume_db = (-12.0 if running else -16.0) + random.randf_range(-1.0, 1.0)
	audio.play()

func ground_surface(body: CharacterBody3D) -> String:
	var query := PhysicsRayQueryParameters3D.create(body.global_position + Vector3.UP * 0.25, body.global_position - Vector3.UP * 0.45, 1, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.normal.dot(Vector3.UP) >= cos(body.floor_max_angle):
		return surface_for(hit.collider)
	# A capsule can stand on an edge while its centre ray misses the floor.
	for index in body.get_slide_collision_count():
		var collision := body.get_slide_collision(index)
		if collision.get_normal().dot(Vector3.UP) >= cos(body.floor_max_angle):
			return surface_for(collision.get_collider())
	return "concrete"

static func surface_for(collider: Node) -> String:
	var node := collider
	while node != null:
		var explicit: String = str(node.get_meta("footstep_surface", ""))
		if SOUNDS.has(explicit): return explicit
		if node is MeshInstance3D:
			var material: Material = node.get_active_material(0) if node.mesh != null and node.mesh.get_surface_count() > 0 else null
			if material != null:
				var label := material.resource_name.to_lower()
				if label == "terrain" or "grass" in label or "lawn" in label: return "grass"
				if "wood" in label or "timber" in label: return "wood"
			return "concrete"
		node = node.get_parent()
	return "concrete"
