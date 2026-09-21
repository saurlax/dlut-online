extends SceneTree

const Footsteps = preload("res://scripts/client/footsteps.gd")
const Movement = preload("res://scripts/shared/movement.gd")
const Player = preload("res://scripts/client/player.gd")
var body: CharacterBody3D
var foley: Node

func _initialize() -> void: run.call_deferred()

func floor_mesh(label: String, size: Vector3, at: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.resource_name = label
	mesh.material_override = material
	mesh.position = at
	root.add_child(mesh)
	mesh.create_trimesh_collision()
	return mesh

func tick(axis := Vector2.ZERO, running := false, jumping := false, active := true) -> void:
	var before := body.global_position
	Movement.step(body, axis, running, jumping, 1.0 / 60.0, Vector3(0, 1, 0))
	foley.update(body, body.global_position - before, 1.0 / 60.0, active and axis != Vector2.ZERO, running)

func run() -> void:
	floor_mesh("Terrain", Vector3(200, 1, 200), Vector3(0, -0.5, 0))
	var paving := floor_mesh("Map plaza paving", Vector3(8, 0.1, 8), Vector3(12, 0.05, 0))
	floor_mesh("Stone wall", Vector3(8, 4, 1), Vector3(0, 2, -4))
	body = Player.new()
	body.spawn_position = Vector3(0, 0.1, 0)
	root.add_child(body)
	body.set_physics_process(false)
	foley = body.footsteps
	for i in 15:
		await physics_frame
		tick()
	assert(body.is_on_floor())
	assert(foley.ground_surface(body) == "grass")
	for i in 20:
		await physics_frame
		tick(Vector2(1, 0))
	assert(foley.audio.stream in Footsteps.SOUNDS.grass)
	# Raised paving must win over the underlying terrain.
	body.position = Vector3(12, 0.2, 0)
	for i in 15:
		await physics_frame
		tick()
	assert(foley.ground_surface(body) == "concrete")
	paving.set_meta("footstep_surface", "wood")
	assert(foley.ground_surface(body) == "wood")
	for i in 12:
		await physics_frame
		tick(Vector2(0, 1))
	assert(foley.audio.stream in Footsteps.SOUNDS.wood)
	body.stop()
	assert(not foley.audio.playing)
	# Network correction itself never advances the audio phase.
	var phase: float = foley.progress
	body.correct_position(Vector3(0.2, 0, 0))
	assert(foley.progress == phase and not foley.audio.playing)
	await physics_frame
	tick(Vector2(1, 0), false, true)
	assert(not body.is_on_floor() and not foley.audio.playing)
	body.position = Vector3(0, 0.1, -3)
	body.velocity = Vector3.ZERO
	for i in 60:
		await physics_frame
		tick(Vector2(0, -1))
	assert(not foley.audio.playing, "Pushing into a wall must be silent")
	assert(foley.progress == 0.75)
	var counts: Array[int] = []
	for running in [false, true]:
		body.position = Vector3(-50, 0.1, 20)
		body.velocity = Vector3.ZERO
		for i in 15:
			await physics_frame
			tick()
		var count := 0
		var previous_clip: AudioStream
		for i in 120:
			await physics_frame
			var before_phase: float = foley.progress
			tick(Vector2(1, 0), running)
			if foley.progress < before_phase:
				assert(foley.audio.stream != previous_clip, "Consecutive takes must differ")
				previous_clip = foley.audio.stream
				count += 1
		counts.append(count)
	assert(counts[1] > counts[0] and counts[0] >= 4)
	foley.update(body, Vector3(1, 0, 0), 1.0 / 60.0, false, false)
	assert(not foley.audio.playing)
	foley.update(body, Vector3(100, 0, 0), 1.0 / 60.0, true, false)
	assert(not foley.audio.playing, "Teleport displacement must be silent")
	# All selected audio must decode and remain short, non-looping one-shots.
	for surface: String in Footsteps.SOUNDS:
		for clip: AudioStreamOggVorbis in Footsteps.SOUNDS[surface]:
			assert(clip.get_length() > 0.0 and clip.get_length() < 2.0 and not clip.loop)
	print("Footsteps: floor ray, raised paving, metadata, movement, pause, correction, jump and wall checks passed")
	body.free()
	# Give the audio mixer time to retire the last stopped one-shot.
	await create_timer(0.1).timeout
	quit.call_deferred()
