extends RefCounted
## Offline polygon union; runtime only loads the saved campus meshes.
const EPS := 0.00001
const Geometry = preload("res://scripts/shared/road_geometry.gd")

func build(builder, campus: String) -> void:
	var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/%s/data/osm_roads.json" % campus)).roads
	var painted: Array = []
	var surface_masks: Array[PackedVector2Array] = []
	for surface: Dictionary in builder.manifest.get("ground_overlays", []):
		var ring := PackedVector2Array()
		for p: Array in surface.outer: ring.append(Vector2(p[0],p[1]))
		surface_masks.append(ring)
	if campus == "eda":
		var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/mapping/road-details.json"))
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
		emit(builder, Geometry.polygons(roads, 1.5), 0.08, builder.material("Road edge", Color("a9a69c")),surface_masks)
		var edging := emit(builder, Geometry.polygons(painted, profile.edge_width), 0.10, builder.material("Photo path edging", Color("d0cec2")),surface_masks)
		edging.set_meta("walk_collision", false)
	var rings := Geometry.polygons(roads)
	var colored := Geometry.polygons(painted)
	var key: String = "Road" if campus == "eda" else campus.capitalize() + " asphalt"
	emit(builder, rings, 0.14 if campus == "eda" else 0.04, builder.material(key, Color("555a5b") if campus == "eda" else Color("656966")), colored+surface_masks)
	if not colored.is_empty():
		emit(builder, colored, 0.14, preload("res://assets/roads/red_path.tres"),surface_masks)
	for surface: Dictionary in builder.manifest.get("ground_overlays", []):
		var outer: Array[PackedVector2Array] = []
		var cutouts: Array[PackedVector2Array] = []
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
			cutouts.append(building)
		var paving := emit(builder,outer,0.08,builder.material("Map plaza paving",Color("c1b7a1")),cutouts)
		paving.set_meta("ground_surface_id",surface.id)

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
