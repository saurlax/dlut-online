extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	for f in manifest.features:
		if f.id=="77914": assert(is_equal_approx(float(f.height),17.6))
		if f.id=="77917": assert(is_equal_approx(float(f.height),22.0))
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
		for sample in [[Vector2(50,280),17.82],[Vector2(130,165),22.22]]:
			var pos: Vector2 = sample[0]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,35,pos.y),Vector3(pos.x,0,pos.y)))
			assert(not hit.is_empty())
			assert(absf(hit.position.y-float(sample[1]))<0.02,"Body roof must match declared scale")
		# Information roof beams remain open between spans, with solid supports.
		for sample in [[Vector2(70.5,266.75),20.02],[Vector2(31,267),17.82]]:
			var pos: Vector2 = sample[0]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,25,pos.y),Vector3(pos.x,17,pos.y)))
			assert(not hit.is_empty() and absf(hit.position.y-float(sample[1]))<0.02,"Roof frame beam or open bay is incorrect")
		var roof_column := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(25,18.8,261),Vector3(25,18.8,265)))
		assert(not roof_column.is_empty() and absf(roof_column.position.z-262.75)<0.02,"Missing roof frame support")
		# A north perimeter column projects beyond glazing. Test its front face,
		# and the outer ring directly above, in both visual and saved worlds.
		var a := Vector2(121.443,114.839)
		var b := Vector2(130.654,115.074)
		var out := Vector2((b-a).y,-(b-a).x).normalized()
		var mid := (a+b)/2
		var expected := mid+out*0.71
		var from := mid+out*1.5
		var to := mid+out*0.1
		var column := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(from.x,8,from.y),Vector3(to.x,8,to.y)))
		assert(not column.is_empty(),"Missing structural column")
		assert(column.position.distance_to(Vector3(expected.x,8,expected.y))<0.02)
		var ring_pos := mid+out*1.3
		var ring := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(ring_pos.x,30,ring_pos.y),Vector3(ring_pos.x,23,ring_pos.y)))
		assert(not ring.is_empty() and absf(ring.position.y-24.14)<0.02,"Missing raised ring")
		world.free()
		viewport.free()
	print("PASS: information/library declared heights, roofs, open roof frame, structural column and ring")
	quit()
