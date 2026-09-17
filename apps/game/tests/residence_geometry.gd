extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../../references/eda/buildings/residence_facades.json")))
	var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	root.add_child(model)
	var checked := 0
	for feature: Dictionary in manifest.features:
		if not profiles.has(feature.id): continue
		assert(feature.has("osm_id") and not feature.has("reference_points"),"Residence retains legacy silhouette")
		var registration: Dictionary = profiles[feature.id].osm_registration
		var ring := PackedVector2Array()
		for p: Array in feature.points: ring.append(Vector2(p[0],p[1]))
		if registration.has("facade_vertices"):
			var path := preload("res://tools/residence_facade_path.gd").new()
			path.configure(ring,registration.facade_vertices)
			for i in path.points.size()-1:
				for fraction in [0.0,0.23,0.71,1.0]:
					var distance: float = lerpf(path.stations[i],path.stations[i+1],fraction)
					var unrolled: Vector2 = path.origin+path.axis*distance
					var mapped: Vector3 = path.mapped(Vector3(unrolled.x,8,unrolled.y))
					assert(Vector2(mapped.x,mapped.z).distance_to(path.points[i].lerp(path.points[i+1],fraction))<0.0002,"Facade leaves OSM wall chain")
		var group: Node3D = model.get_node("Feature_"+feature.id)
		var roof_corners := PackedVector2Array()
		for mesh: MeshInstance3D in group.get_children():
			for vertex: Vector3 in mesh.mesh.get_faces():
				var position := mesh.transform*vertex
				if absf(position.y-float(profiles[feature.id].height)-0.2)<0.001:
					roof_corners.append(Vector2(position.x,position.z))
		for point in ring:
			var found := false
			for corner in roof_corners:
				if point.distance_to(corner)<0.001:
					found = true
					break
			assert(found,"Saved roof lost OSM outline vertex")
		if feature.id in ["77937","77938","77941"]:
			var total := Vector2.ZERO
			var count := 0
			for mesh: MeshInstance3D in group.get_children():
				if mesh.material_override.resource_name != "EDA residence blue grey stair tower": continue
				for p: Vector3 in mesh.mesh.get_faces():
					var world := mesh.transform*p
					total += Vector2(world.x,world.z)
					count += 1
			assert(count>0,"Saved photo-visible tower missing")
			var center := total/count
			var expected := {"77937":Vector2(383,41),"77938":Vector2(470,57),"77941":Vector2(310,293)}
			assert(center.distance_to(expected[feature.id])<6,"Tower moved away from photo-visible end wall")
		checked += 1
	# The third residence recess must keep its photographed inset and floor slab.
	var third: Node3D = model.get_node("Feature_77935")
	for mesh: MeshInstance3D in third.get_children():
		if mesh.get_meta("walk_collision",false): preload("res://scripts/shared/campus_collision.gd")._collider(mesh)
	await physics_frame
	await physics_frame
	var third_feature: Dictionary
	for feature: Dictionary in manifest.features:
		if feature.id=="77935": third_feature = feature
	var a := Vector2(third_feature.points[2][0],third_feature.points[2][1])
	var b := Vector2(third_feature.points[3][0],third_feature.points[3][1])
	var span: Array = profiles["77935"].osm_registration.recess_span
	var center := a.lerp(b,(float(span[0])+float(span[1]))/2)
	var tangent := (b-a).normalized()
	var out := Vector2(tangent.y,-tangent.x)
	var start := Vector3(center.x,third.position.y+5,center.y)
	var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start+Vector3(out.x,0,out.y)*2,start-Vector3(out.x,0,out.y)*2))
	assert(not hit.is_empty(),"Recess back wall collision missing")
	var hit_point: Vector3 = hit.position
	assert(absf(Vector2(hit_point.x-center.x,hit_point.z-center.y).dot(out)+0.8)<0.03,"Recess collision filled or detached from wall")
	assert(checked==6)
	print("RESIDENCE GEOMETRY PASS: six OSM shells, facade chains, tower ends and recessed wall collision")
	quit()
