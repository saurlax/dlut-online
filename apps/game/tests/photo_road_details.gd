extends SceneTree
const Movement = preload("res://scripts/shared/movement.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var world := Node3D.new()
	root.add_child(world)
	var server_mode := "--server" in OS.get_cmdline_user_args()
	if server_mode:
		world.add_child(load("res://scenes/server/lingshui.scn").instantiate())
	else:
		world.add_child(load("res://assets/campuses/lingshui/models/terrain.tscn").instantiate())
		var model: Node3D = load("res://assets/campuses/lingshui/models/lingshui_campus.tscn").instantiate()
		for child in model.get_children():
			if child is MeshInstance3D and child.get_meta("road_surface",false) and child.get_meta("walk_collision",false):
				child.owner = null
				model.remove_child(child)
				world.add_child(child)
				child.owner = world
				preload("res://scripts/shared/campus_collision.gd")._collider(child)
		model.free()
	var details: Node3D = load("res://assets/campuses/lingshui/models/road_details.tscn").instantiate()
	if not server_mode:
		world.add_child(details)
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("lingshui")
	for name in ["StoneWalks", "BrickWalks"]:
		var faces: PackedVector3Array = details.get_node(name).mesh.get_faces()
		for i in range(0, faces.size(), 3):
			var p := (faces[i]+faces[i+1]+faces[i+2])/3.0
			assert(p.y > terrain.elevation(p.x,p.z)+0.015, "Photo paving must not be buried")
	await physics_frame
	await physics_frame
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/lingshui/mapping/road-details.json"))
	var angle := deg_to_rad(float(profile.rotation_degrees))
	var right := Vector2(cos(angle),sin(angle))
	var forward := Vector2(-sin(angle),cos(angle))
	var origin := Vector2(profile.origin_xz[0],profile.origin_xz[1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/campus.json"))
	if manifest.has("legacy_reference_transform"):
		var registration: Dictionary = manifest.legacy_reference_transform
		origin = Vector2(origin.x*float(registration.scale_x)+float(registration.offset_xz[0]),origin.y+float(registration.offset_xz[1]))
		right.x *= float(registration.scale_x)
		forward.x *= float(registration.scale_x)
	for stair in profile.stairs:
		for direction in [-1.0,1.0]:
			var body := CharacterBody3D.new()
			Movement.setup(body)
			world.add_child(body)
			var start: float = stair.start_depth-1.5 if direction > 0 else stair.start_depth+stair.length+1.5
			var p: Vector2 = origin+right*float(stair.side)+forward*start
			body.position = Vector3(p.x,35,p.y)
			for frame in 90:
				await physics_frame
				Movement.step(body,Vector2.ZERO,false,false,1.0/60.0,body.position)
			assert(body.is_on_floor(), "Stair approach must be grounded")
			for frame in 75:
				await physics_frame
				Movement.step(body,forward*direction,false,false,1.0/60.0,body.position)
			var traveled: float = (Vector2(body.position.x,body.position.z)-p).dot(forward)*direction
			assert(traveled > 6.0, "Stair must be traversable in both directions without jumping")
			assert(body.is_on_floor(), "Stair exit must be grounded")
			print("PHOTO STAIR PASS: ",stair.id," direction=",direction," traveled=",traveled)
			body.free()
	# Walk across each garden-to-OSM-road join in both directions.
	for side in [-18.0,0.0,18.0]:
		for direction in [-1.0,1.0]:
			var body := CharacterBody3D.new()
			Movement.setup(body)
			world.add_child(body)
			var p: Vector2 = origin+right*side+forward*(43.0 if direction > 0 else 47.0)
			body.position = Vector3(p.x,35,p.y)
			for frame in 90:
				await physics_frame
				Movement.step(body,Vector2.ZERO,false,false,1.0/60.0,body.position)
			for frame in 45:
				await physics_frame
				Movement.step(body,forward*direction,false,false,1.0/60.0,body.position)
			assert((Vector2(body.position.x,body.position.z)-p).dot(forward)*direction > 3.9)
			assert(body.is_on_floor(), "Garden exits must join the surrounding ground")
			body.free()
	if server_mode:
		details.free()
	print("PHOTO DETAILS PASS: paving clearance and both stair flights up/down")
	quit()
