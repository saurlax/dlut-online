extends SceneTree

const CornerProfile = preload("res://tools/seventh_corner_profile.gd")
const Collision = preload("res://scripts/shared/campus_collision.gd")

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var feature: Dictionary
	for item: Dictionary in manifest.features:
		if item.id=="2304982": feature = item
	assert(feature.building_parts.size()==2 and not feature.has("reference_points"))
	assert(feature.height==63.6 and feature.height_source=="official-news-81930")
	var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	root.add_child(model)
	var group: Node3D = model.get_node("Feature_2304982")
	var top_vertices := PackedVector2Array()
	var glazing_vertices := 0
	for mesh: MeshInstance3D in group.get_children():
		if mesh.material_override.resource_name == "Seventh opaque glazing":
			assert(mesh.material_override.vertex_color_use_as_albedo)
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				assert(colors.size() == arrays[Mesh.ARRAY_VERTEX].size(), "Merged glazing is missing vertex colors")
				for color in colors:
					assert(minf(color.r, color.g) > 0.8, "Missing end-wall colors turn shared glazing black")
				glazing_vertices += colors.size()
		for vertex: Vector3 in mesh.mesh.get_faces():
			var point := mesh.transform*vertex
			if absf(point.y-63.6)<0.001: top_vertices.append(Vector2(point.x,point.z))
		if mesh.get_meta("walk_collision",false): preload("res://scripts/shared/campus_collision.gd")._collider(mesh)
	assert(glazing_vertices > 0, "Missing seventh residence glazing")
	var ring := PackedVector2Array()
	for coordinate: Array in feature.building_parts[0].points:
		ring.append(Vector2(coordinate[0],coordinate[1]))
	for corner in ring.size():
		if corner in CornerProfile.CORNERS: continue
		var found := false
		for vertex in top_vertices:
			if vertex.distance_to(ring[corner])<0.001: found = true
		assert(found,"Saved tower parapet lost a source corner")
	for corner in CornerProfile.CORNERS:
		for expected in CornerProfile.arc(ring,corner):
			var found := false
			for vertex in top_vertices:
				if vertex.distance_to(expected)<0.001: found=true
			assert(found,"Rounded parapet lost its tangent or arc vertex")
		for vertex in top_vertices:
			assert(vertex.distance_to(ring[corner])>0.20,"Old square corner remains inside the rounded cladding")
	await physics_frame
	await physics_frame
	var space := model.get_world_3d().direct_space_state
	# Independent locations distinguish the south tower, low north podium and
	# photo-visible raised courtyard roof. An overall extruded envelope fails.
	for sample in [[395,145,62.4],[365,100,8.2],[385,117,12.3]]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(sample[0],group.position.y+80,sample[1]),Vector3(sample[0],group.position.y-1,sample[1])))
		assert(not hit.is_empty(),"Seventh roof collision missing")
		assert(absf(hit.position.y-group.position.y-float(sample[2]))<0.04,"Seventh high/low roof partition is wrong")
	var base := group.position.y
	model.free()
	await check_corners(ring,base,manifest)
	print("SEVENTH GEOMETRY PASS: two source parts, official height, seven fixed corners, two rounded corners and three roof levels")
	quit()

func check_corners(ring: PackedVector2Array, base: float, manifest: Dictionary) -> void:
	for server in [false,true]:
		var viewport := SubViewport.new()
		viewport.own_world_3d=true
		root.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		if server:
			world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			var scene: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(scene)
			Collision.build(world,scene,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		# Three independently registered points on the low north/west parapet.
		for at: Vector2 in [Vector2(378.521,79.023),Vector2(355.783,94.636),Vector2(346.927,124.407)]:
			var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,base+10,at.y),Vector3(at.x,base+8,at.y)))
			assert(not top.is_empty() and absf(top.position.y-base-9.05)<0.01,"Low podium parapet missing or wrong height")
		for corner in CornerProfile.CORNERS:
			var before := (ring[posmod(corner-1,ring.size())]-ring[corner]).normalized()
			var after := (ring[(corner+1)%ring.size()]-ring[corner]).normalized()
			var inward := (before+after).normalized()
			var arc := CornerProfile.arc(ring,corner)
			var center := ring[corner]+inward*0.75/sin(acos(before.dot(after))*0.5)
			for i in arc.size()-1:
				assert(absf(arc[i].distance_to(center)-0.75)<0.001,"Corner radius changed")
				var middle := (arc[i]+arc[i+1])*0.5
				var out := (middle-center).normalized()
				var position := Vector3(middle.x,base+30,middle.y)
				var normal := Vector3(out.x,0,out.y)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(position+normal,position-normal))
				assert(not hit.is_empty() and hit.position.distance_to(position)<0.01,"Collision does not follow rounded wall")
				assert(hit.normal.dot(normal)>0.98,"Rounded corner face points inward")
			var cut := ring[corner]+inward*0.1
			var cut_position := Vector3(cut.x,base+30,cut.y)
			var along_cut := Vector3(-inward.y,0,inward.x)
			assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(cut_position-along_cut,cut_position+along_cut)).is_empty(),"Square collision face remains across the rounded cut")
			var sphere := SphereShape3D.new()
			sphere.radius=0.035
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape=sphere
			query.transform=Transform3D(Basis.IDENTITY,Vector3(cut.x,base+30,cut.y))
			assert(space.intersect_shape(query).is_empty(),"Old square corner still blocks movement")
			var middle := (arc[3]+arc[4])*0.5
			var out := (middle-center).normalized()
			var normal := Vector3(out.x,0,out.y)
			var capsule := CapsuleShape3D.new()
			capsule.radius=0.3
			capsule.height=1.8
			query.shape=capsule
			query.transform=Transform3D(Basis.IDENTITY,Vector3(middle.x,base+30,middle.y)+normal*2)
			query.motion=-normal*4
			var travel: float = space.cast_motion(query)[0]
			assert(travel>0.39 and travel<0.45,"Player capsule crosses rounded wall")
		print("SEVENTH ROUND CORNERS PASS server=",server)
		viewport.free()
