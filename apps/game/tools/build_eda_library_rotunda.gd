extends RefCounted

# The registered lower outline stays fixed. All upper surfaces share one field,
# including the roof attachments, rather than moving the glass independently.
var points: PackedVector2Array
var profile: Dictionary
var vertex_offsets: PackedVector2Array
var single_sided_materials: Dictionary = {}

func configure(outline: PackedVector2Array, settings: Dictionary) -> void:
	points = outline
	profile = settings
	vertex_offsets.resize(points.size())
	for vertex in points.size():
		var weight := float(profile.get("vertex_weights", {}).get(str(vertex), 0.0))
		if is_zero_approx(weight): continue
		var previous := (vertex - 1 + points.size()) % points.size()
		var before := outward(previous)
		var after := outward(vertex)
		var bisector := (before + after).normalized()
		vertex_offsets[vertex] = bisector * (weight * float(profile.top_outset) / maxf(0.5, bisector.dot(after)))

func outward(edge: int) -> Vector2:
	var a := points[edge]
	var b := points[(edge + 1) % points.size()]
	var axis := (b - a).normalized()
	var normal := Vector2(axis.y, -axis.x)
	return -normal if Geometry2D.is_point_in_polygon((a + b) * 0.5 + normal, points) else normal

func build_fins(facade, height: float, _material: Material) -> void:
	var cladding: StandardMaterial3D = facade.builder.material("Library upper fin cladding", Color("b3b7b6"))
	cladding.albedo_texture = null
	cladding.metallic = 0.45
	cladding.roughness = 0.42
	cladding.cull_mode = BaseMaterial3D.CULL_BACK
	var seam: StandardMaterial3D = facade.builder.material("Library upper fin joints", Color("687071"))
	seam.albedo_texture = null
	seam.cull_mode = BaseMaterial3D.CULL_BACK
	for station: Dictionary in profile.get("fin_stations", []):
		var edge := int(station.edge)
		var a := points[edge]
		var b := points[(edge + 1) % points.size()]
		var axis := (b - a).normalized()
		var out := outward(edge)
		var at := a.lerp(b, float(station.fraction))
		var start := float(profile.start_y)
		var depth := float(station.depth)
		var center := at + out * (0.33 + depth * 0.5)
		var width := float(station.width)
		var upper: MeshInstance3D = facade.builder.box(facade.group, Vector3(center.x, (start + height) * 0.5, center.y), Vector3(width, height - start, depth), cladding, "LibraryUpperRadialFin")
		upper.rotation.y = -atan2(axis.y, axis.x)
		upper.set_meta("walk_collision", true)
		upper.set_meta("fin_edge", edge)
		upper.set_meta("fin_fraction", float(station.fraction))
		var joint_y := start + float(profile.get("fin_panel_height", 1.1))
		while joint_y < height - 0.1:
			for side in [-1.0, 1.0]:
				var lateral: Vector2 = axis * float(side) * (width * 0.5 + 0.004)
				facade.edge_box(at + out * 0.33 + lateral, at + out * (0.33 + depth) + lateral, joint_y, 0.014, 0.006, seam)
			var front := at + out * (0.33 + depth + 0.004)
			facade.edge_box(front - axis * width * 0.5, front + axis * width * 0.5, joint_y, 0.014, 0.006, seam)
			joint_y += float(profile.get("fin_panel_height", 1.1))
func displacement(at: Vector3) -> Vector3:
	var factor := clampf((at.y - float(profile.start_y)) / (float(profile.top_y) - float(profile.start_y)), 0.0, 1.0)
	if factor == 0.0: return Vector3.ZERO
	var flat := Vector2(at.x, at.z)
	var nearest := INF
	var shift := Vector2.ZERO
	for edge in points.size():
		var next := (edge + 1) % points.size()
		var line := points[next] - points[edge]
		var fraction := clampf((flat - points[edge]).dot(line) / line.length_squared(), 0.0, 1.0)
		var distance := flat.distance_squared_to(points[edge] + line * fraction)
		if distance < nearest:
			nearest = distance
			shift = vertex_offsets[edge].lerp(vertex_offsets[next], fraction)
	return Vector3(shift.x, 0.0, shift.y) * factor

func clipped(vertices: Array, upper: bool) -> Array:
	var result: Array = []
	var level := float(profile.start_y)
	for i in vertices.size():
		var a: Dictionary = vertices[i]
		var b: Dictionary = vertices[(i + 1) % vertices.size()]
		var inside_a: bool = a.position.y >= level if upper else a.position.y <= level
		var inside_b: bool = b.position.y >= level if upper else b.position.y <= level
		if inside_a: result.append(a)
		if inside_a != inside_b:
			var fraction: float = (level - a.position.y) / (b.position.y - a.position.y)
			result.append({"position": a.position.lerp(b.position, fraction), "uv": a.uv.lerp(b.uv, fraction), "uv2": a.uv2.lerp(b.uv2, fraction), "color": a.color.lerp(b.color, fraction)})
	return result

func midpoint(a: Dictionary, b: Dictionary) -> Dictionary:
	return {"position": (a.position + b.position) * 0.5, "uv": a.uv.lerp(b.uv, 0.5), "uv2": a.uv2.lerp(b.uv2, 0.5), "color": a.color.lerp(b.color, 0.5)}

