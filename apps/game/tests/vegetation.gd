extends SceneTree
## Requires a real renderer: the dummy renderer discards MultiMesh buffers.
const CAMPUS_CATALOG = preload("res://scripts/shared/campus_catalog.gd")
var failures: Array[String] = []
var shared: Dictionary = {}
var groundcover_extents: Dictionary = {}

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func verify() -> void:
	check(DisplayServer.get_name() != "headless", "Use a real renderer")
	for campus: String in CAMPUS_CATALOG.CAMPUSES:
		var entry: Dictionary = CAMPUS_CATALOG.CAMPUSES[campus]
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entry.vegetation))
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../"+data.source))
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entry.manifest))
		var zones: Dictionary = {}
		for zone: Dictionary in source.zones:
			zones[zone.id] = zone
			check(not zone.photos.is_empty(), "Missing source for "+zone.id)
			for photo: String in zone.photos:
				check(FileAccess.file_exists("res://../../references/%s/vegetation/%s" % [campus,photo]), "Missing reference "+photo)
		var registered: Dictionary = {}
		for area: Dictionary in manifest.get("vegetation_areas", []):
			registered[area.id] = area
			check(zones.has(area.id), "Registered zone missing profile")
			zones[area.id].polygon = area.points
		var unregistered: bool = registered.is_empty()
		check(data.withheld_zone_ids.size() == zones.size()-registered.size(), "Wrong withheld zone count")
		for id: String in zones:
			check((id in data.withheld_zone_ids) == not registered.has(id), "Incorrect withholding: " + id)
		if unregistered:
			check(data.instances.is_empty(), "Unregistered planting must be withheld")
		else:
			check(not data.instances.is_empty(), "Registered woodland was not generated")
		var roads: Array = JSON.parse_string(FileAccess.get_file_as_string(entry.roads)).roads
		for linear: Dictionary in data.get("linear_zones",[]):
			var path := points(linear.get("path_points",linear.expected_points))
			var offsets: Array = linear.get("offsets", [linear.get("offset", 0.0)])
			var corridor := Geometry2D.offset_polyline(path,float(offsets.max())+0.05,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
			check(corridor.size()==1,"Invalid linear planting corridor")
			var area := {"points":Array(corridor[0])}
			registered[linear.id] = area
			zones[linear.id] = {"polygon":area.points,"plants":[linear]}
			var matching := false
			if linear.has("feature_id"):
				for feature: Dictionary in manifest.features:
					if feature.id != linear.feature_id: continue
					var edge := int(linear.edge)
					var anchor := points([feature.points[edge],feature.points[int(linear.get("end_vertex",(edge+1)%feature.points.size()))]])
					var registered_edge := points(linear.expected_points)
					matching = feature.osm_id==linear.osm_id and int(feature.osm_version)==int(linear.osm_version) and anchor[0].distance_to(registered_edge[0])<0.000001 and anchor[1].distance_to(registered_edge[1])<0.000001
					if linear.get("path_direction","")=="outward":
						check(path[0].distance_to(anchor[0].lerp(anchor[1],float(linear.anchor_fraction)))<0.0001,"Entry planting origin drift")
						check(absf((path[1]-path[0]).normalized().dot((anchor[1]-anchor[0]).normalized()))<0.0001,"Entry planting axis must be perpendicular to facade")
						check(not Geometry2D.is_point_in_polygon(path[1],points(feature.points)),"Entry planting path points inside building")
				var count := 0
				for plant: Dictionary in data.instances:
					if plant.zone != linear.id: continue
					count += 1
					var at := Vector2(plant.position[0],plant.position[2])
					var axis := (path[1]-path[0]).normalized()
					var side := Vector2(-axis.y,axis.x)
					var lateral := (at-path[0]).dot(side)
					var along := (at-path[0]).dot(axis)
					var station := (along-float(linear.start_distance))/float(linear.spacing)
					check(absf(station-roundf(station))*float(linear.spacing)<0.001 and roundi(station)>=0 and roundi(station)<int(linear.station_count),"Facade planting station drift")
					var row_matches := false
					for offset in offsets:
						for sign_side in linear.sides:
							if absf(lateral-float(offset)*float(sign_side))<0.002: row_matches=true
					check(row_matches,"Facade planting crossed anchor wall")
				check(count==int(linear.station_count)*offsets.size()*linear.sides.size(),"Facade planting lost a station")
			for road: Dictionary in roads:
				if linear.has("feature_id"): break
				if int(road.osm_way_id)==int(linear.osm_way_id):
					matching = int(road.osm_version)==int(linear.osm_version) and road.points.slice(int(linear.from_vertex),int(linear.to_vertex)+1)==linear.expected_points
			check(matching,"Linear planting no longer matches its anchor")
		var expected: Dictionary = {}
		var near_seen: Dictionary = {}
		var far_seen: Dictionary = {}
		var terrain: RefCounted
		if FileAccess.file_exists("res://assets/campuses/%s/data/terrain.json" % campus):
			terrain = preload("res://tools/build_terrain.gd").new()
			terrain.load_campus(campus)
		for plant: Dictionary in data.instances:
			var at := Vector3(plant.position[0],plant.position[1],plant.position[2])
			var key := position_key(at)
			check(not expected.has(key), "Duplicate plant position "+key)
			expected[key] = plant
			check(registered.has(plant.zone), "Unregistered zone generated a plant")
			var zone: Dictionary = zones[plant.zone]
			check(Geometry2D.is_point_in_polygon(Vector2(at.x,at.z),points(zone.polygon)), "Plant outside registered zone "+key)
			var clearance := 0.0
			for profile: Dictionary in zone.plants:
				if profile.kind == plant.kind: clearance = float(profile.get("clearance", 2.0))
			if plant.kind in ["juniper","hedge"]:
				var variant := int(plant.variant)
				var mesh_key := "%s_%d" % [plant.kind,variant]
				if not groundcover_extents.has(mesh_key):
					var near_mesh: ArrayMesh = load("res://assets/campuses/eda/models/vegetation/%s_0.res" % mesh_key)
					var radius := 0.0
					for lod in 2:
						var mesh: ArrayMesh = load("res://assets/campuses/eda/models/vegetation/%s_%d.res" % [mesh_key,lod])
						for surface in mesh.get_surface_count():
							for vertex: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
								radius = maxf(radius,Vector2(vertex.x,vertex.z).length())
					groundcover_extents[mesh_key] = radius / near_mesh.get_aabb().end.y
				var extent: float = groundcover_extents[mesh_key] * float(plant.height) * float(plant.width) + 0.05
				check(extent <= clearance,"Groundcover leaves exceed reserved clearance " + key)
				if plant.zone=="information-entry-hedges":
					var center := Vector2(56.08684592832981,493.3005938496776)
					var axis := Vector2(-0.9925953599288225,0.12146790295288375)
					check(absf((Vector2(at.x,at.z)-center).dot(axis))-extent>=9.0,"Hedge leaves intrude into the 18 m entry paving")
			for road: Dictionary in roads:
				var line := points(road.points)
				for segment in range(line.size()-1):
					var nearest := Geometry2D.get_closest_point_to_segment(Vector2(at.x,at.z),line[segment],line[segment+1])
					check(Vector2(at.x,at.z).distance_to(nearest) >= float(road.width)*0.5+clearance-0.002, "Serialized plant intrudes into road clearance " + key)
			var y: float = planting_floor(terrain,at.x,at.z,campus)
			check(absf(y-at.y)<0.002, "Floating root "+key)
			for feature: Dictionary in manifest.features:
				if feature.kind not in ["building","water","road","plaza","gate","sports","track","basketball","tennis"]:
					continue
				for polygon: Array in feature.get("render_polygons",[feature.points]):
					var outline:=points(polygon)
					var feature_bounds:=Rect2(outline[0],Vector2.ZERO)
					for vertex:Vector2 in outline:feature_bounds=feature_bounds.expand(vertex)
					check(not feature_bounds.has_point(Vector2(at.x,at.z)) or not Geometry2D.is_point_in_polygon(Vector2(at.x,at.z),outline), "Plant overlaps official feature "+feature.id)
					if plant.kind == "juniper":
						var boundary := points(polygon)
						for index in boundary.size():
							var closest := Geometry2D.get_closest_point_to_segment(Vector2(at.x,at.z),boundary[index],boundary[(index+1)%boundary.size()])
							check(Vector2(at.x,at.z).distance_to(closest) >= clearance-0.002,"Groundcover crosses feature boundary " + feature.id)
		var scene: Node3D = load("res://assets/campuses/%s/models/vegetation.tscn" % campus).instantiate()
		if unregistered:
			check(scene.get_child_count() == 0, "Unregistered lawn or plant remains")
		check(scene.find_children("*","CollisionObject3D",true,false).is_empty(), "Decorative foliage must not collide")
		verify_lawn(scene,registered,zones,manifest,terrain,campus)
		var pairs: Dictionary = {}
		for batch in scene.get_children():
			if not batch is MultiMeshInstance3D:
				continue
			var multi: MultiMesh = batch.multimesh
			var mesh: ArrayMesh = multi.mesh
			var path := mesh.resource_path
			check(multi.buffer.size()==multi.instance_count*12, "Invalid serialized buffer "+path)
			var flowering_cherry: bool = campus == "eda" and mesh.get_meta("kind", "") == "cherry"
			if flowering_cherry:
				check(mesh.get_meta("flower_geometry", "") == "five notched pale petals in short-stalked clusters", "Missing cherry blossom geometry")
				check(mesh.get_surface_count() == 2, "Cherry requires separate bark and blossom surfaces")
				check(mesh.surface_get_material(1).resource_path == "res://assets/campuses/eda/materials/cherry_blossoms.tres", "Incorrect cherry blossom material")
			else:
				check(mesh.has_meta("kind") and mesh.get_meta("leaf_geometry","")=="folded non-rectangular silhouettes", "Unexpected legacy foliage mesh")
			if shared.has(path):
				check(shared[path]==mesh, "Mesh duplicated instead of shared")
			shared[path] = mesh
			var lod := int(mesh.get_meta("lod"))
			var pair_key: String = str(batch.name).left(-1)
			if pairs.has(pair_key):
				check(multi.custom_aabb.is_equal_approx(pairs[pair_key]), "Near/far bounds differ and can cause LOD gaps")
			else:
				pairs[pair_key] = multi.custom_aabb
			for i in multi.instance_count:
				var transform := multi.get_instance_transform(i)
				check((scene.transform*batch.transform*transform).basis.determinant()>0.0, "Mirrored or collapsed vegetation reverses bark winding: "+path)
				var at: Vector3 = batch.position+transform.origin
				var key := position_key(at)
				check(expected.has(key), "Unexpected serialized plant "+key)
				if not expected.has(key):
					continue
				var plant: Dictionary = expected[key]
				check(mesh.get_meta("kind")==plant.kind and int(mesh.get_meta("variant"))==int(plant.variant), "Wrong plant variant")
				check(multi.custom_aabb.grow(0.003).encloses(transform*mesh.get_aabb()), "Clipped foliage bounds")
				var seen: Dictionary = near_seen if lod==0 else far_seen
				check(not seen.has(key), "Duplicate plant at same LOD")
				seen[key] = transform
				if lod==1:
					check(near_seen.has(key) and transform.is_equal_approx(near_seen[key]), "LOD jumps position or size")
		check(near_seen.size()==expected.size(), "Missing near instances for "+campus)
		for key: String in expected:
			check(far_seen.has(key) or expected[key].kind=="grass", "Missing far tree/shrub/flower")
		print("VEGETATION CHECK ",campus,": ",near_seen.size()," roots, ",far_seen.size()," far instances, source/terrain/footprints/bounds checked")
		scene.free()
	for path: String in shared:
		var mesh: ArrayMesh = shared[path]
		if int(mesh.get_meta("lod")) != 0 or mesh.get_meta("kind")=="grass":
			continue
		var far: ArrayMesh = load(path.replace("_0.res","_1.res"))
		check(triangles(far)<triangles(mesh), "Far mesh does not reduce geometry: "+path)
	print("VEGETATION RESULT: ",failures.size()," failures, ",shared.size()," shared meshes")
	quit(0 if failures.is_empty() else 1)

func triangles(mesh: ArrayMesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		count += mesh.surface_get_array_index_len(surface)/3
	return count

func points(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in values:
		result.append(Vector2(p[0],p[1]))
	return result

func position_key(at: Vector3) -> String:
	return "%d,%d,%d" % [roundi(at.x*1000),roundi(at.y*1000),roundi(at.z*1000)]

func verify_lawn(scene: Node3D, registered: Dictionary, zones: Dictionary, manifest: Dictionary, terrain: RefCounted, campus: String) -> void:
	var areas: Array[PackedVector2Array] = []
	for id: String in registered:
		if zones[id].get("lawn",false): areas.append(points(registered[id].points))
	var lawn := scene.get_node_or_null("Lawn") as MeshInstance3D
	if areas.is_empty():
		check(lawn==null,"Unexpected lawn without a registered source")
		return
	check(lawn!=null,"Registered lawn missing from saved scene")
	if lawn==null: return
	var forbidden: Array[PackedVector2Array] = []
	for feature: Dictionary in manifest.features:
		if feature.kind in ["building","water","plaza","sports","track","basketball","tennis"]:
			for polygon: Array in feature.get("render_polygons",[feature.points]):
				forbidden.append(points(polygon))
	if campus == "eda":
		var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads
		var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/mapping/road-details.json"))
		for sidewalk: Dictionary in preload("res://tools/build_roads.gd").new().sidewalk_regions(roads,profile): forbidden.append(sidewalk.polygon)
	var faces: PackedVector3Array = lawn.mesh.get_faces()
	check(not faces.is_empty(),"Registered lawn has no saved geometry")
	for i in range(0,faces.size(),3):
		var triangle := PackedVector2Array()
		for k in 3: triangle.append(Vector2(faces[i+k].x,faces[i+k].z))
		var inside_area := false
		for area in areas:
			var outside := 0.0
			for ring in Geometry2D.clip_polygons(triangle,area): outside += polygon_area(ring)
			if outside<0.0001: inside_area = true
		if not inside_area:
			check(false,"Saved lawn triangle extends outside registered grass area")
			return
		for ring in forbidden:
			for overlap in Geometry2D.intersect_polygons(triangle,ring):
				if polygon_area(overlap)>0.0001:
					check(false,"Saved lawn covers a building or non-grass feature")
					return
		for p: Vector3 in [faces[i],faces[i+1],faces[i+2],(faces[i]+faces[i+1]+faces[i+2])/3.0]:
			if absf(p.y-planting_floor(terrain,p.x,p.z,campus)-0.018)>0.002:
				check(false,"Saved lawn floats above shared terrain triangles")
				return
	print("LAWN CHECK: ",faces.size()/3," saved triangles inside registered area, terrain fit and exclusions checked")

func polygon_area(ring: PackedVector2Array) -> float:
	var area := 0.0
	for i in ring.size(): area += (ring[i]-ring[0]).cross(ring[(i+1)%ring.size()]-ring[0])*0.5
	return absf(area)

func planting_floor(terrain:RefCounted,x:float,z:float,campus:String)->float:
	if terrain==null:return 0.0
	if campus=="eda" and x>=-125 and x<=-112 and z>=327.24 and z<=339:
		return preload("res://tools/eda_xiang_plaza_profile.gd").garden_height(terrain,Vector2(x,z))
	return terrain.elevation(x,z)
