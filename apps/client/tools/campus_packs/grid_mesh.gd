@tool
extends RefCounted

const SIZE := 100.0

class Bucket:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var tangents := PackedFloat32Array()
	var uv2s := PackedVector2Array()
	var has_normal := false
	var has_uv := false
	var has_color := false
	var has_tangent := false
	var has_uv2 := false

	func vertex(v: Array) -> void:
		vertices.append(v[0])
		if has_normal: normals.append(v[1].normalized())
		if has_uv: uvs.append(v[2])
		if has_color: colors.append(v[3])
		if has_tangent:
			for value in [v[4].x, v[4].y, v[4].z, v[4].w]: tangents.append(value)
		if has_uv2: uv2s.append(v[5])

	func arrays() -> Array:
		var result := []
		result.resize(Mesh.ARRAY_MAX)
		result[Mesh.ARRAY_VERTEX] = vertices
		if has_normal: result[Mesh.ARRAY_NORMAL] = normals
		if has_uv: result[Mesh.ARRAY_TEX_UV] = uvs
		if has_color: result[Mesh.ARRAY_COLOR] = colors
		if has_tangent: result[Mesh.ARRAY_TANGENT] = tangents
		if has_uv2: result[Mesh.ARRAY_TEX_UV2] = uv2s
		return result

static func cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / SIZE), floori(point.z / SIZE))

static func clip_polygon(poly: Array, axis: int, boundary: float, keep_greater: bool) -> Array:
	var result: Array = []
	if poly.is_empty(): return result
	var previous: Array = poly.back()
	var previous_inside: bool = previous[0][axis] >= boundary if keep_greater else previous[0][axis] <= boundary
	for current: Array in poly:
		var inside: bool = current[0][axis] >= boundary if keep_greater else current[0][axis] <= boundary
		if inside != previous_inside:
			var t: float = (boundary - previous[0][axis]) / (current[0][axis] - previous[0][axis])
			var crossing: Array = []
			for i in previous.size(): crossing.append(previous[i].lerp(current[i], t))
			crossing[0][axis] = boundary
			result.append(crossing)
		if inside: result.append(current)
		previous = current
		previous_inside = inside
	return result

static func sample(arrays: Array, i: int, transform: Transform3D) -> Array:
	var normal := Vector3.UP
	if arrays[Mesh.ARRAY_NORMAL] != null: normal = transform.basis.inverse().transposed() * arrays[Mesh.ARRAY_NORMAL][i]
	var uv := Vector2.ZERO
	if arrays[Mesh.ARRAY_TEX_UV] != null: uv = arrays[Mesh.ARRAY_TEX_UV][i]
	var color := Color.WHITE
	if arrays[Mesh.ARRAY_COLOR] != null: color = arrays[Mesh.ARRAY_COLOR][i]
	var tangent := Vector4(1, 0, 0, 1)
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var values: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var direction := transform.basis * Vector3(values[i*4], values[i*4+1], values[i*4+2])
		tangent = Vector4(direction.x, direction.y, direction.z, values[i*4+3])
	var uv2 := Vector2.ZERO
	if arrays[Mesh.ARRAY_TEX_UV2] != null: uv2 = arrays[Mesh.ARRAY_TEX_UV2][i]
	return [transform * arrays[Mesh.ARRAY_VERTEX][i], normal, uv, color, tangent, uv2]

static func split_surface(arrays: Array, transform: Transform3D) -> Dictionary:
	var buckets := {}
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count: int = indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
	for offset in range(0, count, 3):
		var triangle: Array = []
		for j in 3:
			triangle.append(sample(arrays, indices[offset+j] if not indices.is_empty() else offset+j, transform))
		var low := cell(triangle[0][0])
		var high := low
		for v: Array in triangle:
			var c := cell(v[0])
			low = Vector2i(mini(low.x,c.x),mini(low.y,c.y))
			high = Vector2i(maxi(high.x,c.x),maxi(high.y,c.y))
		for x in range(low.x, high.x+1):
			for z in range(low.y, high.y+1):
				var polygon := triangle
				if low != high:
					polygon = clip_polygon(polygon, 0, x*SIZE, true)
					polygon = clip_polygon(polygon, 0, (x+1)*SIZE, false)
					polygon = clip_polygon(polygon, 2, z*SIZE, true)
					polygon = clip_polygon(polygon, 2, (z+1)*SIZE, false)
				var key := Vector2i(x,z)
				for j in range(1,polygon.size()-1):
					var a: Vector3 = polygon[0][0]
					var b: Vector3 = polygon[j][0]
					var c: Vector3 = polygon[j+1][0]
					if (b-a).cross(c-a).length_squared() < 1e-14: continue
					if not buckets.has(key):
						var bucket := Bucket.new()
						bucket.has_normal = arrays[Mesh.ARRAY_NORMAL] != null
						bucket.has_uv = arrays[Mesh.ARRAY_TEX_UV] != null
						bucket.has_color = arrays[Mesh.ARRAY_COLOR] != null
						bucket.has_tangent = arrays[Mesh.ARRAY_TANGENT] != null
						bucket.has_uv2 = arrays[Mesh.ARRAY_TEX_UV2] != null
						buckets[key] = bucket
					var bucket: Bucket = buckets[key]
					bucket.vertex(polygon[0])
					bucket.vertex(polygon[j])
					bucket.vertex(polygon[j+1])
	return buckets
