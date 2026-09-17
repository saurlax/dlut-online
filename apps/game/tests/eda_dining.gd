extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var ring := PackedVector2Array()
	for feature in manifest.features:
		if feature.id != "77943": continue
		assert(feature.osm_id=="way/375541048" and feature.osm_version==5)
		assert(is_equal_approx(float(feature.height),12.0))
		for p in feature.points: ring.append(Vector2(p[0],p[1]))
	assert(ring.size()==19)
	var reference: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	var base: float = reference.get_node("Feature_77943").position.y
	reference.free()
	# Photo registration: south divider is on directed edge 14 -> 13.
	var divider_axis := (ring[13]-ring[14]).normalized()
	var divider_out := Vector2(divider_axis.y,-divider_axis.x)
	if Geometry2D.is_point_in_polygon((ring[14]+ring[13])/2+divider_out,ring): divider_out = -divider_out
	var divider := ring[14].lerp(ring[13],0.82)+divider_out*0.65
	var east_axis := (ring[14]-ring[15]).normalized()
	var east_out := Vector2(east_axis.y,-east_axis.x)
	if Geometry2D.is_point_in_polygon((ring[15]+ring[14])/2+east_out,ring): east_out = -east_out
	var east := ring[15].lerp(ring[14],0.5)
	for server in [false,true]:
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		root.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		if server:
			world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(model)
			assert(model.get_node("Feature_77943").get_child_count()<=8)
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for sample in [[Vector2(350,220),12.18],[Vector2(341,239),12.18],[divider,14.5]]:
			var pos: Vector2 = sample[0]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,base+30,pos.y),Vector3(pos.x,base+10,pos.y)))
			assert(not hit.is_empty(),"Missing dining roof or projection")
			assert(absf(hit.position.y-base-float(sample[1]))<0.02,"Wrong dining height: "+str(hit))
		var near := east+east_out*3
		var far := east-east_out*3
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(near.x,base+7,near.y),Vector3(far.x,base+7,far.y)))
		assert(not wall.is_empty() and wall.position.distance_to(Vector3(east.x,base+7,east.y))<0.03,"East exterior must match the registered wall")
		# Divider must project outside the shell, with clear space above the lower roof beside it.
		var beside := divider+divider_axis
		var clearance := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(beside.x,base+16,beside.y),Vector3(beside.x,base+13.5,beside.y)))
		assert(clearance.is_empty(),"Raised divider expanded into its adjacent bay")
		print("DINING PHYSICS PASS: server=",server," two roofs, raised divider, adjacent clearance and east wall")
		world.free()
		viewport.free()
	print("PASS: client/server dining roof, raised divider and closed exterior")
	quit()
