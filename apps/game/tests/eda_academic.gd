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
	check_tower_head_normals(reference.get_node("Feature_77925"))
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
	var entry_center := tower_a.lerp(tower_b,0.30)
	var canopy_a := ring_b[17]
	var canopy_b := ring_b[0]
	var canopy_axis := (canopy_b-canopy_a).normalized()
	var canopy_out := outward(ring_b,17)
	var canopy_center := canopy_a.lerp(canopy_b,0.72)
	var rotunda_mid := (ring_c[6]+ring_c[7])/2
	var samples := [[Vector2(100,-45),base_a+21.18],[Vector2(25,-10),base_b+9.78],[Vector2(145,20),base_c+24.78],[tower_center+tower_axis*1.9,base_a+31.1],[rotunda_mid+outward(ring_c,6)*0.4,base_c+24.82],[(canopy_a+canopy_b)/2+canopy_out*0.45,base_b+9.87]]
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	var ellipse_map := preload("res://tools/eda_ellipse_envelope.gd").new()
	ellipse_map.configure(ring_c,JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/buildings/academic_facades.json"))["77927"].osm_registration.curve_refinement)
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
				# C permits four local single-sided curve variants; straight-wing batches remain.
				var material_budget: int = {"77925":23,"77928":17,"77927":12}[id]
				assert(model.get_node("Feature_"+id).get_child_count()<=material_budget)
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		check_ellipse_wall(space,base_c)
		check_curved_eave_faces(space,ring_c,base_c)
		# Sample both sides of every rotunda joint, above and below all six bands.
		for vertex in range(5,18):
			var bisector := (outward(ring_c,vertex-1)+outward(ring_c,vertex)).normalized()
			for y in [8.8,12.4,16.0,19.6,23.0,24.7]:
				var distance := 1.5 if y>24.0 else 0.7
				var joint := ring_c[vertex]+bisector*distance/bisector.dot(outward(ring_c,vertex))
				for side in [-1.0,1.0]:
					var pos: Vector2 = joint+Vector2(bisector.y,-bisector.x)*side*0.025
					var moved:Vector3=ellipse_map.shift(Vector3(pos.x,y,pos.y))
					pos+=Vector2(moved.x,moved.z)
					for direction in [-1.0,1.0]:
						var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,base_c+y+direction*0.5,pos.y),Vector3(pos.x,base_c+y-direction*0.5,pos.y)))
						assert(not hit.is_empty() and absf(hit.position.y-base_c-y-direction*0.12)<0.015,"C rotunda band joint/top/underside gap")
		for sample in samples:
			var pos: Vector2 = sample[0]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,80,pos.y),Vector3(pos.x,-1,pos.y)))
			assert(not hit.is_empty(),"Missing roof at "+str(pos))
			assert(absf(hit.position.y-float(sample[1]))<0.03,"Wrong roof height at "+str(pos)+": "+str(hit.position))
		for sample in [[0.0,false],[2.4,true]]:
			var p := tower_center+tower_axis*float(sample[0])
			var start := p+tower_out*3
			var end := p-tower_out*3
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(start.x,base_a+30.25,start.y),Vector3(end.x,base_a+30.25,end.y)))
			assert(hit.is_empty()!=bool(sample[1]),"A tower top opening/fins must remain distinct")
		for offset in [-5.0,-0.35,4.8]:
			var p := entry_center+tower_axis*float(offset)+tower_out*0.6
			for direction in [-1.0,1.0]:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,base_a+4.1+direction*0.6,p.y),Vector3(p.x,base_a+4.1-direction*0.6,p.y)))
				assert(not hit.is_empty() and absf(hit.position.y-base_a-4.1-direction*0.04)<0.015,"A entry canopy top and underside must match")
			var wall_p := entry_center+tower_axis*float(offset)
			var wall_from := wall_p+tower_out
			var wall_to := wall_p-tower_out
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(wall_from.x,base_a+1.5,wall_from.y),Vector3(wall_to.x,base_a+1.5,wall_to.y)))
			if absf(offset)<0.8:
				assert(hit.is_empty(),"A central doorway must be open")
			else:
				assert(not hit.is_empty() and Vector2(hit.position.x,hit.position.z).distance_to(wall_p)<0.015,"A facade beside the doorway remains closed")
		for along in [-7.0,0.0,7.0]:
			for depth in [0.5,2.2]:
				var p: Vector2 = entry_center+tower_axis*float(along)+tower_out*float(depth)
				var y: float = terrain.elevation(p.x,p.y)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,y+0.5,p.y),Vector3(p.x,y-0.5,p.y)))
				assert(not hit.is_empty() and absf(hit.position.y-y-0.018)<0.005,"A entry paving must follow terrain")
				assert(hit.normal.y>0.98,"A entry paving normal must face upward")
		# The head fins have distinct east/west heights above the lower solid cap.
		for sample in [[-2.4,35.2],[2.4,32.5],[0.0,29.6]]:
			var p: Vector2 = tower_center+tower_axis*float(sample[0])
			var top_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,base_a+37,p.y),Vector3(p.x,base_a+28,p.y)))
			assert(not top_hit.is_empty() and absf(top_hit.position.y-base_a-float(sample[1]))<0.015,"A tower fin/cap height or aperture changed")
			assert(top_hit.normal.y>0.98,"A tower fin/cap normal reversed")
		for i in 8:
			var angle := TAU*i/8.0
			var radius := tower_axis*cos(angle)*1.6+tower_out*sin(angle)*0.75
			for scale in [0.0,0.6,1.3]:
				var p: Vector2 = tower_center+radius*float(scale)
				for direction in [-1.0,1.0]:
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,base_a+31.0+direction*0.4,p.y),Vector3(p.x,base_a+31.0-direction*0.4,p.y)))
					if scale<1.0:
						assert(hit.is_empty(),"A tower elliptical skylight must be open from both sides")
					else:
						assert(not hit.is_empty() and absf(hit.position.y-base_a-31.0-direction*0.1)<0.015,"A tower skylight rim top/underside")
						assert(hit.normal.y*direction>0.98,"A tower skylight rim normal reversed")
			var outside := tower_center+radius*1.1
			var reveal := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(tower_center.x,base_a+31.0,tower_center.y),Vector3(outside.x,base_a+31.0,outside.y)))
			assert(not reveal.is_empty(),"A tower skylight inner reveal missing")
			var expected := tower_center+radius
			assert(Vector2(reveal.position.x,reveal.position.z).distance_to(expected)<0.015,"A tower skylight ellipse shape")
			var inward := -(tower_axis*cos(angle)/1.6+tower_out*sin(angle)/0.75).normalized()
			assert(Vector2(reveal.normal.x,reveal.normal.z).dot(inward)>0.98,"A tower skylight reveal normal deviates from inward ellipse normal: "+str(reveal.normal))
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
		for edge in [6,11,14,16]:
			var column_axis := (ring_c[edge+1]-ring_c[edge]).normalized()
			var column_out := outward(ring_c,edge)
			var column_mid := (ring_c[edge]+ring_c[edge+1])/2
			for offset in [-0.4,-0.25,0.0,0.25,0.4]:
				var p: Vector2 = column_mid+column_axis*offset
				var start := p+column_out*1.5
				# Stop at the column centre plane; the newly curved wall lies behind it.
				var end := p+column_out*0.48
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(start.x,base_c+4,start.y),Vector3(end.x,base_c+4,end.y)))
				if absf(offset)>0.35:
					assert(hit.is_empty(),"C round column exceeds its diameter")
				else:
					var radius_depth := sqrt(0.35*0.35-offset*offset)
					var expected_p := p+column_out*(0.48+radius_depth)
					assert(not hit.is_empty() and hit.position.distance_to(Vector3(expected_p.x,base_c+4,expected_p.y))<0.012,"C column must have circular rather than square collision: edge=%d offset=%s expected=%s hit=%s" % [edge,offset,Vector3(expected_p.x,base_c+4,expected_p.y),hit])
					var normal := Vector3(column_axis.x*offset+column_out.x*radius_depth,0,column_axis.y*offset+column_out.y*radius_depth).normalized()
					assert(hit.normal.dot(normal)>0.98,"C column face normal points inward")
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

