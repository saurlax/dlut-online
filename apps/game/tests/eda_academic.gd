extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")


func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var rings: Dictionary = {}
	var bases: Dictionary = {}
	var reference: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	for feature in manifest.features:
		if feature.id not in ["77925","77928","77927"]: continue
		var ring := PackedVector2Array()
		for p in feature.points: ring.append(Vector2(p[0],p[1]))
		rings[feature.id] = ring
		bases[feature.id] = reference.get_node("Feature_"+feature.id).position.y
	reference.free()
	var ring_a: PackedVector2Array = rings["77925"]
	var ring_b: PackedVector2Array = rings["77928"]
	var ring_c: PackedVector2Array = rings["77927"]
	assert(ring_a.size()==8 and ring_b.size()==18 and ring_c.size()==25)
	var base_a: float = bases["77925"]
	var base_b: float = bases["77928"]
	var base_c: float = bases["77927"]
	var tower_a := ring_a[3]
	var tower_b := ring_a[4]
	var tower_axis := (tower_b-tower_a).normalized()
	var tower_out := outward(ring_a,3)
	var tower_center := tower_a.lerp(tower_b,0.13)
	var canopy_a := ring_b[17]
	var canopy_b := ring_b[0]
	var canopy_axis := (canopy_b-canopy_a).normalized()
	var canopy_out := outward(ring_b,17)
	var canopy_center := canopy_a.lerp(canopy_b,0.72)
	var rotunda_mid := (ring_c[6]+ring_c[7])/2
	var samples := [[Vector2(100,-45),base_a+21.18],[Vector2(25,-10),base_b+9.78],[Vector2(145,20),base_c+24.78],[tower_center,base_a+28.6],[rotunda_mid+outward(ring_c,6)*0.4,base_c+24.82],[(canopy_a+canopy_b)/2+canopy_out*0.45,base_b+9.87]]
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
			for id in ["77925","77928","77927"]:
				assert(model.get_node("Feature_"+id).get_child_count()<=7)
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for sample in samples:
			var pos: Vector2 = sample[0]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,80,pos.y),Vector3(pos.x,-1,pos.y)))
			assert(not hit.is_empty(),"Missing roof at "+str(pos))
			assert(absf(hit.position.y-float(sample[1]))<0.03,"Wrong roof height at "+str(pos)+": "+str(hit.position))
		for sample in [[0.0,false],[2.4,true]]:
			var p := tower_center+tower_axis*float(sample[0])
			var start := p+tower_out*3
			var end := p-tower_out*3
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(start.x,base_a+28.0,start.y),Vector3(end.x,base_a+28.0,end.y)))
			assert(hit.is_empty()!=bool(sample[1]),"A tower top opening/fins must remain distinct")
		var eave := ring_c[2].lerp(ring_c[3],0.5)+outward(ring_c,2)*0.4
		var south_eave := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(eave.x,base_c+26,eave.y),Vector3(eave.x,base_c+23,eave.y)))
		assert(not south_eave.is_empty() and absf(south_eave.position.y-base_c-24.78)<0.03,"Missing C south-end eave")
		var recess_a := ring_c[1]
		var recess_b := ring_c[2]
		var recess_out := outward(ring_c,1)
		var recess_p := recess_a.lerp(recess_b,0.9)
		for sample in [[10.0,-0.8],[22.5,0.0]]:
			var from_p := recess_p+recess_out*2
			var to_p := recess_p-recess_out*2
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(from_p.x,base_c+sample[0],from_p.y),Vector3(to_p.x,base_c+sample[0],to_p.y)))
			var expected_p := recess_p+recess_out*float(sample[1])
			assert(not hit.is_empty() and hit.position.distance_to(Vector3(expected_p.x,base_c+sample[0],expected_p.y))<0.03,"C south recess and upper bridge must have distinct walls")
		# The rotunda's visible lower column must remain solid beyond the wall.
		var out := outward(ring_c,6)
		var mid := rotunda_mid
		var from := mid+out*1.5
		var to := mid+out*0.1
		var column := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(from.x,base_c+4,from.y),Vector3(to.x,base_c+4,to.y)))
		var expected := mid+out*0.83
		assert(not column.is_empty() and column.position.distance_to(Vector3(expected.x,base_c+4,expected.y))<0.03,"Missing C rotunda column")
		for sample in [[1.9,0.9,true],[0.0,0.9,false]]:
			var p := canopy_center+canopy_axis*float(sample[0])+canopy_out*float(sample[1])
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,base_b+5.5,p.y),Vector3(p.x,base_b+4.0,p.y)))
			assert(hit.is_empty()!=bool(sample[2]),"B canopy beam/gap must match: "+str(sample)+" / "+str(hit))
		# B's former 21m shell must not remain above the low wing.
		var clearance := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,base_b+15,0),Vector3(40,base_b+15,0)))
		assert(clearance.is_empty(),"Old B wing collision remains at 15m")
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,base_b+2,0),Vector3(40,base_b+2,0)))
		assert(not wall.is_empty(),"Low B wing exterior must remain closed")
		print("ACADEMIC PHYSICS PASS: server=",server," six roofs, tower aperture, eave, recessed wall, rotunda column, canopy and B clearance")
		world.free()
		viewport.free()
	print("PASS: client/server academic A/B/C roof heights, A glass tower C rotunda column/eaves and low B clearance")
	quit()

func outward(ring: PackedVector2Array, edge: int) -> Vector2:
	var a := ring[edge]
	var b := ring[(edge+1)%ring.size()]
	var axis := (b-a).normalized()
	var out := Vector2(axis.y,-axis.x)
	if Geometry2D.is_point_in_polygon((a+b)/2+out,ring): out = -out
	return out
