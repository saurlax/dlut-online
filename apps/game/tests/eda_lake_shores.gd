extends SceneTree

const Water = preload("res://scripts/shared/water.gd")
const Terrain = preload("res://tools/build_terrain.gd")
const Collision = preload("res://scripts/shared/campus_collision.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var terrain := Terrain.new()
	terrain.load_campus("eda")
	check_refined_outlines()
	assert(absf(float(terrain.shores.water_levels.Feature_39328846)-float(terrain.shores.water_levels.Feature_2304775)-1.0)<.0001,"Small lake must be exactly one metre below the large lake")
	# Local grading must not perturb remote parts of the campus.
	assert(is_equal_approx(terrain.elevation(200,400),terrain.raw_elevation(200,400)))
	for server: bool in [false,true]:
		var world: Node3D
		if server:
			world = load("res://scenes/server/eda.scn").instantiate()
		else:
			world = load("res://scenes/campuses/eda.tscn").instantiate()
			world.set_script(null)
			var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
			Collision.build(world,world.get_node("CampusModel"),manifest,"eda")
			world.set_meta("water_regions",world.get_node("Terrain").get_meta("water_regions"))
			check_roads(world.get_node("CampusModel"),terrain)
			check_normals(world.get_node("Terrain/Ground"))
			for region: Dictionary in world.get_meta("water_regions"):
				for mesh in world.get_node("CampusModel").get_node(NodePath(region.source)).get_children():
					if mesh is MeshInstance3D: check_normals(mesh)
		root.add_child(world)
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		var count := 0
		for region: Dictionary in world.get_meta("water_regions"):
			var ring: PackedVector2Array = region.polygon
			assert(is_equal_approx(float(region.level),float(terrain.shores.water_levels[region.source])))
			for i in ring.size():
				var tangent := (ring[(i+1)%ring.size()]-ring[i]).normalized()
				var outward := Vector2(tangent.y,-tangent.x)
				for fraction in [0.2,0.4,0.6,0.8]:
					var edge := ring[i].lerp(ring[(i+1)%ring.size()],fraction)
					var land := edge+outward*4.0
					if Geometry2D.is_point_in_polygon(land,ring): continue
					var bank := ray_height(space,land)
					var waterline := ray_height(space,edge)
					assert(bank > float(region.level)+0.35, "Water must be below the bank: " + str(land))
					assert(waterline < float(region.level)+0.025, "Waterline must meet the bank slope without a raised slab")
					assert(absf(waterline-terrain.elevation(edge.x,edge.y)) < 0.035, "Saved collision must follow the graded surface")
					count += 1
		assert(count >= 90)
		print("EDA SHORE PHYSICS PASS server=",server," shoreline samples=",count)
		world.free()
	print("EDA LAKE SHORES PASS")
	quit()

func ray_height(space: PhysicsDirectSpaceState3D, at: Vector2) -> float:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(at.x,80,at.y),Vector3(at.x,-20,at.y),1)
	var hit := space.intersect_ray(ray)
	assert(not hit.is_empty(), "Shoreline collision gap")
	return hit.position.y

func check_normals(mesh: MeshInstance3D) -> void:
	for normal: Vector3 in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
		assert(normal.y > 0.0, "Terrain and water must face upward, including clipped shoreline triangles")

func check_roads(model: Node3D, terrain: RefCounted) -> void:
	var checked := 0
	for mesh in model.get_children():
		if not mesh is MeshInstance3D or not mesh.get_meta("road_surface",false): continue
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for i in range(0,faces.size(),31):
			var p: Vector3 = mesh.transform*faces[i]
			var local := false
			for region: Dictionary in terrain.shores.regions:
				if region.bounds.has_point(Vector2(p.x,p.z)): local = true
			if not local: continue
			var lift: float = p.y-terrain.elevation(p.x,p.z)
			if mesh.get_meta("raised_lake_sidewalk",false):
				assert(lift>=.179 and lift<=.183,"Lake sidewalk must maintain its raised curb height")
			else:
				assert(lift >= -0.001 and lift <= 0.025, "Road must track the new terrain, not float or be buried")
			checked += 1
	assert(checked > 100)
	print("EDA SHORE ROAD FIT PASS vertices=",checked)

func check_refined_outlines() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	for feature: Dictionary in manifest.features:
		if feature.kind != "water": continue
		var original := PackedVector2Array()
		var curve := PackedVector2Array()
		for p: Array in feature.source_outline: original.append(Vector2(p[0],p[1]))
		for p: Array in feature.points: curve.append(Vector2(p[0],p[1]))
		assert(curve.size()>original.size()*8, "Lake retains coarse source chords")
		for p in original:
			var nearest := INF
			for q in curve: nearest = minf(nearest,p.distance_to(q))
			assert(nearest<0.001, "Reviewed source node displaced beyond serialization tolerance")
		var region := {"polygon":original,"holes":[]}
		for i in curve.size():
			assert(curve[i].distance_to(curve[(i+1)%curve.size()]) <= 2.001, "Shoreline tessellation too coarse")
			assert(Water.shore_distance(region,curve[i]) <= 2.001, "Shoreline escaped reviewed uncertainty corridor")
			var incoming := (curve[i]-curve[(i-1+curve.size())%curve.size()]).normalized()
			var outgoing := (curve[(i+1)%curve.size()]-curve[i]).normalized()
			assert(incoming.dot(outgoing)>0.94, "Shoreline retains a hard corner")
		var triangles := Geometry2D.triangulate_polygon(curve)
		assert(not triangles.is_empty(), "Refined outline cannot be triangulated")
		print("EDA SHORE OUTLINE PASS: ",feature.id," ",original.size()," -> ",curve.size()," bounded vertices")