func check_tower_head_normals(feature: Node3D) -> void:
	var triangles := 0
	for child in feature.get_children():
		if not child is MeshInstance3D: continue
		for surface in child.mesh.get_surface_count():
			var arrays: Array = child.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty(): indices=PackedInt32Array(range(vertices.size()))
			for i in range(0,indices.size(),3):
				var points: Array[Vector3] = []
				for j in 3: points.append(child.transform*vertices[indices[i+j]])
				if points.any(func(p: Vector3): return p.y<30.899 or p.y>31.101): continue
				var normal := (points[2]-points[0]).cross(points[1]-points[0])
				assert(normal.length()>0.00001,"Degenerate tower head triangle")
				normal=normal.normalized()
				for j in 3:
					var saved: Vector3 = (child.basis*normals[indices[i+j]]).normalized()
					assert(saved.dot(normal)>0.999,"Tower head saved normals must match clockwise faces")
				triangles+=1
	assert(triangles==416,"Tower head must contain all 52 closed ring sectors: "+str(triangles))
	print("A TOWER HEAD NORMALS PASS: ",triangles," triangles")

func outward(ring: PackedVector2Array, edge: int) -> Vector2:
	var a := ring[edge]
	var b := ring[(edge+1)%ring.size()]
	var axis := (b-a).normalized()
	var out := Vector2(axis.y,-axis.x)
	if Geometry2D.is_point_in_polygon((a+b)/2+out,ring): out = -out
	return out

