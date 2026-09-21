extends RefCounted
static func load_profile() -> Dictionary:
	var p:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/sports_east_entry.json"))
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var found:=false
	for feature in manifest.features:
		if str(feature.id)!=str(p.feature_id):continue
		assert(feature.osm_id==p.osm_id and int(feature.osm_version)==int(p.osm_version))
		var points:Array=feature.sports_surfaces[0].points
		assert([points[int(p.running_edge_indices[0])],points[int(p.running_edge_indices[1])]]==p.expected_running_edge,"Sports entry running edge changed")
		found=true
	assert(found)
	return p
static func point(p: Dictionary, station: float, cross: float) -> Vector2:
	var axis:=Vector2(p.outward_xz[0],p.outward_xz[1])
	return Vector2(p.origin_xz[0],p.origin_xz[1])+axis*station+Vector2(p.cross_xz[0],p.cross_xz[1])*cross
static func mask(p: Dictionary) -> PackedVector2Array:
	var half:=float(p.clear_width_m)/2+float(p.cheek_width_m)
	var end:=float(p.end_station_m)
	var result:=PackedVector2Array([point(p,0,-half),point(p,end,-half),point(p,end,half),point(p,0,half)])
	if Geometry2D.is_polygon_clockwise(result):result.reverse()
	return result
