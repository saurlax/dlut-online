extends "res://tools/build_model.gd"
## Rebuild only road meshes in saved campuses, preserving unrelated model assets.
func build() -> void:
	for campus in ["eda", "lingshui", "panjin"]:
		var filename: String = "development_campus" if campus == "eda" else campus + "_campus"
		var path: String = "res://assets/campuses/%s/models/%s.tscn" % [campus, filename]
		scene.free()
		scene = load(path).instantiate()
		root.add_child(scene)
		manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/%s/data/campus.json" % campus))
		materials.clear()
		remove_roads(scene)
		preload("res://tools/build_roads.gd").new().build(self, campus)
		if campus != "panjin":
			var terrain := preload("res://tools/build_terrain.gd").new()
			terrain.load_campus(campus)
			for child in scene.get_children():
				if child is MeshInstance3D and child.get_meta("road_surface", false):
					terrain.fit_road(child)
		for mat in materials.values():
			if mat.albedo_texture is NoiseTexture2D and mat.albedo_texture.get_image() == null:
				await mat.albedo_texture.changed
		var packed := PackedScene.new()
		assert(packed.pack(scene) == OK)
		assert(ResourceSaver.save(packed, path) == OK)
		print("ROAD REBUILD PASS: ", campus)
	quit()

func remove_roads(node: Node) -> void:
	for child in node.get_children():
		# Official squares and other source features may also be road surfaces.
		# Their dedicated generators own those meshes, not the road importer.
		if child.has_meta("source_id"):
			continue
		if child is MeshInstance3D and child.material_override != null and (child.get_meta("road_surface", false) or child.material_override.resource_name in ["Road", "Road edge", "Lingshui asphalt", "Panjin asphalt"]):
			node.remove_child(child)
			child.free()
		else:
			remove_roads(child)
