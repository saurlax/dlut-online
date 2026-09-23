extends RefCounted
## Offline finishes for the existing EDA meshes. No extra collision or placement.

const GROUND = preload("res://assets/campuses/eda/materials/ground.gdshader")
var surfaces: Dictionary = {}
var path_segments: Array = []

func path_uv(node: MeshInstance3D) -> void:
	if path_segments.is_empty():
		var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads
		var selections: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/mapping/road-details.json")).red_paths
		for road in roads:
			for selection in selections:
				if int(road.osm_way_id) != int(selection.osm_way_id): continue
				var distance := 0.0
				for i in range(int(selection.get("from_vertex",0)),int(selection.get("to_vertex",road.points.size()-1))):
					var a := Vector2(road.points[i][0],road.points[i][1])
					var b := Vector2(road.points[i+1][0],road.points[i+1][1])
					path_segments.append([a,b,distance,1.0 if int(road.osm_way_id)==1076344124 else 0.0])
					distance += a.distance_to(b)
	var arrays := node.mesh.surface_get_arrays(0)
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var at := node.transform * vertex
		var p := Vector2(at.x,at.z)
		var closest := INF
		var coordinates := Vector2.ZERO
		var band := 0.0
		for segment in path_segments:
			var a: Vector2 = segment[0]
			var b: Vector2 = segment[1]
			var axis := (b-a).normalized()
			var along := (p-a).dot(axis)
			var distance := p.distance_squared_to(a+axis*clampf(along,0.0,a.distance_to(b)))
			if distance < closest:
				closest = distance
				coordinates = Vector2(float(segment[2])+along,(p-a).dot(Vector2(-axis.y,axis.x)))
				band = segment[3]
		uv.append(coordinates)
		uv2.append(Vector2(band,0.0))
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	node.mesh = mesh

static func tint_glazing(node: MeshInstance3D, mat: Material, x: float, y: float) -> void:
	if not ("glazing" in mat.resource_name or "opaque glass" in mat.resource_name):
		return
	# Slight differences between panes, baked into vertices, retain one draw batch.
	var tone := 0.82 + 0.18 * fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)
	var arrays := node.mesh.surface_get_arrays(0)
	var colors := PackedColorArray()
	colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
	colors.fill(Color(tone, tone, minf(1.0,tone+0.025)))
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	node.mesh = mesh
	mat.vertex_color_use_as_albedo = true

func ground_material(key: String, color: Color, kind: int) -> ShaderMaterial:
	if surfaces.has(key): return surfaces[key]
	var mat := ShaderMaterial.new()
	mat.resource_name = key
	mat.shader = GROUND
	mat.set_shader_parameter("base_color",color)
	mat.set_shader_parameter("surface_kind",kind)
	surfaces[key] = mat
	return mat

func stone_path(mat: ShaderMaterial) -> void:
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/mapping/road-details.json")).stone_path
	var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads
	for road: Dictionary in roads:
		if int(road.osm_way_id) != int(profile.osm_way_id): continue
		var points := [road.points[int(profile.vertices[0])], road.points[int(profile.vertices[1])]]
		assert(int(road.osm_version) == int(profile.osm_version) and points == profile.expected_points, "Stone path anchor changed")
		var a := Vector2(points[0][0],points[0][1])
		var b := Vector2(points[1][0],points[1][1])
		var axis := (b-a).normalized()
		a += axis*float(profile.start_margin_m)
		mat.set_shader_parameter("stone_path_frame",Vector4(a.x,a.y,axis.x,axis.y))
		mat.set_shader_parameter("stone_path_extent",Vector2(a.distance_to(b),float(road.width)*0.5))
		return
	assert(false,"Missing stone path anchor")

