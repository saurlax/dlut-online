extends RefCounted
## Offline polygon union; runtime only loads the saved campus meshes.
const EPS := 0.00001
const Geometry = preload("res://scripts/shared/road_geometry.gd")

func build(builder, campus: String) -> void:
	var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/%s/data/osm_roads.json" % campus)).roads
	var painted: Array = []
	var replacement_masks: Array[PackedVector2Array] = []
	var stair_edge_mask:=PackedVector2Array()
	if campus=="eda":
		var stairs=preload("res://tools/eda_stair_profile.gd")
		var stair_profile:Dictionary=stairs.load_profile()
		replacement_masks.append(stairs.mask(stair_profile))
		var sports_entry=preload("res://tools/eda_sports_entry_profile.gd")
		replacement_masks.append(sports_entry.mask(sports_entry.load_profile()))
		# This stair segment borders planted ground, not the generic road apron.
		var edge_profile:Dictionary=stair_profile.duplicate(true)
		edge_profile.width_m=float(stair_profile.width_m)+3.0
		stair_edge_mask=stairs.mask(edge_profile)
	var surface_masks: Array[PackedVector2Array] = replacement_masks.duplicate()
	for surface: Dictionary in builder.manifest.get("ground_overlays", []):
		var ring := PackedVector2Array()
		for p: Array in surface.outer: ring.append(Vector2(p[0],p[1]))
		surface_masks.append(ring)
	# Terrain fitting adds 0.08 m. Final road lift is 0.02 m, with
	# lower decorative borders; visual separation must not create a curb.
	if campus == "eda":
		var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/mapping/road-details.json"))
		var sidewalks := sidewalk_regions(roads,profile)
		var border_masks := surface_masks.duplicate()
		border_masks.append(stair_edge_mask)
		for sidewalk: Dictionary in sidewalks: border_masks.append(sidewalk.polygon)
		var split: Array = []
		for road in roads:
			for i in range(road.points.size() - 1):
				var segment: Dictionary = road.duplicate()
				segment.points = [road.points[i], road.points[i + 1]]
				for selection in profile.red_paths:
					if int(road.osm_way_id) == int(selection.osm_way_id) and i >= int(selection.get("from_vertex", 0)) and i < int(selection.get("to_vertex", road.points.size()-1)):
						segment.edge_width = float(profile.edge_width)
						painted.append(segment)
						break
				split.append(segment)
		roads = split
		emit(builder, Geometry.polygons(roads, 1.5), -0.068, builder.material("Road edge", Color("a9a69c")),border_masks)
		for sidewalk: Dictionary in sidewalks:
			var material := preload("res://tools/eda_surface_details.gd").new().ground_material("Library roadside brick",Color("a66e62"),6)
			material.set_shader_parameter("paving_origin",sidewalk.origin)
			material.set_shader_parameter("paving_axis",sidewalk.axis)
			var polygons: Array[PackedVector2Array] = [sidewalk.polygon]
			emit(builder,polygons,-0.068,material,surface_masks)
		var edging := emit(builder, Geometry.polygons(painted, profile.edge_width), -0.066, builder.material("Photo path edging", Color("d0cec2")),surface_masks)
		edging.set_meta("walk_collision", false)
	var rings := Geometry.polygons(roads)
	var colored := Geometry.polygons(painted)
	var key: String = "Road" if campus == "eda" else campus.capitalize() + " asphalt"
	var asphalt: Material = preload("res://assets/roads/asphalt.tres") if campus == "eda" else builder.material(key, Color("656966"))
	emit(builder, rings, -0.06, asphalt, colored+surface_masks)
	if not colored.is_empty():
		emit(builder, colored, -0.06, preload("res://assets/roads/red_path.tres"),surface_masks)
	for surface: Dictionary in builder.manifest.get("ground_overlays", []):
		var outer: Array[PackedVector2Array] = []
		var cutouts: Array[PackedVector2Array] = replacement_masks.duplicate()
		var ring := PackedVector2Array()
		for p: Array in surface.outer: ring.append(Vector2(p[0],p[1]))
		outer.append(ring)
		for hole: Array in surface.holes:
			var inner := PackedVector2Array()
			for p: Array in hole: inner.append(Vector2(p[0],p[1]))
			cutouts.append(inner)
		for feature: Dictionary in builder.manifest.features:
			if feature.kind != "building": continue
			var building := PackedVector2Array()
			for p: Array in feature.points: building.append(Vector2(p[0],p[1]))
			if Geometry2D.is_polygon_clockwise(building): building.reverse()
			# A 1 mm construction clearance keeps float32 terrain subdivision
			# from placing tiny paving slivers across the wall boundary.
			cutouts.append_array(Geometry2D.offset_polygon(building,0.001,Geometry2D.JOIN_MITER))
		var surface_material: Material = builder.material("Map plaza paving",Color("c1b7a1"))
		if surface.get("surface_type", "paving") == "asphalt":
			surface_material = asphalt
		# fit_road adds 0.08 m; keep reviewed thin ground surfaces walkable.
		var lift: float = float(surface.get("render_lift_m",0.02))
		assert(lift>0.0 and lift<=0.02)
		var paving := emit(builder,outer,lift-0.08,surface_material,cutouts)
		paving.set_meta("ground_surface_id",surface.id)