func check_ellipse_wall(space: PhysicsDirectSpaceState3D, base: float) -> void:
	var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/buildings/academic_facades.json"))["77927"].osm_registration.curve_refinement.ellipse
	var center:=Vector2(profile.center_xz[0],profile.center_xz[1])
	var radii:=Vector2(profile.radii_m[0],profile.radii_m[1])
	for sample in 120:
		var angle:=TAU*sample/120.0
		var p:=center+Vector2(radii.x*cos(angle),radii.y*sin(angle)).rotated(float(profile.rotation_rad))
		if p.y<74 and absf(p.x-center.x)<5:continue
		var normal:=Vector2(cos(angle)/radii.x,sin(angle)/radii.y).rotated(float(profile.rotation_rad)).normalized()
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x+normal.x*2,base+18.3,p.y+normal.y*2),Vector3(p.x-normal.x,base+18.3,p.y-normal.y)))
		assert(not hit.is_empty(),"C ellipse exterior has a gap")
		assert(Vector2(hit.position.x,hit.position.z).distance_to(p)<0.04,"C wall retains an irregular mapped contour")
		assert(Vector2(hit.normal.x,hit.normal.z).normalized().dot(normal)>.985,"C ellipse normal mismatch")
	print("C ELLIPSE PASS: analytical perimeter and outward normals")

func check_curved_eave_faces(space: PhysicsDirectSpaceState3D, points: PackedVector2Array, base: float) -> void:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/buildings/academic_facades.json"))
	var curve := preload("res://tools/eda_ellipse_envelope.gd").new()
	curve.configure(points,profiles["77927"].osm_registration.curve_refinement)
	for edge in [6,8,10,12,14,16]:
		var out := outward(points,edge)
		for y in [12.4,19.6,24.7]:
			var offset := 1.8 if y>24 else .88
			var p := (points[edge]+points[edge+1])*.5+out*offset
			var original := Vector3(p.x,y,p.y)
			var expected := original+curve.shift(original)+Vector3(0,base,0)
			var normal := Vector3(out.x,0,out.y)
			var query := PhysicsRayQueryParameters3D.create(expected+normal*.4,expected-normal*.15)
			query.hit_back_faces=false
			var hit := space.intersect_ray(query)
			assert(not hit.is_empty() and hit.position.distance_to(expected)<.01,"C curved eave outer face missing or reversed")
			assert(hit.normal.dot(normal)>.95,"C curved eave outer normal reversed")
	print("C CURVED EAVE FACES PASS: 18 outward side rays")
