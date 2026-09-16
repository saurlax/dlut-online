extends RefCounted
## Shared, deterministic centerline ribbons for baked world meshes and UI maps.
static func polygons(roads: Array, margin := 0.0) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var junctions: Dictionary = {}
	for road in roads:
		var half_width := float(road.width) * 0.5 + margin
		for i in range(road.points.size() - 1):
			var a := Vector2(road.points[i][0], road.points[i][1])
			var b := Vector2(road.points[i + 1][0], road.points[i + 1][1])
			if a.distance_squared_to(b) < 0.000001:
				continue
			var normal := (b - a).normalized().orthogonal() * half_width
			var ring := PackedVector2Array([a + normal, b + normal, b - normal, a - normal])
			if Geometry2D.is_polygon_clockwise(ring):
				ring.reverse()
			result.append(ring)
			for point in [a, b]:
				# Four decimal places match the importer and preserve OSM shared
				# nodes. No proximity snapping across unrelated roads.
				var key := Vector2i(roundi(point.x * 10000), roundi(point.y * 10000))
				if not junctions.has(key):
					junctions[key] = PackedVector2Array()
				junctions[key].append(point + normal)
				junctions[key].append(point - normal)
	for vertices: PackedVector2Array in junctions.values():
		if vertices.size() < 4:
			continue
		var hull := Geometry2D.convex_hull(vertices)
		if hull.size() < 4:
			continue
		hull.remove_at(hull.size() - 1)
		if Geometry2D.is_polygon_clockwise(hull):
			hull.reverse()
		result.append(hull)
	return result
