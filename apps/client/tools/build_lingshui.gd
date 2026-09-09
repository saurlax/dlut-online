extends "res://tools/build_model.gd"

func build() -> void:
	scene.name = "LingshuiCampus"
	root.add_child(scene)
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/campus.json"))
	var bounds: Array = manifest.bounds
	box(scene,Vector3(bounds[0]+bounds[2]/2.0,-1.0,bounds[1]+bounds[3]/2.0),Vector3(bounds[2],2.0,bounds[3]),material("Lingshui ground",Color("7c8069")),"CampusBase")
	var facade_builder := preload("res://tools/build_lingshui_facades.gd").new()
	for feature in manifest.features:
		var group := Node3D.new()
		group.name = "Feature_"+feature.id+"_"+str(int(feature.part))
		group.set_meta("source_id",feature.id)
		group.set_meta("source_part",int(feature.part))
		group.set_meta("display_name",feature.name)
		group.set_meta("height_is_approximate",true)
		scene.add_child(group)
		group.owner = scene
		for render_points in feature.render_polygons:
			var points := PackedVector2Array()
			for p in render_points:
				points.append(Vector2(p[0],p[1]))
			assert(not Geometry2D.triangulate_polygon(points).is_empty(),"Invalid official polygon "+feature.id+" part "+str(feature.part))
			match feature.kind:
				"building":
					var profile: Dictionary = feature.facade
					var color: String = profile.get("color","b0aca0")
					polygon(group,points,feature.height,material("Lingshui "+color,Color(color)),"Building")
					group.get_child(group.get_child_count()-1).set_meta("walk_collision",true)
					polygon(group,points,feature.height+0.18,material("Lingshui roof",Color("85867d")),"Roof",feature.height)
					if not profile.is_empty():
						facade_builder.build(self,group,points,profile)
				"road":
					polygon(group,points,0.04,material("Lingshui asphalt",Color("656966")),"Road")
				"water":
					polygon(group,points,0.05,material("Water",Color("526b6a")),"Water")
				"sports":
					polygon(group,points,0.06,material("Lingshui sports",Color("92776a")),"Sports")
				"plaza", "gate":
					polygon(group,points,0.06,material("Lingshui paving",Color("aaa799")),"Paving")
				"reserve":
					polygon(group,points,0.03,material("Lingshui reserve",Color("899079")),"PlannedFootprint")
				"reference":
					# Point-of-interest outlines are retained as metadata, not invented statues or bridges.
					pass
		generated_count += 1
	merge_meshes(scene)
	for mat in materials.values():
		if mat.albedo_texture is NoiseTexture2D and mat.albedo_texture.get_image() == null:
			await mat.albedo_texture.changed
	var packed := PackedScene.new()
	assert(packed.pack(scene)==OK)
	DirAccess.make_dir_recursive_absolute("res://assets/campuses/lingshui/models")
	assert(ResourceSaver.save(packed,"res://assets/campuses/lingshui/models/lingshui_campus.tscn")==OK)
	print("LINGSHUI MODEL PASS: %d official polygon parts" % generated_count)
	quit()
