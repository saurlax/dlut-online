extends RefCounted
## Offline placement in photo-supported zones; no runtime generation.

const MESH_GENERATOR = preload("res://tools/vegetation_meshes.gd")
const CELL_SIZE := 32.0
var meshes: Dictionary = {}
var terrain: RefCounted
var excluded: Array[Dictionary] = []
var roads: Array = []
var rng := RandomNumberGenerator.new()

func build(_builder: SceneTree = null, campus := "eda") -> void:
	var directory := "res://assets/campuses/%s/" % campus
	var source_path := ProjectSettings.globalize_path("res://../../references/%s/vegetation/planting.json" % campus)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory + "data/campus.json"))
	terrain = null
	if FileAccess.file_exists(directory + "data/terrain.json"):
		terrain = preload("res://tools/build_terrain.gd").new()
		terrain.load_campus(campus)
	excluded.clear()
	roads.clear()
	for feature: Dictionary in manifest.features:
		if feature.kind in ["building", "water", "road", "plaza", "gate", "sports", "track", "basketball", "tennis"]:
			for polygon: Array in feature.get("render_polygons", [feature.points]):
				var points := polygon_points(polygon)
				excluded.append({"points": points, "bounds": polygon_bounds(points).grow(5.0), "id": feature.id})
	roads = JSON.parse_string(FileAccess.get_file_as_string(directory + "data/osm_roads.json")).roads
	var instances: Array[Dictionary] = []
	var lawns := SurfaceTool.new()
	lawns.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lawn_vertices := 0
	for zone: Dictionary in source.zones:
		rng.seed = int(zone.seed)
		var points := polygon_points(zone.polygon)
		if manifest.has("legacy_reference_transform"):
			var registration: Dictionary = manifest.legacy_reference_transform
			for i in points.size():
				points[i] = Vector2(points[i].x*float(registration.scale_x)+float(registration.offset_xz[0]),points[i].y+float(registration.offset_xz[1]))
		var bounds := polygon_bounds(points)
		for plant: Dictionary in zone.plants:
			var spacing := float(plant.spacing)
			var z := bounds.position.y + spacing*0.5
			while z < bounds.end.y:
				var x := bounds.position.x + spacing*0.5
				while x < bounds.end.x:
					var at := Vector2(x,z) + Vector2(rng.randf_range(-0.28,0.28),rng.randf_range(-0.28,0.28))*spacing*float(plant.get("jitter",1.0))
					if Geometry2D.is_point_in_polygon(at,points) and allowed(at,float(plant.get("clearance",2.0))):
						var height := rng.randf_range(float(plant.height[0]),float(plant.height[1]))
						instances.append({"position":[snappedf(at.x,0.001),snappedf(elevation(at),0.001),snappedf(at.y,0.001)],"kind":plant.kind,"height":snappedf(height,0.001),"width":snappedf(rng.randf_range(0.88,1.16),0.001),"rotation_y":snappedf(rng.randf()*TAU,0.001),"variant":rng.randi_range(0,MESH_GENERATOR.VARIANTS-1),"zone":zone.id})
					x += spacing
				z += spacing
		if zone.get("lawn", false):
			# Fine triangulation follows terrain instead of large floating flat quads.
			for z in range(floori(bounds.position.y),ceili(bounds.end.y)):
				for x in range(floori(bounds.position.x),ceili(bounds.end.x)):
					var corners := [Vector2(x,z),Vector2(x+1,z),Vector2(x,z+1),Vector2(x+1,z+1)]
					var valid := true
					for corner: Vector2 in corners:
						if not Geometry2D.is_point_in_polygon(corner,points) or not allowed(corner,0.5):
							valid = false
							break
					if valid:
						for index in [0,1,2,1,3,2]:
							var at: Vector2 = corners[index]
							lawns.set_uv(at*0.4)
							var edge_distance := 2.0
							for edge_index in points.size():
								edge_distance = minf(edge_distance, at.distance_to(Geometry2D.get_closest_point_to_segment(at,points[edge_index],points[(edge_index+1)%points.size()])))
							lawns.set_uv2(Vector2(clampf(edge_distance/1.25,0,1),0))
							lawns.set_color(Color("506335").lerp(Color("707347"),0.5+sin(at.x*0.4)*cos(at.y*0.31)*0.2))
							lawns.add_vertex(Vector3(at.x,elevation(at)+0.018,at.y))
						lawn_vertices += 6
	if lawn_vertices > 0:
		lawns.index()
		lawns.generate_normals()
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/vegetation/lawn.gdshader")
		lawns.set_material(mat)
		assert(ResourceSaver.save(lawns.commit(),directory+"models/vegetation_lawn.res",ResourceSaver.FLAG_COMPRESS) == OK)
	var data := {"schema_version":2,"campus":campus,"source":"references/%s/vegetation/planting.json" % campus,"precision":"Photo-supported areas; approximate positions, dimensions and counts, not surveyed trees","instances":instances}
	var file := FileAccess.open(directory+"data/vegetation.json",FileAccess.WRITE)
	assert(file != null, "Cannot write vegetation data: " + directory)
	var records: Array[String] = []
	for entry in instances:
		records.append(JSON.stringify(entry))
	data.erase("instances")
	file.store_string(JSON.stringify(data).trim_suffix("}")+',"instances":[\n'+",\n".join(records)+"\n]}\n")
	file.close()
	write_scene(directory,instances,lawn_vertices > 0)

