extends RefCounted
## Mean water plane drives physics; short visual waves never move collision.
const DEPTH := 4.0
const SHORE_WIDTH := 6.0

static func region_at(regions: Array, point: Vector3) -> Dictionary:
	var flat := Vector2(point.x, point.z)
	for region: Dictionary in regions:
		if not region.bounds.has_point(flat): continue
		if not Geometry2D.is_point_in_polygon(flat, region.polygon): continue
		var in_hole := false
		for hole: PackedVector2Array in region.holes:
			if Geometry2D.is_point_in_polygon(flat, hole): in_hole = true
		if not in_hole: return region
	return {}

static func shore_distance(region: Dictionary, point: Vector2) -> float:
	var distance := INF
	var rings: Array = [region.polygon]
	rings.append_array(region.holes)
	for ring: PackedVector2Array in rings:
		for i in ring.size():
			distance = minf(distance, point.distance_to(Geometry2D.get_closest_point_to_segment(point, ring[i], ring[(i+1)%ring.size()])))
	return distance
