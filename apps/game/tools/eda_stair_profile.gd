extends RefCounted
## One footprint shared by terrain removal, road removal and step construction.
static func load_profile() -> Dictionary:
	var p: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/academic_c_stairs.json"))
	var roads: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads
	var found:=false
	for road: Dictionary in roads:
		if int(road.osm_way_id)!=int(p.osm_way_id): continue
		assert(int(road.osm_version)==int(p.osm_version))
		assert([road.points[int(p.vertices[0])],road.points[int(p.vertices[1])]]==p.expected_points,"Stair road anchor changed")
		found=true
	assert(found)
	return p

static func point(p: Dictionary, station: float, across: float) -> Vector2:
	var a:=Vector2(p.expected_points[0][0],p.expected_points[0][1])
	var b:=Vector2(p.expected_points[1][0],p.expected_points[1][1])
	var axis: Vector2=(b-a).normalized()
	return a+axis*station+Vector2(-axis.y,axis.x)*across

static func mask(p: Dictionary) -> PackedVector2Array:
	var half:=float(p.width_m)/2.0
	var a:=float(p.station_range_m[0])
	var b:=float(p.station_range_m[1])
	var result:=PackedVector2Array([point(p,a,-half),point(p,b,-half),point(p,b,half),point(p,a,half)])
	if Geometry2D.is_polygon_clockwise(result): result.reverse()
	return result

static func outside_triangle(vertices: PackedVector3Array, polygon: PackedVector2Array) -> Array[PackedVector3Array]:
	var outline:=PackedVector2Array()
	for v in vertices: outline.append(Vector2(v.x,v.z))
	var rect:=Rect2(outline[0],Vector2.ZERO)
	for v in outline: rect=rect.expand(v)
	var bounds:=Rect2(polygon[0],Vector2.ZERO)
	for v in polygon: bounds=bounds.expand(v)
	if not rect.intersects(bounds,true): return [vertices]
	if Geometry2D.is_polygon_clockwise(outline): outline.reverse()
	var result: Array[PackedVector3Array]=[]
	var a:=Vector2(vertices[0].x,vertices[0].z)
	var b:=Vector2(vertices[1].x,vertices[1].z)
	var c:=Vector2(vertices[2].x,vertices[2].z)
	var determinant: float=(b-a).cross(c-a)
	for piece in Geometry2D.clip_polygons(outline,polygon):
		var indices:=Geometry2D.triangulate_polygon(piece)
		for i in range(0,indices.size(),3):
			var triangle:=PackedVector3Array()
			for j in 3:
				var q: Vector2=piece[indices[i+j]]
				var v: float=(q-a).cross(c-a)/determinant
				var w: float=(b-a).cross(q-a)/determinant
				triangle.append(Vector3(q.x,vertices[0].y*(1-v-w)+vertices[1].y*v+vertices[2].y*w,q.y))
			if (triangle[2]-triangle[0]).cross(triangle[1]-triangle[0]).y<0: triangle.reverse()
			if (triangle[2]-triangle[0]).cross(triangle[1]-triangle[0]).length_squared()>0.00000000001: result.append(triangle)
	return result