func elevation(at: Vector2) -> float:
	return terrain.elevation(at.x,at.y) if terrain != null else 0.0

func polygon_points(values: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p: Array in values:
		points.append(Vector2(p[0],p[1]))
	return points

func polygon_bounds(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0],Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds

func allowed(at: Vector2, clearance: float) -> bool:
	for item: Dictionary in excluded:
		if not item.bounds.has_point(at):
			continue
		var points: PackedVector2Array = item.points
		if Geometry2D.is_point_in_polygon(at,points):
			return false
		for i in points.size():
			if at.distance_to(Geometry2D.get_closest_point_to_segment(at,points[i],points[(i+1)%points.size()])) < clearance:
				return false
	for road: Dictionary in roads:
		var points := polygon_points(road.points)
		for i in points.size()-1:
			if at.distance_to(Geometry2D.get_closest_point_to_segment(at,points[i],points[i+1])) < float(road.width)*0.5+clearance:
				return false
	return true

func ensure_meshes(kinds: Array) -> void:
	var generator := MESH_GENERATOR.new()
	if meshes.is_empty():
		generator.materials()
	else:
		generator.bark = load(MESH_GENERATOR.DIRECTORY+"bark.tres")
		generator.leaves = load(MESH_GENERATOR.DIRECTORY+"leaves.tres")
	for kind: String in kinds:
		for variant in MESH_GENERATOR.VARIANTS:
			for lod in 2:
				if kind == "grass" and lod == 1:
					continue
				var key := "%s_%d_%d" % [kind,variant,lod]
				if meshes.has(key):
					continue
				var mesh := generator.build(kind,variant,lod)
				var path := MESH_GENERATOR.DIRECTORY+key+".res"
				assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS) == OK)
				meshes[key] = load(path)