func build_crosswalks(builder) -> void:
	var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/crosswalks.json"))
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	var paint: Material = builder.material("EDA crosswalk paint", Color("dddcd3"))
	paint.albedo_texture = null
	paint.roughness = 0.92
	paint.cull_mode = BaseMaterial3D.CULL_BACK
	for crossing: Dictionary in profile.crosswalks:
		var road: Dictionary = {}
		var footway: Dictionary = {}
		for candidate: Dictionary in roads:
			if int(candidate.osm_way_id) == int(crossing.road_id): road = candidate
			if int(candidate.osm_way_id) == int(crossing.footway_id): footway = candidate
		assert(not road.is_empty() and not footway.is_empty(), "Missing crosswalk road anchor")
		var index := int(crossing.road_vertex)
		assert(int(road.osm_version) == int(crossing.road_version) and road.points.slice(index-1,index+2) == crossing.expected_road_points, "Crosswalk road anchor changed")
		assert(int(footway.osm_version) == int(crossing.footway_version) and footway.points[-1] == road.points[index], "Crosswalk path junction changed")
		var center := Vector2(road.points[index][0], road.points[index][1])
		var before := Vector2(road.points[index-1][0], road.points[index-1][1])
		var after := Vector2(road.points[index+1][0], road.points[index+1][1])
		var along := (after-before).normalized()
		var across := Vector2(-along.y, along.x)
		var count := int(crossing.stripe_count)
		var width := float(crossing.stripe_width_m)
		var pitch := float(crossing.stripe_pitch_m)
		var half_length := float(crossing.stripe_length_m)/2.0
		assert((count-1)*pitch+width < float(road.width), "Crosswalk exceeds carriageway")
		var stripes: Array[PackedVector2Array] = []
		for i in count:
			var at := center+across*(i-(count-1)/2.0)*pitch
			var ring := PackedVector2Array([at-along*half_length-across*width/2, at+along*half_length-across*width/2, at+along*half_length+across*width/2, at-along*half_length+across*width/2])
			if Geometry2D.is_polygon_clockwise(ring): ring.reverse()
			stripes.append(ring)
		# The same terrain tessellation as asphalt keeps paint 4 mm above it.
		var node := emit(builder, stripes, -0.056, paint)
		terrain.fit_road(node)
		# Orient the clipped triangles explicitly before generating paint normals.
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var faces := node.mesh.get_faces()
		for i in range(0, faces.size(), 3):
			var order := [0,1,2] if (faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).y > 0 else [0,2,1]
			for corner in order: surface.add_vertex(faces[i+corner])
		surface.index()
		surface.generate_normals()
		node.mesh = surface.commit()
		node.set_meta("walk_collision", false)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func edge_y(edge: PackedVector2Array, x: float) -> float:
	return lerpf(edge[0].y, edge[1].y, (x - edge[0].x) / (edge[1].x - edge[0].x))

