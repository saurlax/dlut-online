extends SceneTree

const Movement = preload("res://scripts/shared/movement.gd")
const Collision = preload("res://scripts/shared/campus_collision.gd")
var failed := false

func require(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/buildings/academic_facades.json"))
	var spec: Dictionary = profiles["77928"].osm_registration.courtyard_entry
	var ring := PackedVector2Array()
	for feature: Dictionary in manifest.features:
		if feature.id == "77928":
			for point: Array in feature.points:
				ring.append(Vector2(point[0], point[1]))
	var edge := int(spec.edge)
	var center := ring[edge].lerp(ring[edge + 1], float(spec.fraction))
	var axis := (ring[edge + 1] - ring[edge]).normalized()
	var outward := Vector2(axis.y, -axis.x)
	if Geometry2D.is_point_in_polygon(center + outward, ring):
		outward = -outward
	var terrain_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/terrain.json"))
	var base: float = terrain_data.feature_base_y.Feature_77928
	for server in [false, true]:
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		root.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		if server:
			world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(model)
			Collision.build(world, model, manifest, "eda")
			world.add_child(load("res://assets/campuses/eda/models/terrain.tscn").instantiate())
			var hidden := 0
			for mesh: MeshInstance3D in model.get_node("Feature_77928").get_children():
				if mesh.material_override.resource_name == "EDA B courtyard stair collision":
					hidden += 1
					require(not mesh.visible and mesh.get_meta("walk_collision", false), "Stair collision surface must stay hidden and collidable")
			require(hidden == 1, "Keep one welded stair collision mesh")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		# Doors remain closed on both storeys; the entrance provides no interior.
		for y in [1.8, 6.0]:
			var p := Vector3(center.x, base + y, center.y)
			var out3 := Vector3(outward.x, 0, outward.y)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + out3 * 0.7, p - out3 * 0.7))
			require(not hit.is_empty(), "Entry rear wall collision missing")
		var body := CharacterBody3D.new()
		Movement.setup(body)
		world.add_child(body)
		# Traverse in both directions, including both intermediate landings and
		# the connections from the top flights onto the balcony.
		for direction in [1.0, -1.0]:
			var start: Vector2 = center + axis * (14.5 * direction) + outward * 1.85
			body.position = Vector3(start.x, base + 1.0, start.y)
			body.velocity = Vector3.ZERO
			for frame in 60:
				await physics_frame
				Movement.step(body, Vector2.ZERO, false, false, 1.0 / 60.0, body.position)
			for station in [14.17, 13.77, 10.41, 9.21, 5.85, 4.0, 0.0, -4.0, -5.85, -9.21, -10.41, -13.77, -14.17, -14.5]:
				var target: Vector2 = center + axis * (station * direction) + outward * 1.85
				var reached := false
				for frame in 480:
					await physics_frame
					var delta := target - Vector2(body.position.x, body.position.z)
					if delta.length() < 0.12:
						reached = true
						break
					Movement.step(body, delta.normalized() * 0.45, false, false, 1.0 / 60.0, body.position)
				require(reached, "B entrance route blocked at " + str(station) + ", server=" + str(server))
				if not reached:
					break
				if absf(station) <= 4.0:
					require(absf(body.position.y - base - 4.75) < 0.04, "Route bypassed upper balcony")
		print("B ENTRY ROUTE CHECK server=", server)
		viewport.queue_free()
		await process_frame
	if not failed:
		print("B ENTRY PASS: saved hidden collision, closed doors and bidirectional client/server stair routes")
	quit(1 if failed else 0)
