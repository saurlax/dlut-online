extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var pitch: Dictionary
	for feature in manifest.features:
		if feature.id=="39327169": pitch=feature
	var points: Array = pitch.sports_lines[0].points
	var reference: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	var base: float = reference.get_node("Feature_39327169").position.y+0.3
	reference.free()
	for server in [false,true]:
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
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for ends in [[0,3],[1,2]]:
			var a := Vector3(points[ends[0]][0],base,points[ends[0]][1])
			var b := Vector3(points[ends[1]][0],base,points[ends[1]][1])
			var middle := (a+b)*0.5
			var across := (b-a).normalized()
			var normal := Vector3(-across.z,0,across.x)
			for side in [-1.0,1.0]:
				var post: Vector3 = middle+across*3.66*side+Vector3.UP
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(post-normal,post+normal))
				assert(not hit.is_empty(),"Goal upright has no collision")
			var bar := space.intersect_ray(PhysicsRayQueryParameters3D.create(middle+Vector3.UP*3.0,middle+Vector3.UP*2.0))
			assert(not bar.is_empty() and absf(bar.position.y-base-2.485)<0.02,"Goal crossbar missing or wrong height")
			var mouth := middle+Vector3.UP
			assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(mouth-normal*3,mouth+normal*3)).is_empty(),"Decorative net blocks the goal mouth")
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.35
			capsule.height = 1.75
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform = Transform3D(Basis.IDENTITY,middle+Vector3.UP*0.975-normal*3)
			query.motion = normal*6
			var motion := space.cast_motion(query)
			assert(motion[0]>0.999,"Player capsule cannot pass through the open goal")
		print("GOALS PHYSICS PASS server=",server," four posts, two crossbars, open mouths and capsule passage")
		world.free()
		viewport.free()
	quit()
