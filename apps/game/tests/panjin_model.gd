extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	var campus: Node3D = load("res://scenes/campuses/panjin.tscn").instantiate()
	root.add_child(campus)
	for frame in 45:
		await physics_frame
	assert(campus.manifest.features.size()==64)
	assert(not campus.model.get_meta("is_placeholder",false))
	assert(campus.player.is_on_floor(),"Arrival must land outside the main teaching building")
	assert(campus.hud.minimap.map_bounds.size.y>900)
	var ids := {}
	var buildings := 0
	for feature in campus.manifest.features:
		ids[feature.id] = true
		var group: Node3D = campus.model.get_node("Feature_"+feature.id+"_"+str(int(feature.part)))
		assert(group.get_meta("source_id")==feature.id)
		for ring in feature.render_polygons:
			var polygon := PackedVector2Array()
			for point in ring:
				polygon.append(Vector2(point[0],point[1]))
			assert(not Geometry2D.triangulate_polygon(polygon).is_empty())
		if feature.kind == "building":
			buildings += 1
			assert(not group.find_children("*","StaticBody3D",true,false).is_empty())
		elif feature.kind == "reference":
			assert(group.get_child_count()==0,"Incomplete corridor reference must not become a solid wall")
		for child in group.get_children():
			if child is MeshInstance3D and not child.get_meta("walk_collision",false) and child.name != "Roof":
				assert(child.find_children("*","StaticBody3D",true,false).is_empty(),"Decoration must not collide")
	assert(ids.size()==60 and buildings==49)
	for excluded in ["80152","80155","80158","80161","80164"]:
		assert(not ids.has(excluded))
	# A walking capsule approaching the library's west wall must be stopped.
	var player: CharacterBody3D = campus.player
	player.set_physics_process(false)
	player.position = Vector3(227,0.05,-406)
	for frame in 90:
		await physics_frame
		player.velocity = Vector3(13,-2,0)
		player.move_and_slide()
	assert(player.position.x>231 and player.position.x<233,"Library shell blocks walking, fins are decorative")
	assert(player.is_on_floor())
	# The exported server must give the same wall hit and arrival as the client.
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	root.add_child(viewport)
	var server: Node3D = load("res://scenes/server/panjin.scn").instantiate()
	viewport.add_child(server)
	for frame in 3:
		await physics_frame
	assert(server.get_meta("spawn")==campus.spawn_position)
	var ray := PhysicsRayQueryParameters3D.create(Vector3(227,1,-406),Vector3(240,1,-406))
	ray.exclude = [player.get_rid()]
	var client_hit := campus.get_world_3d().direct_space_state.intersect_ray(ray)
	var server_hit := server.get_world_3d().direct_space_state.intersect_ray(ray)
	assert(not client_hit.is_empty() and not server_hit.is_empty())
	assert(client_hit.position.distance_to(server_hit.position)<0.001)
	var b: Array = campus.manifest.bounds
	player.position = Vector3(b[0]+4,0.05,0)
	for frame in 45:
		await physics_frame
		player.velocity = Vector3(-13,-2,0)
		player.move_and_slide()
	assert(player.position.x>b[0]+1 and player.position.x<b[0]+2)
	print("PASS: Panjin 64 parts / 60 IDs / 49 buildings; grounded arrival; library and boundary capsule collision; server parity; no invented corridor or decorative collisions")
	quit()
