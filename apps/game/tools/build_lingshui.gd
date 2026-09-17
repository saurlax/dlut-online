extends "res://tools/build_model.gd"

func build() -> void:
	scene.name = "LingshuiCampus"
	root.add_child(scene)
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/campus.json"))
	var bounds: Array = manifest.bounds
	box(scene,Vector3(bounds[0]+bounds[2]/2.0,-1.0,bounds[1]+bounds[3]/2.0),Vector3(bounds[2],2.0,bounds[3]),material("Lingshui ground",Color("7c8069")),"CampusBase")
	var facade_builder := preload("res://tools/build_lingshui_facades.gd").new()
	var panel_builder := preload("res://tools/build_lingshui_panel_facades.gd").new()
	var sports_builder := preload("res://tools/build_lingshui_sports.gd").new()
	var halls_builder := preload("res://tools/build_lingshui_halls.gd").new()
	var gabled_builder := preload("res://tools/build_lingshui_gabled_hall.gd").new()
	for feature in manifest.features:
		var group := Node3D.new()
		group.name = "Feature_"+feature.id+"_"+str(int(feature.part))
		group.set_meta("source_id",feature.id)
		group.set_meta("source_part",int(feature.part))
		group.set_meta("display_name",feature.name)
		group.set_meta("height_is_approximate",true)
		if feature.has("geometry_assembly"):
			group.set_meta("geometry_assembly",feature.geometry_assembly)
		if feature.has("shared_geometry"):
			group.set_meta("shared_geometry",feature.shared_geometry)
		if feature.has("shared_official_ids"):
			group.set_meta("shared_official_ids",feature.shared_official_ids)
		scene.add_child(group)
		group.owner = scene
		for render_points in feature.get("reference_render_polygons",feature.render_polygons):
			var points := PackedVector2Array()
			for p in render_points:
				points.append(Vector2(p[0],p[1]))
			assert(not Geometry2D.triangulate_polygon(points).is_empty(),"Invalid official polygon "+feature.id+" part "+str(feature.part))
			match feature.kind:
				"building":
					var profile: Dictionary = feature.facade
					if profile.get("style", "") == "gabled_shell":
						gabled_builder.build(self, group, points, profile)
						if profile.has("panels"):
							panel_builder.build(self, group, points, profile)
						continue
					if profile.get("style", "") == "sports_halls":
						halls_builder.build(self, group, points, profile)
						continue
					var color: String = profile.get("color","b0aca0")
					polygon(group,points,feature.height,material("Lingshui "+color,Color(color)),"Building",0.0,feature.get("holes",[]))
					group.get_child(group.get_child_count()-1).set_meta("walk_collision",true)
					polygon(group,points,feature.height+0.18,material("Lingshui roof",Color("85867d")),"Roof",feature.height,feature.get("holes",[]))
					if profile.get("style", "") == "photo_panels":
						panel_builder.build(self, group, points, profile)
					elif not profile.is_empty():
						facade_builder.build(self,group,points,profile)
				"road":
					pass # Built together below so junctions share one surface.
				"water":
					polygon(group,points,0.05,preload("res://assets/water/campus_water.tres"),"Water")
				"sports":
					if feature.has("sports"):
						sports_builder.build(self, group, points, feature.sports)
					else:
						var turf: bool = feature.get("surface_type", "") == "artificial_turf"
						polygon(group,points,0.06,material("Lingshui artificial turf" if turf else "Lingshui sports",Color("65824d") if turf else Color("92776a")),"Sports")
				"plaza", "gate":
					polygon(group,points,0.06,material("Lingshui paving",Color("aaa799")),"Paving")
					group.get_child(group.get_child_count()-1).set_meta("terrain_surface",true)
				"reserve":
					polygon(group,points,0.03,material("Lingshui reserve",Color("899079")),"PlannedFootprint")
				"reference":
					# Point-of-interest outlines are retained as metadata, not invented statues or bridges.
					pass
		generated_count += 1
	preload("res://tools/build_roads.gd").new().build(self, "lingshui")
	if not preload("res://tools/build_photo_surfaces.gd").new().build(self, "lingshui"):
		quit(1)
		return
	if manifest.has("legacy_reference_transform"):
		var registration: Dictionary = manifest.legacy_reference_transform
		var conversion := Transform3D(Basis.from_scale(Vector3(float(registration.scale_x),1,1)),Vector3(registration.offset_xz[0],0,registration.offset_xz[1]))
		for feature: Dictionary in manifest.features:
			if not feature.has("reference_points"): continue
			var group: Node3D = scene.get_node("Feature_"+feature.id+"_"+str(int(feature.part)))
			for child in group.get_children():
				if child is MeshInstance3D: child.transform = conversion * child.transform
	preload("res://tools/build_terrain.gd").new().build(self, "lingshui")
	preload("res://tools/build_vegetation.gd").new().build(self,"lingshui")
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