## Sweep the polygon union into non-overlapping trapezoids. Winding keeps
## islands/holes empty, unlike triangulating only a union's outer contour.
func tessellate(rings: Array[PackedVector2Array], cutouts: Array[PackedVector2Array] = []) -> Array[PackedVector2Array]:
	var edges: Array[PackedVector2Array] = []
	var cuts: Array[float] = []
	var layers: Array[int] = []
	var all_rings := rings + cutouts
	for ring_index in all_rings.size():
		var ring: PackedVector2Array = all_rings[ring_index]
		for i in ring.size():
			var a := ring[i]
			var b := ring[(i + 1) % ring.size()]
			cuts.append(a.x)
			if absf(a.x - b.x) > EPS:
				edges.append(PackedVector2Array([a, b]))
				layers.append(0 if ring_index < rings.size() else 1)
	for i in edges.size():
		for j in range(i + 1, edges.size()):
			var hit = Geometry2D.segment_intersects_segment(edges[i][0], edges[i][1], edges[j][0], edges[j][1])
			if hit != null:
				cuts.append(hit.x)
	cuts.sort()
	var result: Array[PackedVector2Array] = []
	var strips: Dictionary = {}
	for i in range(cuts.size() - 1):
		var left := cuts[i]
		var right := cuts[i + 1]
		if right - left < EPS:
			continue
		var middle := (left + right) * 0.5
		var crossings: Array = []
		for edge_index in edges.size():
			var edge := edges[edge_index]
			if middle > minf(edge[0].x, edge[1].x) and middle < maxf(edge[0].x, edge[1].x):
				crossings.append({"index": edge_index, "y": edge_y(edge, middle), "edge": edge, "delta": 1 if edge[1].x > edge[0].x else -1})
		crossings.sort_custom(func(a, b): return a.y < b.y)
		var depth := 0
		var cut_depth := 0
		var start := PackedVector2Array()
		var start_index := -1
		for crossing in crossings:
			var previous := depth > 0 and cut_depth == 0
			if layers[crossing.index] == 0:
				depth += int(crossing.delta)
			else:
				cut_depth += int(crossing.delta)
			var inside := depth > 0 and cut_depth == 0
			if not previous and inside:
				start = crossing.edge
				start_index = crossing.index
			elif previous and not inside:
				var finish: PackedVector2Array = crossing.edge
				var key := Vector2i(start_index, crossing.index)
				if strips.has(key) and absf(result[strips[key]][1].x - left) < EPS:
					result[strips[key]][1] = Vector2(right, edge_y(start, right))
					result[strips[key]][2] = Vector2(right, edge_y(finish, right))
				else:
					strips[key] = result.size()
					result.append(PackedVector2Array([Vector2(left, edge_y(start, left)), Vector2(right, edge_y(start, right)), Vector2(right, edge_y(finish, right)), Vector2(left, edge_y(finish, left))]))
	return result

func emit(builder, rings: Array[PackedVector2Array], height: float, mat: Material, cutouts: Array[PackedVector2Array] = []) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for quad in tessellate(rings, cutouts):
		for indices in [[0, 2, 1], [0, 3, 2]]:
			if absf((quad[indices[1]] - quad[indices[0]]).cross(quad[indices[2]] - quad[indices[0]])) < EPS:
				continue
			for i in indices:
				st.add_vertex(Vector3(quad[i].x, height, quad[i].y))
	st.index()
	var node: MeshInstance3D = builder.mesh_node(builder.scene, st.commit(), mat, mat.resource_name.replace(" ", "_"))
	node.set_meta("road_surface", true)
	node.set_meta("walk_collision", true)
	return node

func sidewalk_regions(roads: Array, profile: Dictionary) -> Array:
	var sidewalks: Array = []
	for selection: Dictionary in profile.get("sidewalk_segments",[]):
		for road: Dictionary in roads:
			if int(road.osm_way_id)!=int(selection.osm_way_id): continue
			var index := int(selection.from_vertex)
			assert(int(road.osm_version)==int(selection.osm_version) and road.points.slice(index,index+2)==selection.expected_points,"Sidewalk road anchor changed")
			var a := Vector2(road.points[index][0],road.points[index][1])
			var b := Vector2(road.points[index+1][0],road.points[index+1][1])
			var axis := (b-a).normalized()
			var side := Vector2(-axis.y,axis.x)*float(selection.side)
			assert(float(selection.along[0])>=0 and float(selection.along[1])<=a.distance_to(b))
			assert(float(selection.offsets[0])>float(road.width)/2 and float(selection.offsets[1])<float(road.width)/2+1.5)
			var polygon := PackedVector2Array([a+axis*float(selection.along[0])+side*float(selection.offsets[0]),a+axis*float(selection.along[1])+side*float(selection.offsets[0]),a+axis*float(selection.along[1])+side*float(selection.offsets[1]),a+axis*float(selection.along[0])+side*float(selection.offsets[1])])
			sidewalks.append({"polygon":polygon,"origin":a,"axis":axis})
	assert(sidewalks.size()==profile.get("sidewalk_segments",[]).size(),"Missing sidewalk anchor")
	return sidewalks
