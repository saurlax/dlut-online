extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	var reference: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	var base_y: float = reference.get_node("Feature_77921").position.y
	reference.free()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var points := PackedVector2Array()
	for feature in manifest.features:
		if feature.id=="77921":
			for point in feature.points: points.append(Vector2(point[0],point[1]))
	var axis := (points[7]-points[5]).normalized()
	var out := Vector2(axis.y,-axis.x)
	if Geometry2D.is_point_in_polygon((points[5]+points[7])*0.5+out,points): out=-out
	# Independently registered north projection center and roof interior sample.
	var projection := points[5].lerp(points[7],0.13)+out*0.9
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
			assert(model.get_node("Feature_77921").get_child_count()<=16)
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for sample in [[Vector2(-270,290),base_y+20.18],[projection,base_y+16.225]]:
			var pos: Vector2 = sample[0]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,base_y+30,pos.y),Vector3(pos.x,base_y,pos.y)))
			assert(not hit.is_empty(),"Missing comprehensive roof or projection")
			assert(absf(hit.position.y-float(sample[1]))<0.02,"Wrong comprehensive height: "+str(hit))
		# The registered rooftop enclosure is bounded to the inner north roof.
		for fraction in [0.13,0.185,0.24]:
			for depth in [1.0,4.0]:
				var at: Vector2 = points[5].lerp(points[7],fraction)-out*depth
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,base_y+26,at.y),Vector3(at.x,base_y+19,at.y)))
				assert(not hit.is_empty() and absf(hit.position.y-base_y-23.52)<0.02,"Rooftop enclosure cap missing")
		for fraction in [0.07,0.30]:
			var at: Vector2 = points[5].lerp(points[7],fraction)-out*3.0
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,base_y+26,at.y),Vector3(at.x,base_y+19,at.y)))
			assert(not hit.is_empty() and absf(hit.position.y-base_y-20.18)<0.02,"Rooftop enclosure exceeds registered width")
		print("COMPREHENSIVE ROOF ENCLOSURE PASS: server=",server," six cap samples and two outside controls")
		# The round annex steps outward above the lower wall and stays closed.
		var annex_center: Vector2 = points[5].lerp(points[7],0.78)+out*6.4
		for degrees in [35.0,90.0,145.0]:
			var radians := deg_to_rad(degrees)
			var direction := axis*cos(radians)+out*sin(radians)
			for spec in [[4.0,9.52],[8.41,9.52]]:
				var at: Vector2 = annex_center+direction*float(spec[0])
				var roof_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,base_y+12,at.y),Vector3(at.x,base_y+8,at.y)))
				assert(not roof_hit.is_empty() and absf(roof_hit.position.y-base_y-float(spec[1]))<0.025,"Annex solid roof missing under decorative coping")
			var at: Vector2 = annex_center+direction*7.8
			var soffit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,base_y+2,at.y),Vector3(at.x,base_y+4,at.y)))
			assert(not soffit.is_empty() and absf(soffit.position.y-base_y-3.3)<0.025,"Annex overhang is not closed")
		for degrees in [90.0,110.0,140.0]:
			var radians := deg_to_rad(degrees)
			var direction := axis*cos(radians)+out*sin(radians)
			var start: Vector2 = annex_center+direction*8.0
			var finish: Vector2 = annex_center+direction*6.8
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(start.x,base_y+1.7,start.y),Vector3(finish.x,base_y+1.7,finish.y)))
			assert(not hit.is_empty() and absf(Vector2(hit.position.x,hit.position.z).distance_to(annex_center)-7.3)<0.025,"Annex lower wall is open")
		print("COMPREHENSIVE ANNEX PASS: server=",server," roofs, overhang underside and lower wall")
		# The shallow canopy has a solid thin roof and open space below it.
		for station in [-7.0,0.0,7.0]:
			var at: Vector2 = points[5].lerp(points[7],0.13)+axis*float(station)+out*2.6
			var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,base_y+4.2,at.y),Vector3(at.x,base_y+3.5,at.y)))
			var bottom := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,base_y+3.5,at.y),Vector3(at.x,base_y+4.2,at.y)))
			assert(not top.is_empty() and absf(top.position.y-base_y-3.84)<0.005,"Canopy top missing or too thick")
			assert(not bottom.is_empty() and absf(bottom.position.y-base_y-3.76)<0.005,"Canopy underside missing")
			var ground_y: float = terrain.elevation(at.x,at.y)+0.02
			var clearance := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,ground_y+0.05,at.y),Vector3(at.x,ground_y+2.0,at.y)))
			assert(clearance.is_empty(),"Canopy blocks standing clearance")
		print("COMPREHENSIVE CANOPY PASS: server=",server," top, underside and standing clearance")
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-270,base_y+1.7,305),Vector3(-270,base_y+1.7,290)))
		assert(not wall.is_empty(),"Exterior must remain closed")
		# Sample the saved plaza in the complete collision world, so a misplaced
		# building cannot be hidden by testing the isolated road mesh alone.
		var plaza_samples := 0
		var overlay: Dictionary = manifest.ground_overlays[0]
		assert(overlay.id == "eda-comprehensive-south-plaza")
		var outer := PackedVector2Array()
		var hole := PackedVector2Array()
		for p in overlay.outer: outer.append(Vector2(p[0],p[1]))
		for p in overlay.holes[0]: hole.append(Vector2(p[0],p[1]))
		for x in range(-330,-285,5):
			for z in range(308,346,5):
				var p := Vector2(x,z)
				if not Geometry2D.is_point_in_polygon(p,outer) or Geometry2D.is_point_in_polygon(p,hole): continue
				var y: float = terrain.elevation(p.x,p.y)+0.02
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,y+40,p.y),Vector3(p.x,y-1,p.y)))
				if hit.is_empty() or absf(hit.position.y-y)>0.03:
					push_error("Comprehensive plaza obstructed/missing: server=%s at=%s hit=%s" % [server,p,hit])
					quit(1)
					return
				plaza_samples += 1
		assert(plaza_samples==32,"Plaza sample coverage changed; review the source footprint")
		print("COMPREHENSIVE PLAZA PASS: server=",server," samples=",plaza_samples)
		# The northern loop is split across two source ways; include the short
		# closing segment and the approach, plus both sides of the road width.
		var roads: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json"))
		var north: Dictionary = manifest.ground_overlays[1]
		assert(north.id == "eda-comprehensive-north-court")
		var apron := PackedVector2Array()
		var island := PackedVector2Array()
		for p in north.outer: apron.append(Vector2(p[0],p[1]))
		for p in north.holes[0]: island.append(Vector2(p[0],p[1]))
		var loop_samples := 0
		var loop_ways := 0
		for road: Dictionary in roads.roads:
			if int(road.osm_way_id) not in [1076344134,1076344135]: continue
			loop_ways += 1
			assert(float(road.width)==6.0)
			for i in range(road.points.size()-1):
				var a := Vector2(road.points[i][0],road.points[i][1])
				var b := Vector2(road.points[i+1][0],road.points[i+1][1])
				var side := Vector2(-(b-a).y,(b-a).x).normalized()
				for fraction in [0.1,0.5,0.9]:
					for offset in [-2.5,0.0,2.5]:
						var p: Vector2 = a.lerp(b,fraction)+side*offset
						assert(not Geometry2D.is_point_in_polygon(p,island), "Road-width sample enters registered island")
						var lift := 0.02
						var y: float = terrain.elevation(p.x,p.y)+lift
						var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,y+40,p.y),Vector3(p.x,y-1,p.y)))
						if hit.is_empty() or absf(hit.position.y-y)>0.03:
							push_error("North loop obstructed/missing: server=%s at=%s hit=%s" % [server,p,hit])
							quit(1)
							return
						loop_samples += 1
		assert(loop_ways==2 and loop_samples==135,"Northern loop source coverage changed")
		print("COMPREHENSIVE NORTH LOOP PASS: server=",server," samples=",loop_samples)
		var apron_samples := 0
		for p: Vector2 in [Vector2(-321,244),Vector2(-319,255),Vector2(-311,262),Vector2(-302,233),Vector2(-294,242)]:
			assert(Geometry2D.is_point_in_polygon(p,apron) and not Geometry2D.is_point_in_polygon(p,island))
			var y: float = terrain.elevation(p.x,p.y)+0.02
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,y+40,p.y),Vector3(p.x,y-1,p.y)))
			assert(not hit.is_empty() and absf(hit.position.y-y)<0.03,"North apron obstructed/missing")
			apron_samples += 1
		print("COMPREHENSIVE NORTH APRON PASS: server=",server," samples=",apron_samples)
		var court_samples := 0
		for p: Vector2 in [Vector2(-303,265),Vector2(-305,270),Vector2(-310,276),Vector2(-293,278),Vector2(-281,278)]:
			var y: float = terrain.elevation(p.x,p.y)+0.02
			# Test the walking surface below overhead shelter, retaining full
			# standing clearance instead of accepting an obstructed floor.
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,y+2.05,p.y),Vector3(p.x,y-1,p.y)))
			if hit.is_empty() or absf(hit.position.y-y)>0.03:
				push_error("North court missing/obstructed: server=%s at=%s hit=%s" % [server,p,hit])
				quit(1)
				return
			court_samples += 1
		print("COMPREHENSIVE NORTH COURT PASS: server=",server," samples=",court_samples)
		var movement = preload("res://scripts/shared/movement.gd")
		var body := CharacterBody3D.new()
		movement.setup(body)
		world.add_child(body)
		for reverse in [false,true]:
			var start_z := 278.0 if reverse else 259.0
			var spawn := Vector3(-305,terrain.elevation(-305,start_z)+0.5,start_z)
			body.position = spawn
			body.velocity = Vector3.ZERO
			for frame in 45:
				await physics_frame
				movement.step(body,Vector2.ZERO,false,false,1.0/60.0,spawn)
			assert(body.is_on_floor())
			for frame in 180:
				await physics_frame
				movement.step(body,Vector2(0,-1 if reverse else 1),false,false,1.0/60.0,spawn)
				assert(body.is_on_floor(),"Lost floor at north loop/court join")
			assert(absf(body.position.z-start_z)>17.5,"North court approach blocked")
		print("COMPREHENSIVE COURT WALK PASS: server=",server," both directions")
		# Walk across both new apron/OSM-road seams using the production capsule.
		for seam: Array in [[Vector2(-319,222),Vector2(0,1)],[Vector2(-289,242.5),Vector2(1,0)]]:
			for reverse in [false,true]:
				var direction: Vector2 = seam[1] * (-1.0 if reverse else 1.0)
				var start: Vector2 = seam[0] + (seam[1]*12.0 if reverse else Vector2.ZERO)
				var spawn := Vector3(start.x,terrain.elevation(start.x,start.y)+0.5,start.y)
				body.position = spawn
				body.velocity = Vector3.ZERO
				for frame in 45:
					await physics_frame
					movement.step(body,Vector2.ZERO,false,false,1.0/60.0,spawn)
				assert(body.is_on_floor())
				for frame in 120:
					await physics_frame
					movement.step(body,direction,false,false,1.0/60.0,spawn)
					assert(body.is_on_floor(),"Lost floor at apron/road seam")
				assert(Vector2(body.position.x,body.position.z).distance_to(start)>10.5,"Apron/road seam blocks walking")
		print("COMPREHENSIVE APRON SEAM WALK PASS: server=",server," north/east, both directions")




		world.free()
		viewport.free()
	print("PASS: client/server WGS84 comprehensive roof, lower glass projection, closed exterior, south plaza and north loop")
	quit()
