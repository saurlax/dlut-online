extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var reference: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	var info_base: float = reference.get_node("Feature_77914").position.y
	var library_base: float = reference.get_node("Feature_77917").position.y
	reference.free()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var info := PackedVector2Array()
	var library := PackedVector2Array()
	for f in manifest.features:
		if f.id=="77914":
			assert(is_equal_approx(float(f.height),17.6))
			for p in f.points: info.append(Vector2(p[0],p[1]))
		if f.id=="77917":
			assert(is_equal_approx(float(f.height),22.0))
			for p in f.points: library.append(Vector2(p[0],p[1]))
	assert(info.size()==12 and library.size()==39)
	# Registered long-wing north edge; source-defined fractions preserve the
	# photo frame while permitting a changed origin and rotated source wall.
	var axis := (info[5]-info[4]).normalized()
	var inward := Vector2(-axis.y,axis.x)
	assert(Geometry2D.is_point_in_polygon((info[4]+info[5])/2+inward,info))
	var first := info[4].lerp(info[5],0.04)+inward*5.0
	var last := info[4].lerp(info[5],0.975)+inward*5.0

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
		for sample in [[Vector2(50,485),info_base+17.82],[Vector2(-40,485),info_base+17.82],[Vector2(106,360),library_base+22.22],[Vector2(90,425),library_base+17.82],[Vector2(90,451),library_base+17.82]]:
			var pos: Vector2 = sample[0]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,50,pos.y),Vector3(pos.x,0,pos.y)))
			assert(not hit.is_empty())
			assert(absf(hit.position.y-float(sample[1]))<0.02,"Body roof must match declared scale")
		# Information roof beams remain open between spans, with solid supports.
		for sample in [[first.lerp(last,0.5)+inward*4.25,info_base+20.02],[first.lerp(last,0.0625)+inward*4.25,info_base+17.82]]:
			var pos: Vector2 = sample[0]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,info_base+25,pos.y),Vector3(pos.x,info_base+17,pos.y)))
			assert(not hit.is_empty() and absf(hit.position.y-float(sample[1]))<0.02,"Roof frame beam or open bay is incorrect")
		var near := first-inward*2
		var far := first+inward*2
		var roof_column := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(near.x,info_base+18.8,near.y),Vector3(far.x,info_base+18.8,far.y)))
		assert(not roof_column.is_empty(),"Missing roof frame support")
		var front := first-inward*0.25
		assert(Vector2(roof_column.position.x,roof_column.position.z).distance_to(front)<0.025)
		near += axis*0.22
		far += axis*0.22
		var round_side := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(near.x,info_base+18.8,near.y),Vector3(far.x,info_base+18.8,far.y)))
		assert(not round_side.is_empty(),"Missing off-axis round support")
		var depth: float = (Vector2(round_side.position.x,round_side.position.z)-first).dot(inward)
		assert(depth>-0.15 and depth< -0.07,"Roof support must retain its round section")
		# Both registered ground setbacks stay open above terrain; an outer
		# rectangle or the former oblique silhouette would incorrectly fill them.
		for p: Vector2 in [Vector2(-8,466),Vector2(-8,497)]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,info_base+25,p.y),Vector3(p.x,info_base+3,p.y)))
			assert(hit.is_empty(),"Information-building setback filled")
		# A north perimeter column projects beyond glazing. Test its front face,
		# and the outer ring directly above, in both visual and saved worlds.
		var a := library[20]
		var b := library[21]
		var out := Vector2((b-a).y,-(b-a).x).normalized()
		var mid := (a+b)/2
		if Geometry2D.is_point_in_polygon(mid+out,library): out = -out
		var expected := mid+out*0.71
		var from := mid+out*1.5
		var to := mid+out*0.1
		var column := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(from.x,library_base+8,from.y),Vector3(to.x,library_base+8,to.y)))
		assert(not column.is_empty(),"Missing structural column")
		assert(column.position.distance_to(Vector3(expected.x,library_base+8,expected.y))<0.02)
		var ring_pos := mid+out*1.3
		var ring := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(ring_pos.x,library_base+30,ring_pos.y),Vector3(ring_pos.x,library_base+23,ring_pos.y)))
		assert(not ring.is_empty() and absf(ring.position.y-library_base-24.14)<0.02,"Missing raised ring")
		print("INFORMATION/LIBRARY PASS: server=",server," shared frame, setbacks, roof frame, round column, library wings/ring")
		world.free()
		viewport.free()
	print("PASS: information/library declared heights, lower library wing, roofs, open roof frame, structural column and ring")
	quit()
