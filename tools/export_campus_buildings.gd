extends SceneTree

# Offline bridge from archived Godot meshes to the shared Blender color baker.
func _initialize():
	var args = OS.get_cmdline_user_args()
	var directory = args[0]
	var source = load(directory.path_join("source.tscn")).instantiate()
	var records = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var jobs = []
	for feature in records.features:
		var facility = feature.kind == "sports" and feature.geometry_status == "photo-layout-registered-to-osm; dimensions approximate"
		if feature.kind != "building" and not facility:
			continue
		var node = source.get_node("Feature_%s_%d" % [feature.id, int(feature.part)])
		var key = "%s-%d" % [feature.id, int(feature.part)]
		var target = directory.path_join(key)
		DirAccess.make_dir_recursive_absolute(target)
		var center = Vector2.ZERO
		for point in feature.points:
			center += Vector2(point[0], point[1])
		center /= feature.points.size()
		var group = Node3D.new()
		group.name = "BuildingSource"
		var copy = node.duplicate()
		group.add_child(copy)
		copy.position = Vector3(-center.x, 0, -center.y)
		var colors = {}
		var bodies = []
		var collision = []
		for mesh in copy.find_children("*", "MeshInstance3D", true, false):
			mesh.mesh = mesh.mesh.duplicate()
			for surface in range(mesh.mesh.get_surface_count()):
				var original = mesh.get_active_material(surface)
				var material = StandardMaterial3D.new()
				material.resource_name = "%s_%s" % [mesh.name, surface]
				material.albedo_color = original.albedo_color
				material.albedo_color.a = 1
				material.roughness = 1
				colors[material.resource_name] = [material.albedo_color.r, material.albedo_color.g, material.albedo_color.b, 1]
				mesh.mesh.surface_set_material(surface, material)
			mesh.material_override = null
			if mesh.get_meta("walk_collision", false) or mesh.name in ["Building", "Roof", "GabledRoof"] or (facility and (mesh.name == "FieldSurface" or mesh.mesh.get_aabb().size.y > 0.2)):
				bodies.append(str(mesh.name))
			if facility and mesh.get_meta("walk_collision", false):
				var faces = mesh.mesh.get_faces()
				for index in range(0, faces.size(), 3):
					var triangle = []
					var low = INF
					var high = -INF
					for i in range(3):
						var p = mesh.transform * faces[index+i]
						triangle.append([p.x, p.z])
						low = min(low, p.y)
						high = max(high, p.y)
					if low < 2.5 and high > 0.2:
						collision.append(triangle)
		var doc = GLTFDocument.new()
		var state = GLTFState.new()
		assert(doc.append_from_scene(group, state) == OK)
		assert(doc.write_to_filesystem(state, target.path_join("details.glb")) == OK)
		jobs.append({"id": key, "directory": target, "origin": [center.x, 0, center.y], "colors": colors, "baseSource": {"objects": bodies}, "facility":facility, "collisionPolygons":collision})
		group.free()
	var file = FileAccess.open(directory.path_join("jobs.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(jobs))
	source.free()
	quit()