func field_markings(feature: Dictionary) -> PackedVector4Array:
	var boundary: Array = feature.sports_lines[0].points
	assert(boundary.size() == 4)
	var corners: Array[Vector2] = []
	for p in boundary: corners.append(Vector2(p[0],p[1]))
	var segments := PackedVector4Array()
	var left := corners[0].lerp(corners[1],0.5)
	var right := corners[3].lerp(corners[2],0.5)
	segments.append(Vector4(left.x,left.y,right.x,right.y))
	var north := (corners[0]+corners[3])*0.5
	var south := (corners[1]+corners[2])*0.5
	# Approximate finish dimensions, anchored to the existing pitch end lines.
	for pair in [[0,3],[1,2]]:
		var a: Vector2 = corners[pair[0]]
		var b: Vector2 = corners[pair[1]]
		var along := (b-a).normalized()
		var inward := (south-north).normalized() * (1.0 if pair[0]==0 else -1.0)
		var end_left := (a+b)*0.5-along*9.15
		var end_right := (a+b)*0.5+along*9.15
		var inner_left := end_left+inward*5.5
		var inner_right := end_right+inward*5.5
		for ends in [[end_left,inner_left],[inner_left,inner_right],[inner_right,end_right]]:
			segments.append(Vector4(ends[0].x,ends[0].y,ends[1].x,ends[1].y))
	return segments

func apply(node: Node, feature_id := "") -> void:
	if node is Node3D and node.has_meta("blender_source"):
		return
	if node.name.begins_with("Feature_"):
		feature_id = node.name.get_slice("_",1)
	if node is MeshInstance3D and node.material_override != null:
		var key: String = node.material_override.resource_name
		if feature_id in ["77925","77927","77928"] and key.begins_with("Surface mineral ") and key.ends_with(" planar"):
			var tile_key := "EDA academic patterned tile"
			if not surfaces.has(tile_key):
				var mat := ShaderMaterial.new()
				mat.resource_name = tile_key
				mat.shader = preload("res://assets/campuses/eda/materials/academic_tile.gdshader")
				surfaces[tile_key] = mat
			node.material_override = surfaces[tile_key]
		match key:
			"Field grass":
				if not surfaces.has(key):
					var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
					for feature in manifest.features:
						if feature.id != "39327169": continue
						for surface in feature.sports_surfaces:
							if surface.surface_type != "grass": continue
							var a := Vector2(surface.points[0][0],surface.points[0][1])
							var b := Vector2(surface.points[1][0],surface.points[1][1])
							var mat := ShaderMaterial.new()
							mat.resource_name = "EDA striped field turf"
							mat.shader = preload("res://assets/campuses/eda/materials/field_turf.gdshader")
							mat.set_shader_parameter("field_origin",a)
							mat.set_shader_parameter("field_axis",(b-a).normalized())
							mat.set_shader_parameter("field_length",a.distance_to(b))
							mat.set_shader_parameter("markings",field_markings(feature))
							surfaces[key] = mat
				if surfaces.has(key): node.material_override = surfaces[key]
			"EDA gym metal roof":
				if not surfaces.has(key):
					var mat := ShaderMaterial.new()
					mat.resource_name = key
					mat.shader = preload("res://assets/campuses/eda/materials/roof_metal.gdshader")
					surfaces[key] = mat
				node.material_override = surfaces[key]
			"EDA Xueyuan bridge deck":
				if not surfaces.has(key):
					var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/structures/xueyuan_bridge.json"))
					var start := Vector2(profile.west[0],profile.west[1])
					var end := Vector2(profile.east[0],profile.east[1])
					var axis := (end-start).normalized()
					var mat := ShaderMaterial.new()
					mat.resource_name = key
					mat.shader = preload("res://assets/campuses/eda/materials/bridge_deck.gdshader")
					mat.set_shader_parameter("deck_origin",start+axis*float(profile.west_steps)*float(profile.west_tread))
					mat.set_shader_parameter("deck_axis",axis)
					surfaces[key] = mat
				node.material_override = surfaces[key]
			"Road":
				node.material_override = ground_material(key,Color("555958"),0)
				stone_path(node.material_override)
			"Map plaza paving", "Paving":
				node.material_override = ground_material("EDA Shuyun rose grid",Color("c4b3af"),9) if feature_id=="2304850" else ground_material(key,Color("b4b0a3"),1)
			"Photo red path":
				node.material_override = ground_material(key,Color("a66e62"),2)
				path_uv(node)
			"Photo path edging":
				node.material_override = ground_material(key,Color("b6936b"),3)
				path_uv(node)
	for child in node.get_children(): apply(child,feature_id)
