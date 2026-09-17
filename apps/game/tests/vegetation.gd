extends SceneTree
## Requires a real renderer: the dummy renderer discards MultiMesh buffers.
const CAMPUS_CATALOG = preload("res://scripts/shared/campus_catalog.gd")
var failures: Array[String] = []
var shared: Dictionary = {}

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
		var unregistered: bool = source.get("coordinate_frame", "") != manifest.coordinate_frame or source.get("origin_lon_lat", []) != manifest.origin
		if unregistered:
			check(data.instances.is_empty(), "Unregistered planting must be withheld")
			check(data.withheld_zone_ids.size() == zones.size(), "Every withheld zone must be recorded")
			for id: String in zones:
				check(id in data.withheld_zone_ids, "Missing withheld zone " + id)
		var expected: Dictionary = {}
		var near_seen: Dictionary = {}
		var far_seen: Dictionary = {}
		var terrain: RefCounted
		if campus != "panjin":
			terrain = preload("res://tools/build_terrain.gd").new()
			terrain.load_campus(campus)
		for plant: Dictionary in data.instances:
			var at := Vector3(plant.position[0],plant.position[1],plant.position[2])
			var key := position_key(at)
			check(not expected.has(key), "Duplicate plant position "+key)
			expected[key] = plant
			var zone: Dictionary = zones[plant.zone]
			check(Geometry2D.is_point_in_polygon(Vector2(at.x,at.z),points(zone.polygon)), "Plant outside registered zone "+key)
			var y: float = terrain.elevation(at.x,at.z) if terrain != null else 0.0
			check(absf(y-at.y)<0.002, "Floating root "+key)
			for feature: Dictionary in manifest.features:
				if feature.kind not in ["building","water","road","plaza","gate","sports","track","basketball","tennis"]:
					continue
				for polygon: Array in feature.get("render_polygons",[feature.points]):
					check(not Geometry2D.is_point_in_polygon(Vector2(at.x,at.z),points(polygon)), "Plant overlaps official feature "+feature.id)
		var scene: Node3D = load("res://assets/campuses/%s/models/vegetation.tscn" % campus).instantiate()
		if unregistered:
			check(scene.get_child_count() == 0, "Unregistered lawn or plant remains")
		check(scene.find_children("*","CollisionObject3D",true,false).is_empty(), "Decorative foliage must not collide")
		var pairs: Dictionary = {}
		for batch in scene.get_children():
			if not batch is MultiMeshInstance3D:
				continue
			var multi: MultiMesh = batch.multimesh
			var mesh: ArrayMesh = multi.mesh
			var path := mesh.resource_path
			check(multi.buffer.size()==multi.instance_count*12, "Invalid serialized buffer "+path)
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
	for p: Array in values:
		result.append(Vector2(p[0],p[1]))
	return result

func position_key(at: Vector3) -> String:
	return "%d,%d,%d" % [roundi(at.x*1000),roundi(at.y*1000),roundi(at.z*1000)]