func emit_triangle(output: SurfaceTool, triangle: Array, has_uv2: bool, has_colors: bool, depth: int = 0) -> void:
	# Height times the interpolated corner field is bilinear. Subdivide where a
	# coarse wall triangle would otherwise cut through the finer glazing grid.
	var split_edge := -1
	var maximum_error := 0.002
	# Horizontal caps stay planar: mapping their existing boundary is sufficient.
	var horizontal: bool = is_equal_approx(triangle[0].position.y, triangle[1].position.y) and is_equal_approx(triangle[0].position.y, triangle[2].position.y)
	if not horizontal:
		for edge in 3:
			var a: Vector3 = triangle[edge].position
			var b: Vector3 = triangle[(edge + 1) % 3].position
			var error := displacement((a + b) * 0.5).distance_to((displacement(a) + displacement(b)) * 0.5)
			if error > maximum_error:
				maximum_error = error
				split_edge = edge
	if split_edge >= 0 and depth < 9:
		var a: Dictionary = triangle[split_edge]
		var b: Dictionary = triangle[(split_edge + 1) % 3]
		var c: Dictionary = triangle[(split_edge + 2) % 3]
		var middle := midpoint(a, b)
		emit_triangle(output, [a, middle, c], has_uv2, has_colors, depth + 1)
		emit_triangle(output, [middle, b, c], has_uv2, has_colors, depth + 1)
		return
	for vertex: Dictionary in triangle:
		output.set_uv(vertex.uv)
		if has_uv2: output.set_uv2(vertex.uv2)
		if has_colors: output.set_color(vertex.color)
		output.add_vertex(vertex.position + displacement(vertex.position))

func deform_range(parent: Node3D, first_child: int) -> void:
	for child in parent.get_children().slice(first_child):
		if not child is MeshInstance3D: continue
		deform_mesh(child)

func deform_mesh(node: MeshInstance3D) -> void:
	var has_displacement := false
	for surface in node.mesh.get_surface_count():
		var vertices: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if displacement(node.transform * vertex).length_squared() > 0.0000001:
				has_displacement = true
				break
	if not has_displacement: return
	var rebuilt := ArrayMesh.new()
	for surface in node.mesh.get_surface_count():
		var arrays := node.mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		if indices.is_empty():
			for index in positions.size(): indices.append(index)
		var output := SurfaceTool.new()
		output.begin(Mesh.PRIMITIVE_TRIANGLES)
		output.set_smooth_group(-1)
		for index in range(0, indices.size(), 3):
			var triangle: Array = []
			var low := INF
			var high := -INF
			for corner in 3:
				var source := indices[index + corner]
				var position: Vector3 = node.transform * positions[source]
				low = minf(low, position.y)
				high = maxf(high, position.y)
				triangle.append({"position": position, "uv": uvs[source] if not uvs.is_empty() else Vector2.ZERO, "uv2": uv2s[source] if not uv2s.is_empty() else Vector2.ZERO, "color": colors[source] if not colors.is_empty() else Color.WHITE})
			if node.has_meta("facade_shell_polygon"):
				var shell_polygon: PackedVector2Array = node.get_meta("facade_shell_polygon")
				var a: Vector3 = triangle[0].position
				var b: Vector3 = triangle[1].position
				var c: Vector3 = triangle[2].position
				var normal := (c - a).cross(b - a).normalized()
				var center := (a + b + c) / 3.0
				if normal.y < -0.9 or (absf(normal.y) < 0.1 and Geometry2D.is_point_in_polygon(Vector2(center.x, center.z) + Vector2(normal.x, normal.z) * 0.01, shell_polygon)):
					triangle.reverse()
			var polygons: Array = [triangle]
			if low < float(profile.start_y) and high > float(profile.start_y):
				polygons = [clipped(triangle, false), clipped(triangle, true)]
			for polygon: Array in polygons:
				for fan in range(1, polygon.size() - 1):
					emit_triangle(output, [polygon[0], polygon[fan], polygon[fan + 1]], not uv2s.is_empty(), not colors.is_empty())
		output.generate_normals()
		if arrays[Mesh.ARRAY_TANGENT] != null and not uvs.is_empty(): output.generate_tangents()
		output.index()
		output.set_material(node.mesh.surface_get_material(surface))
		output.commit(rebuilt)
	node.mesh = rebuilt
	node.transform = Transform3D.IDENTITY
	if node.has_meta("facade_shell_polygon"): node.remove_meta("facade_shell_polygon")
	if node.material_override is StandardMaterial3D:
		var source: StandardMaterial3D = node.material_override
		var key := source.get_instance_id()
		if not single_sided_materials.has(key):
			var material: StandardMaterial3D = source.duplicate()
			material.resource_name = source.resource_name + " library envelope"
			material.cull_mode = BaseMaterial3D.CULL_BACK
			single_sided_materials[key] = material
		node.material_override = single_sided_materials[key]
	node.set_meta("upper_envelope_start", float(profile.start_y))
	node.set_meta("upper_envelope_outset", float(profile.top_outset))
