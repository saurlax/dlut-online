extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	var campus: Node3D = load("res://scenes/campuses/lingshui.tscn").instantiate()
	root.add_child(campus)
	for i in 45:
		await physics_frame
	assert(campus.manifest.features.size()==313)
	assert(not campus.model.get_meta("is_placeholder",false))
	assert(campus.player.is_on_floor())
	assert(campus.hud.minimap.map_bounds.size.x>2000)
	var ids := {}
	var split_parts := 0
	for feature in campus.manifest.features:
		ids[feature.id] = true
		var group: Node3D = campus.model.get_node("Feature_"+feature.id+"_"+str(int(feature.part)))
		assert(group.get_meta("source_id")==feature.id)
		for polygon_points in feature.render_polygons:
			var polygon := PackedVector2Array()
			for p in polygon_points:
				polygon.append(Vector2(p[0],p[1]))
			assert(not Geometry2D.triangulate_polygon(polygon).is_empty())
			split_parts += 1
		if feature.kind == "building":
			assert(not group.find_children("*","StaticBody3D",true,false).is_empty(),"Every building must collide")
		elif feature.kind == "reference":
			assert(group.get_child_count()==0,"No invented statue or bridge geometry")
	assert(ids.size()==282 and split_parts==314)
	var map_script = preload("res://scripts/campus_map.gd")
	for scale in [0.5,2.0,8.0]:
		for center in [Vector2(96,28),Vector2.ZERO,Vector2(-880,-510)]:
			var clip := PackedVector2Array()
			for i in 64:
				clip.append(Vector2(cos(TAU*i/64.0),sin(TAU*i/64.0))*74.0)
			for feature in campus.manifest.features:
				for ring in feature.render_polygons:
					var poly := PackedVector2Array()
					for p in ring:
						poly.append((Vector2(p[0],p[1])-center)*scale)
					for piece in map_script.clipped_polygons(poly,clip):
						assert(piece.size()<3 or not Geometry2D.triangulate_polygon(piece).is_empty())
	# Main south wall, just beside the photo-supported portico: walk until blocked.
	var player: CharacterBody3D = campus.player
	player.set_physics_process(false)
	player.position = Vector3(115,0.05,-15)
	for i in 100:
		await physics_frame
		player.velocity = Vector3(0,-2,-13)
		player.move_and_slide()
	assert(player.position.z>-29.2 and player.position.z<-28.0,"Main south wall blocks a walking capsule")
	assert(player.position.y>-0.1)
	# Structural portico column must stop a capsule; trim/windows have no colliders.
	var main: Node3D = campus.model.get_node("Feature_77386_0")
	var ray := PhysicsRayQueryParameters3D.create(Vector3(99,4,-12),Vector3(99,4,-30))
	assert(not campus.get_world_3d().direct_space_state.intersect_ray(ray).is_empty())
	for feature in campus.manifest.features:
		if feature.kind != "building":
			continue
		var group: Node3D = campus.model.get_node("Feature_"+feature.id+"_"+str(int(feature.part)))
		for child in group.get_children():
			if child is MeshInstance3D and not child.get_meta("walk_collision",false) and child.name != "Roof":
				assert(child.find_children("*","StaticBody3D",true,false).is_empty())
	var b: Array = campus.manifest.bounds
	player.position = Vector3(b[0]+4,0.05,300)
	for i in 45:
		await physics_frame
		player.velocity = Vector3(-13,-2,0)
		player.move_and_slide()
	assert(player.position.x>b[0]+1 and player.position.x<b[0]+2)
	print("PASS: 313 source parts / 282 IDs / 314 valid rings; grounded arrival; main wall and perimeter block capsule; structural-only collisions; real map bounds")
	quit()
