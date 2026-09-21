extends SceneTree
const Collision = preload("res://scripts/shared/campus_collision.gd")
const Terrain = preload("res://tools/build_terrain.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var terrain := Terrain.new()
	terrain.load_campus("eda")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	for server in [false, true]:
		var world := Node3D.new()
		if server:
			world.free()
			world = load("res://scenes/server/eda.scn").instantiate()
		else:
			var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(model)
			var ground: Node3D = load("res://assets/campuses/eda/models/terrain.tscn").instantiate()
			ground.name = "Terrain"
			world.add_child(ground)
			Collision.build(world, model, manifest, "eda")
		root.add_child(world)
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		var count := 0
		# The former triangular hole and split approach must hit asphalt, not grass.
		for z in range(353,496,2):
			for x in [-121.0,-119.0,-117.0]:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,80,z),Vector3(x,-20,z)))
				assert(not hit.is_empty(), "Junction collision gap")
				assert(absf(hit.position.y-terrain.elevation(x,z)-0.02)<0.002, "Junction centre is not paved at the terrain surface")
				count += 1
		var body := CharacterBody3D.new()
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.height = 1.7
		capsule.radius = 0.3
		shape.shape = capsule
		shape.position.y = 0.85
		body.add_child(shape)
		world.add_child(body)
		body.position = Vector3(-129,terrain.elevation(-129,361)+0.04,361)
		for frame in 240:
			body.velocity = Vector3(4,-1,0)
			body.move_and_slide()
			await physics_frame
		assert(body.position.x > -114, "Walking capsule blocked across the formerly separated junction")
		assert(absf(body.position.y-terrain.elevation(body.position.x,body.position.z))<0.08, "Walker fell through junction")
		print("EDA LAKESIDE PASS server=",server," infill rays=",count," continuous capsule walk")
		world.free()
	quit()
