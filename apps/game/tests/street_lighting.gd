extends SceneTree
const Session = preload("res://scripts/client/local_session.gd")
class Campus extends Node3D:
	var campus_id := "eda"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(15).timeout.connect(func(): quit(2))
	Session.enabled = true
	Session.minutes = 720
	Session.revision += 1
	var campus := Campus.new()
	root.add_child(campus)
	var lamps: Node3D = load("res://assets/campuses/eda/models/exterior_details.tscn").instantiate()
	campus.add_child(lamps)
	var environment: Node3D = load("res://scenes/campus_environment.tscn").instantiate()
	campus.add_child(environment)
	assert(lamps.lights.size() == 12)
	for light: SpotLight3D in lamps.lights:
		assert(not light.visible and light.light_energy == 0.0, "Daytime lamp must be off")
		assert((-light.basis.z).dot(Vector3.DOWN) > 0.95, "Light must face road surface")
	assert(not lamps.lens_material.emission_enabled)
	Session.minutes = 1380
	Session.revision += 1
	paused = true
	await create_timer(0.4, true).timeout
	for light: SpotLight3D in lamps.lights:
		assert(light.visible and light.light_energy > 3.9, "Map time change must light lamps even while paused")
	assert(lamps.lens_material.emission_enabled)
	# Another scene instance must not share the mutable emissive material.
	var separate: Node3D = load("res://assets/campuses/eda/models/exterior_details.tscn").instantiate()
	root.add_child(separate)
	assert(separate.lens_material != lamps.lens_material)
	assert(not separate.lens_material.emission_enabled)
	Session.minutes = 720
	Session.revision += 1
	await create_timer(0.4, true).timeout
	for light: SpotLight3D in lamps.lights:
		assert(not light.visible and light.light_energy == 0.0, "Returning to day must turn lights off")
	assert(not lamps.lens_material.emission_enabled)
	paused = false
	separate.free()
	campus.free()
	assert(get_nodes_in_group("campus_night_lighting").is_empty(), "Unloaded campus must leave no lights registered")
	print("STREET LIGHTING PASS: day/night/day, paused time changes, light direction, material isolation and scene cleanup")
	quit()
