extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/campus.json"))
	var model: Node3D = load("res://assets/campuses/lingshui/models/lingshui_campus.tscn").instantiate()
	root.add_child(model)
	var checked := 0
	for feature: Dictionary in data.features:
		if feature.id not in ["77412","77413","77416","77427","77429","77431","77439","77441","77461","77499","77504","77507","77508","77510","77511","77512","77513","77514"]: continue
		assert(feature.has("osm_id") and not feature.has("reference_points"))
		if feature.id in ["77461","77499","77504","77507","77508","77510","77511","77512","77513","77514"]:
			var outline := PackedVector2Array()
			for p in feature.points: outline.append(Vector2(p[0],p[1]))
			var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/osm_roads.json")).roads
			for road in roads:
				var line := PackedVector2Array()
				for p in road.points: line.append(Vector2(p[0],p[1]))
				var length := 0.0
				for piece in Geometry2D.intersect_polyline_with_polygon(line,outline):
					for i in range(1,piece.size()): length += piece[i-1].distance_to(piece[i])
				assert(length<0.5,"Registered residence again covers a road centerline")
		var group: Node3D = model.get_node("Feature_"+feature.id+"_0")
		var roof := PackedVector2Array()
		var lower_windows := 0
		for mesh: MeshInstance3D in group.get_children():
			for vertex: Vector3 in mesh.mesh.get_faces():
				var p := mesh.transform*vertex
				if (mesh.material_override.resource_name=="Lingshui roof" and absf(p.y-float(feature.height)-0.18)<0.001) or (feature.id in ["77499","77504"] and mesh.material_override.resource_name=="Gabled hall roof"):
					roof.append(Vector2(p.x,p.z))
				if feature.id in ["77412","77413"] and mesh.material_override.resource_name=="Window glass" and p.y<3:
					assert(p.z>-228,"Visible ground-floor windows moved away from the south end")
					lower_windows += 1
			if mesh.get_meta("walk_collision",false): preload("res://scripts/shared/campus_collision.gd")._collider(mesh)
		if feature.id in ["77412","77413"]: assert(lower_windows>0)
		for coordinate: Array in feature.points:
			var found := false
			for p in roof:
				if p.distance_to(Vector2(coordinate[0],coordinate[1]))<0.001: found = true
			assert(found,"Saved roof corner differs from the registered source")
		checked += 1
	assert(checked==18)
	await physics_frame
	await physics_frame
	for sample in [["77412",384.25,-235],["77413",444.86,-239]]:
		var group: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		var p := Vector3(sample[1],group.position.y+6,sample[2])
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.RIGHT*4,p-Vector3.RIGHT*4))
		assert(not hit.is_empty() and absf(hit.position.x-p.x)<0.1,"East wall collision detached from registered footprint")
	for sample in [["77416",420,410.23],["77427",470,230.24],["77429",618,225.23],["77431",470,99.23],["77439",838,73.1595],["77441",860,0.744]]:
		var group: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		var p := Vector3(sample[1],group.position.y+6,sample[2])
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.BACK*4,p-Vector3.BACK*4))
		assert(not hit.is_empty() and absf(hit.position.z-p.z)<0.1,"Registered north/south wall collision detached")
	for sample in [["77507",-339.109,161.548],["77508",-379.550,165.291],["77510",-379.552,93.131],["77511",-343.416,88.177],["77512",-378.814,13.064],["77513",-334.055,-10.875],["77514",-292.211,-45.333]]:
		var residence: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		for level in ([3.5,7.0,10.5,14.0] if sample[0] in ["77507","77508","77510","77511"] else [3.5,7.0,10.5,14.0,17.5]):
			var p := Vector3(sample[1],residence.position.y+level,sample[2])
			var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.4,p-Vector3.UP*0.4))
			assert(not hit.is_empty() and absf(hit.position.y-p.y)<0.02,"Registered south balcony floor detached")
	var north: Node3D = model.get_node("Feature_77461_0")
	# Three southern segments and the eastern end must follow the bent source footprint.
	for sample in [[192.755,-688.241,0,1],[166.346,-679.887,0,1],[140.115,-666.189,0,1],[204.908,-699.418,1,0]]:
		var p := Vector3(sample[0],north.position.y+6,sample[1])
		var direction := Vector3(sample[2],0,sample[3])
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+direction*3,p-direction*3))
		assert(not hit.is_empty() and hit.position.distance_to(p)<0.03,"North residence bent wall collision detached")
	# Independent source-frame samples check ridge height and both roof slopes.
	for sample in [["77499",-289.424,198.333],["77504",-305.776,75.981]]:
		var residence: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		var peak := Vector3(sample[1],residence.position.y+26.0,sample[2])
		var space := model.get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(peak+Vector3.UP,peak-Vector3.UP))
		assert(not hit.is_empty() and absf(hit.position.y-peak.y)<0.03,"Registered roof ridge height/location differs")
		for offset in [-4.0,4.0]:
			var p := peak+Vector3(offset,0,0)
			var slope := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP*4))
			assert(not slope.is_empty() and slope.position.y<peak.y-1.0 and slope.position.y>peak.y-3.0,"Gabled roof slope collision detached")
	for sample in [["77499",-277.075,231.595],["77504",-292.807,109.785]]:
		var residence: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		for level in [7.0,10.5,14.0,17.5]:
			var p := Vector3(sample[1],residence.position.y+level,sample[2])
			var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.4,p-Vector3.UP*0.4))
			assert(not hit.is_empty() and absf(hit.position.y-p.y)<0.02,"East long balcony collision detached")
	print("LINGSHUI REGISTRATION PASS: eighteen roofs, registered walls and thirty-nine residence platform floors and two gabled roofs")
	quit()
