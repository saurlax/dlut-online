extends RefCounted

# Unroll only a reviewed chain of adjacent OSM walls. Shell coordinates stay intact.
var points := PackedVector2Array()
var stations := PackedFloat64Array([0.0])
var normals := PackedVector2Array()
var origin: Vector2
var axis: Vector2
var outward: Vector2
var length := 0.0

func configure(ring: PackedVector2Array, indices: Array) -> void:
	assert(indices.size() >= 2)
	for i in indices.size():
		points.append(ring[int(indices[i])])
		if i > 0:
			var difference := absi(int(indices[i])-int(indices[i-1]))
			assert(difference == 1 or difference == ring.size()-1,"Facade chain skips OSM vertices")
			length += points[i].distance_to(points[i-1])
			stations.append(length)
	origin = points[0]
	axis = (points[-1]-origin).normalized()
	outward = Vector2(axis.y,-axis.x)
	if Geometry2D.is_point_in_polygon((origin+points[-1])/2+outward,ring): outward = -outward
	var segment_normals := PackedVector2Array()
	for i in points.size()-1:
		var tangent := (points[i+1]-points[i]).normalized()
		var normal := Vector2(tangent.y,-tangent.x)
		if normal.dot(outward)<0: normal = -normal
		segment_normals.append(normal)
	for i in points.size():
		if i==0: normals.append(segment_normals[0])
		elif i==points.size()-1: normals.append(segment_normals[-1])
		else:
			var bisector := (segment_normals[i-1]+segment_normals[i]).normalized()
			assert(bisector.dot(segment_normals[i])>0.9,"Sharp facade corner requires independent photo registration")
			normals.append(bisector/bisector.dot(segment_normals[i]))

func mapped(vertex: Vector3) -> Vector3:
	var offset := Vector2(vertex.x,vertex.z)-origin
	var distance := offset.dot(axis)
	var segment := 0
	while segment<points.size()-2 and distance>stations[segment+1]: segment += 1
	var fraction := (distance-stations[segment])/(stations[segment+1]-stations[segment])
	var position := points[segment].lerp(points[segment+1],fraction)+normals[segment].lerp(normals[segment+1],fraction)*offset.dot(outward)
	return Vector3(position.x,vertex.y,position.y)

func clip(vertices: PackedVector3Array, station: float, keep_after: bool) -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in vertices.size():
		var a := vertices[i]
		var b := vertices[(i+1)%vertices.size()]
		var da := (Vector2(a.x,a.z)-origin).dot(axis)-station
		var db := (Vector2(b.x,b.z)-origin).dot(axis)-station
		var inside_a := da>=0 if keep_after else da<=0
		var inside_b := db>=0 if keep_after else db<=0
		if inside_a: result.append(a)
		if inside_a != inside_b: result.append(a.lerp(b,da/(da-db)))
	return result

func deform(node: MeshInstance3D) -> void:
	var faces := node.mesh.get_faces()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for i in range(0,faces.size(),3):
		var parts: Array[PackedVector3Array] = [PackedVector3Array([node.transform*faces[i],node.transform*faces[i+1],node.transform*faces[i+2]])]
		for station_index in range(1,stations.size()-1):
			var split: Array[PackedVector3Array] = []
			for part in parts:
				var low := INF
				var high := -INF
				for vertex in part:
					var distance := (Vector2(vertex.x,vertex.z)-origin).dot(axis)
					low = minf(low,distance)
					high = maxf(high,distance)
				if low>=stations[station_index] or high<=stations[station_index]:
					split.append(part)
					continue
				for keep_after in [false,true]:
					var clipped := clip(part,stations[station_index],keep_after)
					if clipped.size()>=3: split.append(clipped)
			parts = split
		for part in parts:
			for j in range(1,part.size()-1):
				var a := mapped(part[0])
				var b := mapped(part[j])
				var c := mapped(part[j+1])
				if (b-a).cross(c-a).length_squared()<0.000000000001: continue
				surface.add_vertex(a)
				surface.add_vertex(b)
				surface.add_vertex(c)
	surface.generate_normals()
	surface.index()
	node.mesh = surface.commit()
	node.transform = Transform3D.IDENTITY
