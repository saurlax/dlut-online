extends SceneTree
const Collision = preload("res://scripts/shared/campus_collision.gd")
const RoadGeometry = preload("res://scripts/shared/road_geometry.gd")
func ring(raw: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for v in raw: p.append(Vector2(v[0],v[1]))
	return p
func area(p: PackedVector2Array) -> float:
	var value := 0.0
	for i in p.size():value+=p[i].cross(p[(i+1)%p.size()])*0.5
	return absf(value)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	create_timer(60).timeout.connect(func():quit(2))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var points := PackedVector2Array()
	for f in manifest.features:
		if f.id=="77927":points=ring(f.points)
	assert(points.size()==25)
	var north := points[1]-points[0]
	var south := points[2]-points[24]
	assert(absf(north.normalized().cross(south.normalized()))<0.00001,"Main block was sheared by refinement")
	assert(absf(south.length()/north.length()-159.0/160)<0.00001)
	for f in manifest.features:
		if f.kind!="building" or f.id=="77927":continue
		for p in Geometry2D.intersect_polygons(points,ring(f.points)):
			assert(area(p)<0.1,"Refined C intersects another building: "+str(f.id))
	var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads
	for road in roads:
		for ribbon in RoadGeometry.polygons([road]):
			for p in Geometry2D.intersect_polygons(points,ribbon):assert(area(p)<0.01,"Road width intersects C")
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	var reference: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	var base: float = reference.get_node("Feature_77927").position.y
	reference.free()
	for server in [false,true]:
		var viewport := SubViewport.new()
		viewport.own_world_3d=true
		root.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		if server:world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(model)
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for p: Vector2 in [Vector2(145,20),Vector2(150,85)]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,base+35,p.y),Vector3(p.x,base+20,p.y)))
			assert(not hit.is_empty() and absf(hit.position.y-base-24.78)<0.03,"Main/rotunda roof mismatch")
		# The two gaps flanking the narrow connector must remain open.
		for p: Vector2 in [Vector2(135,69),Vector2(162,69)]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,base+30,p.y),Vector3(p.x,base+3,p.y)))
			assert(hit.is_empty(),"C connector gap filled")
		var edge := points[2]-points[1]
		var out := Vector2(edge.y,-edge.x).normalized()
		var p := points[1].lerp(points[2],0.9)
		for sample in [[10.0,-0.8],[22.5,0.0]]:
			var a := p+out*2
			var b := p-out*2
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(a.x,base+sample[0],a.y),Vector3(b.x,base+sample[0],b.y)))
			var expected: Vector2 = p+out*sample[1]
			assert(not hit.is_empty() and hit.position.distance_to(Vector3(expected.x,base+sample[0],expected.y))<0.03,"Recess/upper wall changed")
		var count := 0
		for road in roads:
			if road.osm_way_id!=1076344083:continue
			for i in range(4,13):
				var a := Vector2(road.points[i][0],road.points[i][1])
				var b := Vector2(road.points[i+1][0],road.points[i+1][1])
				var axis := (b-a).normalized()
				var side := Vector2(-axis.y,axis.x)
				for fraction in [0.1,0.5,0.9]:
					for offset in [-2.5,0.0,2.5]:
						var at: Vector2 = a.lerp(b,fraction)+side*offset
						var y: float = terrain.elevation(at.x,at.y)+0.22
						var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,y+40,at.y),Vector3(at.x,y-1,at.y)))
						assert(not hit.is_empty() and absf(hit.position.y-y)<0.03,"C road obstructed by saved collision")
						count+=1
		assert(count==81)
		print("C ALIGNMENT PASS: server=",server," road samples=",count," roofs, gaps, recessed facade")
		world.free()
		viewport.free()
	print("C FOOTPRINT PASS: parallel end walls, distinct connector, no building/full-road overlap")
	quit()
