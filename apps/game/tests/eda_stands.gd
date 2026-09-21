extends SceneTree
const Collision = preload("res://scripts/shared/campus_collision.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var feature: Dictionary
	for item in manifest.features:
		if item.id=="39327169": feature=item
	var north := Vector2(feature.points[18][0],feature.points[18][1])
	var south := Vector2(feature.points[0][0],feature.points[0][1])
	var axis := (south-north).normalized()
	var inward := Vector2(axis.y,-axis.x)
	var center := Vector2.ZERO
	for p in feature.sports_lines[0].points: center+=Vector2(p[0],p[1])*0.25
	var origin := north+axis*(center-north).dot(axis)
	var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	var base: float = model.get_node("Feature_39327169").position.y
	var boundary := PackedVector2Array()
	for p in feature.points: boundary.append(Vector2(p[0],p[1]))
	for mesh: MeshInstance3D in model.get_node("Feature_39327169").get_children():
		if not mesh.material_override.resource_name.begins_with("EDA stand "): continue
		for vertex: Vector3 in mesh.mesh.get_faces():
			var point: Vector3 = mesh.transform*vertex
			assert(Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),boundary),"Stand geometry extends beyond its registered site")
	model.free()
	for server in [false,true]:
		var viewport := SubViewport.new()
		viewport.own_world_3d=true
		root.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		if server: world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			model=load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(model)
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for aisle in [-50.0,-25.0,25.0,50.0]:
			for step in 16:
				var p: Vector2 = origin+axis*aisle+inward*(7.0-step*0.4)
				var y := base+0.15+0.2*(step+1)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,y+0.3,p.y),Vector3(p.x,y-0.3,p.y)))
				assert(not hit.is_empty() and absf(hit.position.y-y)<0.002,"Stand aisle tread missing or discontinuous")
				var shape := CapsuleShape3D.new()
				shape.radius=0.35
				shape.height=1.8
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape=shape
				query.transform=Transform3D(Basis.IDENTITY,Vector3(p.x-axis.x*0.4,y+1.15,p.y-axis.y*0.4))
				query.motion=Vector3(axis.x,0,axis.y)*0.8
				assert(space.cast_motion(query)[0]>0.999,"Handrails obstruct aisle body clearance")
		var platform := origin+inward*4.0
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(platform.x,base+3,platform.y),Vector3(platform.x,base,platform.y)))
		assert(not floor_hit.is_empty() and absf(floor_hit.position.y-base-0.95)<0.002,"Covered platform missing")
		var roof_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(platform.x,base+7,platform.y),Vector3(platform.x,base+4,platform.y)))
		assert(not roof_hit.is_empty() and absf(roof_hit.position.y-base-5.15)<0.002,"Stand canopy missing")
		print("STANDS PHYSICS PASS server=",server," 64 treads, aisle capsule clearance, platform and canopy")
		viewport.free()
	quit()
