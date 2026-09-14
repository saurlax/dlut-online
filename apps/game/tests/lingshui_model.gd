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
	# Photo-supported sports surfaces stay inside their source footprints.
	for feature in campus.manifest.features:
		if not feature.has("sports"):
			continue
		var outline := PackedVector2Array()
		for p in feature.points:
			outline.append(Vector2(p[0], p[1]))
		var group: Node3D = campus.model.get_node("Feature_"+feature.id+"_0")
		for child in group.get_children():
			if not child is MeshInstance3D:
				continue
			var vertices: PackedVector3Array = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var p: Vector3 = child.transform * vertex
				if p.y > 0.13 or p.y < 0.06:
					continue
				var flat := Vector2(p.x, p.z)
				var near_edge := false
				for i in outline.size():
					if flat.distance_to(Geometry2D.get_closest_point_to_segment(flat, outline[i], outline[(i+1)%outline.size()])) < 0.02:
						near_edge = true
						break
				assert(near_edge or Geometry2D.is_point_in_polygon(flat, outline), "Sports surface must stay within the official footprint")
			if not child.get_meta("walk_collision", false):
				assert(child.find_children("*", "StaticBody3D", true, false).is_empty(), "Field markings and seating decoration have no colliders")
	var space := campus.get_world_3d().direct_space_state
	# Photo-supported pitched roofs must collide at their ridges and both slopes.
	for sample in [Vector3(727.3,6.5,-245),Vector3(723.55,5.75,-245),Vector3(735.95,5.75,-245),Vector3(730,10.6,-315.8),Vector3(730,9.9,-327.827),Vector3(730,9.9,-302.6365),Vector3(319,12.3,-556),Vector3(319,11.55,-560.6065),Vector3(319,11.55,-551.3035),Vector3(380,11.0,-523),Vector3(380,9.9,-528.354),Vector3(380,9.9,-517.7405),Vector3(460,11.2,-526),Vector3(460,10.1,-530.909),Vector3(460,10.1,-520.9565),Vector3(375,13.4,-448),Vector3(375,12.3,-452.687),Vector3(375,12.3,-443.066)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(sample.x,25,sample.z),Vector3(sample.x,0,sample.z)))
		assert(not hit.is_empty() and absf(hit.position.y-sample.y)<0.04,"Pitched hall ridges and roof slopes must collide at the modeled height")
	# Each photo-supported window slab must collide at its own level.
	for sample in [Vector3(584.0865,11.48,-524.73),Vector3(575.0393,11.48,-524.658),Vector3(572.0235,11.48,-524.634),Vector3(575.0393,7.93,-524.658),Vector3(572.0235,7.93,-524.634),Vector3(594.0925,7.93,-472.3805),Vector3(594.0925,11.48,-472.3805),Vector3(588.6862,7.93,-498.5697),Vector3(588.6862,11.48,-498.5697),Vector3(640.84809,4.38,-424.10669),Vector3(640.84809,7.93,-424.10669),Vector3(640.84809,11.48,-424.10669),Vector3(632.21747,4.38,-423.89444),Vector3(632.21747,7.93,-423.89444),Vector3(632.21747,11.48,-423.89444),Vector3(629.34059,4.38,-423.82369),Vector3(629.34059,7.93,-423.82369),Vector3(629.34059,11.48,-423.82369),Vector3(620.70997,4.38,-423.61144),Vector3(620.70997,7.93,-423.61144),Vector3(620.70997,11.48,-423.61144),Vector3(636.02889,4.38,-448.67056),Vector3(636.02889,7.93,-448.67056),Vector3(636.02889,11.48,-448.67056),Vector3(632.97906,4.38,-476.03266),Vector3(632.97906,7.93,-476.03266),Vector3(632.97906,11.48,-476.03266)]:
		var platform_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(sample+Vector3.UP*0.5,sample-Vector3.UP*0.5))
		assert(not platform_hit.is_empty() and absf(platform_hit.position.y-sample.y)<0.02,"East Hill window platforms must collide at their slab tops")
	assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(584.09,12.3,-524.4),Vector3(584.09,10,-524.4))).is_empty(),"Window platform collision must stop at its outside edge")
	assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(584.088,11.9,-524.0),Vector3(584.088,11.9,-524.9))).is_empty(),"Thin window platform rails must remain decorative")
	# Wide network-center ledges are structural surfaces outside the wall footprint.
	for level in [4.275,8.375,12.775]:
		for flat in [Vector2(220,-45.2),Vector2(197.6,-69)]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(flat.x,level+0.4,flat.y),Vector3(flat.x,level-0.4,flat.y)))
			assert(not hit.is_empty() and absf(hit.position.y-level)<0.03,"Network-center projecting ledges must have structural collision")
	for feature in campus.manifest.features:
		if feature.facade.get("style", "") != "photo_panels":
			continue
		var ring := PackedVector2Array()
		for point in feature.render_polygons[0]:
			ring.append(Vector2(point[0],point[1]))
		var triangles := Geometry2D.triangulate_polygon(ring)
		var center := (ring[triangles[0]]+ring[triangles[1]]+ring[triangles[2]])/3.0
		var start := Vector3(center.x,60.0,center.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(start,start-Vector3(0,65,0)))
		assert(not hit.is_empty() and absf(hit.position.y-float(feature.height)-0.18)<0.03, "Photo-estimated roof height must match client collision: "+feature.id)
	for sample in [Vector3(390,40,165), Vector3(410,40,239)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(sample, sample-Vector3(0,45,0)))
		assert(not hit.is_empty() and hit.position.y > 13.0, "Curved hall roofs must have structural collision")
	var stand_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(240,2,175),Vector3(220,2,175)))
	assert(not stand_hit.is_empty(), "West stand structure must block players")
	var map_script = preload("res://scripts/client/campus_map.gd")
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
	player.position = Vector3(338,0.35,183)
	for i in 120:
		await physics_frame
		player.velocity = Vector3(0,-2,6)
		player.move_and_slide()
	assert(player.is_on_floor() and player.position.z > 193, "The running track remains walkable")
	# The academic apartment begins at z=270; start in the gap, not inside it.
	player.position = Vector3(408,0.35,268)
	for i in 120:
		await physics_frame
		player.velocity = Vector3(0,-2,-10)
		player.move_and_slide()
	assert(player.position.z > 263.0 and player.position.z < 266.0, "Closed pool podium must block a walking capsule: " + str(player.position))
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