func write_scene(directory: String, instances: Array[Dictionary], has_lawn: bool) -> void:
	var kinds: Array[String] = []
	for entry in instances:
		if not entry.kind in kinds:
			kinds.append(entry.kind)
	kinds.sort()
	ensure_meshes(kinds)
	var buckets: Dictionary = {}
	for entry in instances:
		var at := Vector3(entry.position[0],entry.position[1],entry.position[2])
		var cell := Vector2i(floori(at.x/CELL_SIZE),floori(at.z/CELL_SIZE))
		var key := "%d_%d_%s_%d" % [cell.x,cell.y,entry.kind,int(entry.variant)]
		if not buckets.has(key):
			buckets[key] = {"cell":cell,"kind":entry.kind,"variant":int(entry.variant),"entries":[]}
		buckets[key].entries.append(entry)
	var resources: Array[String] = []
	for kind in kinds:
		for variant in MESH_GENERATOR.VARIANTS:
			for lod in 2:
				if kind == "grass" and lod == 1:
					continue
				var key := "%s_%d_%d" % [kind,variant,lod]
				resources.append('[ext_resource type="ArrayMesh" path="%s%s.res" id="%s"]' % [MESH_GENERATOR.DIRECTORY,key,key])
	var nodes: Array[String] = ['[node name="Vegetation" type="Node3D"]']
	if has_lawn:
		resources.append('[ext_resource type="ArrayMesh" path="%smodels/vegetation_lawn.res" id="Lawn"]' % directory)
		nodes.append('[node name="Lawn" type="MeshInstance3D" parent="."]\nmesh = ExtResource("Lawn")\ncast_shadow = 0')
	for bucket: Dictionary in buckets.values():
		var cell: Vector2i = bucket.cell
		var origin := Vector3(cell.x*CELL_SIZE,0,cell.y*CELL_SIZE)
		var near_key := "%s_%d_0" % [bucket.kind,bucket.variant]
		var reference_mesh: ArrayMesh = meshes[near_key]
		var far_mesh: ArrayMesh = meshes.get("%s_%d_1" % [bucket.kind,bucket.variant],reference_mesh)
		for lod in 2:
			if bucket.kind == "grass" and lod == 1:
				continue
			var mesh_key := "%s_%d_%d" % [bucket.kind,bucket.variant,lod]
			var mesh: ArrayMesh = meshes[mesh_key]
			var buffer := PackedFloat32Array()
			var bounds := AABB()
			for i in bucket.entries.size():
				var entry: Dictionary = bucket.entries[i]
				var scale_y := float(entry.height)/reference_mesh.get_aabb().end.y
				var scale_x := scale_y*float(entry.width)
				var basis := Basis(Vector3.UP,float(entry.rotation_y)).scaled(Vector3(scale_x,scale_y,scale_x))
				var at := Vector3(entry.position[0],entry.position[1],entry.position[2])-origin
				var transform := Transform3D(basis,at)
				var item_bounds: AABB = transform*reference_mesh.get_aabb().merge(far_mesh.get_aabb())
				bounds = item_bounds if i == 0 else bounds.merge(item_bounds)
				buffer.append_array(PackedFloat32Array([basis.x.x,basis.y.x,basis.z.x,at.x,basis.x.y,basis.y.y,basis.z.y,at.y,basis.x.z,basis.y.z,basis.z.z,at.z]))
			bounds = bounds.grow(0.10)
			var name := ("Cell_%d_%d_%s" % [cell.x,cell.y,mesh_key]).replace("-","n")
			resources.append('[sub_resource type="MultiMesh" id="%s"]\ntransform_format = 1\ncustom_aabb = %s\ninstance_count = %d\nmesh = ExtResource("%s")\nbuffer = %s' % [name,var_to_str(bounds),bucket.entries.size(),mesh_key,var_to_str(buffer)])
			var small: bool = bucket.kind in ["shrub","hedge","grass","violet","calibrachoa"]
			var split := 32.0 if small else 48.0
			var end := (120.0 if small else 650.0) if lod == 1 else split
			nodes.append('[node name="%s" type="MultiMeshInstance3D" parent="."]\nposition = %s\nmultimesh = SubResource("%s")\nvisibility_range_begin = %.1f\nvisibility_range_end = %.1f\ncast_shadow = %d' % [name,var_to_str(origin),name,split if lod == 1 else 0.0,end,0 if lod == 1 or small else 1])
	var file := FileAccess.open(directory+"models/vegetation.tscn",FileAccess.WRITE)
	assert(file != null, "Cannot write vegetation scene: " + directory)
	file.store_string('[gd_scene load_steps=%d format=3]\n\n' % (resources.size()+1)+"\n\n".join(resources)+"\n\n"+"\n\n".join(nodes)+"\n")
	print("VEGETATION %s: %d instances, %d spatial/species batches, %d kinds" % [directory,instances.size(),buckets.size(),kinds.size()])
