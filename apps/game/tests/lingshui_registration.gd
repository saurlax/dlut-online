extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/campus.json"))
	var model: Node3D = load("res://assets/campuses/lingshui/models/lingshui_campus.tscn").instantiate()
	root.add_child(model)
	var checked := 0
	for feature: Dictionary in data.features:
		if feature.id not in ["77412","77413"]: continue
		assert(feature.has("osm_id") and not feature.has("reference_points"))
		var group: Node3D = model.get_node("Feature_"+feature.id+"_0")
		var roof := PackedVector2Array()
		var lower_windows := 0
		for mesh: MeshInstance3D in group.get_children():
			for vertex: Vector3 in mesh.mesh.get_faces():
				var p := mesh.transform*vertex
				if mesh.material_override.resource_name=="Lingshui roof" and absf(p.y-float(feature.height)-0.18)<0.001:
					roof.append(Vector2(p.x,p.z))
				if mesh.material_override.resource_name=="Window glass" and p.y<3:
					assert(p.z>-228,"Visible ground-floor windows moved away from the south end")
					lower_windows += 1
			if mesh.get_meta("walk_collision",false): preload("res://scripts/shared/campus_collision.gd")._collider(mesh)
		assert(lower_windows>0)
		for coordinate: Array in feature.points:
			var found := false
			for p in roof:
				if p.distance_to(Vector2(coordinate[0],coordinate[1]))<0.001: found = true
			assert(found,"Saved roof corner differs from the registered source")
		checked += 1
	assert(checked==2)
	await physics_frame
	await physics_frame
	for sample in [["77412",384.25,-235],["77413",444.86,-239]]:
		var group: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		var p := Vector3(sample[1],group.position.y+6,sample[2])
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.RIGHT*4,p-Vector3.RIGHT*4))
		assert(not hit.is_empty() and absf(hit.position.x-p.x)<0.1,"East wall collision detached from registered footprint")
	print("LINGSHUI REGISTRATION PASS: two roofs, south-end windows and east wall collisions")
	quit()
