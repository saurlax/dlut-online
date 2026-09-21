extends RefCounted

# Only the upper perimeter is registered; the lower compound stays unchanged.
func path(points: PackedVector2Array, settings: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	var first := int(settings.edges[0])
	var last := int(settings.edges[-1]) + 1
	for index in range(first, last + 1):
		var corner := index % points.size()
		var radius := float(settings.corner_radii.get(str(corner), 0.0))
		var vertex := points[corner]
		if radius == 0.0:
			result.append(vertex)
			continue
		var before := (points[posmod(corner - 1, points.size())] - vertex).normalized()
		var after := (points[(corner + 1) % points.size()] - vertex).normalized()
		var angle := acos(clampf(before.dot(after), -1.0, 1.0))
		var tangent := radius / tan(angle * 0.5)
		assert(tangent < minf(vertex.distance_to(points[posmod(corner - 1, points.size())]), vertex.distance_to(points[(corner + 1) % points.size()])) * 0.4)
		var center := vertex + (before + after).normalized() * radius / sin(angle * 0.5)
		var start := vertex + before * tangent - center
		var finish := vertex + after * tangent - center
		var sweep := atan2(start.cross(finish), start.dot(finish))
		for segment in 13:
			result.append(center + start.rotated(sweep * segment / 12.0))
	return result

func inset(chain: PackedVector2Array, points: PackedVector2Array, distance: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var normals := PackedVector2Array()
	var area := 0.0
	for i in points.size(): area += points[i].cross(points[(i + 1) % points.size()])
	for i in chain.size() - 1:
		var axis := (chain[i + 1] - chain[i]).normalized()
		var normal := Vector2(-axis.y, axis.x)
		if area < 0.0: normal = -normal
		normals.append(normal)
	for i in chain.size():
		var before := normals[maxi(0, i - 1)]
		var after := normals[mini(i, normals.size() - 1)]
		var bisector := (before + after).normalized()
		result.append(chain[i] + bisector * distance / maxf(0.5, bisector.dot(after)))
	return result

func quad(output: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	var vertices: Array[Vector3] = [a, b, c, a, c, d]
	if (c - a).cross(b - a).dot(normal) < 0.0: vertices = [a, c, b, a, d, c]
	for vertex in vertices:
		output.set_uv(Vector2(vertex.x + vertex.z, vertex.y))
		output.add_vertex(vertex)

func build(builder, group: Node3D, points: PackedVector2Array, settings: Dictionary, roof_y: float) -> void:
	var chain := path(points, settings)
	var outer := inset(chain, points, 0.02)
	var inner := inset(chain, points, 0.02 + float(settings.thickness))
	var top := roof_y + float(settings.height)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(-1)
	for i in chain.size() - 1:
		var j := i + 1
		var a := Vector3(outer[i].x, roof_y, outer[i].y)
		var b := Vector3(outer[j].x, roof_y, outer[j].y)
		var c := Vector3(inner[j].x, roof_y, inner[j].y)
		var d := Vector3(inner[i].x, roof_y, inner[i].y)
		var lift := Vector3.UP * (top - roof_y)
		var inward := ((c + d) - (a + b)).normalized()
		quad(mesh, a, b, b + lift, a + lift, -inward)
		quad(mesh, d, c, c + lift, d + lift, inward)
		quad(mesh, a + lift, b + lift, c + lift, d + lift, Vector3.UP)
		quad(mesh, a, b, c, d, Vector3.DOWN)
		if i == 0: quad(mesh, a, d, d + lift, a + lift, (a - b).normalized())
		if j == chain.size() - 1: quad(mesh, b, c, c + lift, b + lift, (b - a).normalized())
	mesh.generate_normals()
	mesh.index()
	var material: StandardMaterial3D = builder.material("Seventh low podium parapet", Color("d0d1cd"))
	material.albedo_texture = null
	material.cull_mode = BaseMaterial3D.CULL_BACK
	var node: MeshInstance3D = builder.mesh_node(group, mesh.commit(), material, "LowPodiumParapet")
	node.set_meta("walk_collision", true)
