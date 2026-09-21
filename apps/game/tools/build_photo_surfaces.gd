extends RefCounted
## Offline, bounded overlays on existing shell triangles. Never creates collision
## or fills a gap absent from the source mesh. Registries live beside photo bases.

const Palette = preload("res://tools/build_surface_materials.gd")
var palette := Palette.new()

func build(builder, campus: String) -> bool:
	var path := ProjectSettings.globalize_path("res://../../references/%s/buildings/texture_surfaces.json" % campus)
	var entries: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).buildings
	var count := 0
	var valid := true
	for feature in builder.manifest.features:
		if feature.kind != "building" or not entries.has(feature.id):
			continue
		var entry: Dictionary = entries[feature.id]
		if entry.get("status", "") != "applied":
			continue
		var group_name: String = "Feature_" + feature.id + ("_" + str(int(feature.part)) if feature.has("part") else "")
		var group: Node3D = builder.scene.get_node(group_name)
		var points := PackedVector2Array()
		for p in feature.points:
			points.append(Vector2(p[0], p[1]))
		var profile: Dictionary = feature.get("facade", {})
		var regions: Array = entry.get("regions", []).duplicate(true)
		if feature.has("osm_id"):
			if not entry.has("osm_regions"):
				push_error("OSM photo surface registration missing: "+feature.id)
				return false
			regions = entry.osm_regions.duplicate(true)
		if entry.get("coverage", "") == "panel_rows":
			regions = panel_regions(profile, points)
		elif entry.get("coverage", "") == "registered_edges":
			for edge in profile.edges:
				regions.append({"edge": edge, "span": profile.get("edge_spans", {}).get(str(edge), [0.0, 1.0]), "bottom": 1.0, "top": float(profile.height) - 0.5})
		var source_nodes := group.get_children()
		for region in regions:
			var edge := int(region.edge)
			var p := points[edge]
			var q := points[(edge + 1) % points.size()]
			var axis := (q - p).normalized()
			var outward := Vector2(axis.y, -axis.x)
			if Geometry2D.is_point_in_polygon((p + q) * 0.5 + outward * 0.01, points):
				outward = -outward
			var finish: String = region.get("finish", entry.finish)
			var color := Color(region.get("color", entry.get("color", profile.get("color", "b0aca0"))))
			var rect := Rect2(float(region.span[0]) * p.distance_to(q), float(region.bottom), (float(region.span[1]) - float(region.span[0])) * p.distance_to(q), float(region.top) - float(region.bottom))
			var surfaces := SurfaceTool.new()
			surfaces.begin(Mesh.PRIMITIVE_TRIANGLES)
			var vertices := 0
			for child in source_nodes:
				if not child is MeshInstance3D:
					continue
				var source_name: String = child.material_override.resource_name
				var allowed: Array = entry.get("shell_materials", ["Lingshui " + str(profile.get("color", "b0aca0"))] if campus == "lingshui" else ["Panjin " + str(profile.get("color", "b0aca0"))])
				if source_name in allowed:
					vertices += clip_shell(surfaces, child, p, axis, outward, rect)
			if vertices == 0:
				push_error("Photo surface has no source wall: %s/%s edge %d" % [campus, feature.id, edge])
				valid = false
				continue
			surfaces.generate_tangents()
			surfaces.index()
			var node: MeshInstance3D = builder.mesh_node(group, surfaces.commit(), palette.material(builder, finish, color), "PhotoSurface")
			node.set_meta("surface_reference", "references/%s/buildings/texture_surfaces.json#%s" % [campus, feature.id])
			node.set_meta("walk_collision", false)
			count += 1
		# Existing cladding/trim nodes already have explicit photo coverage. Avoid
		# touching whole-shell materials, unknown back faces, windows and doors.
		for child in source_nodes:
			if not child is MeshInstance3D:
				continue
			var mat := child.material_override as StandardMaterial3D
			if mat == null:
				continue
			for prefix in entry.get("detail_finishes", {}):
				if mat.resource_name.begins_with(prefix):
					child.material_override = palette.material(builder, entry.detail_finishes[prefix], mat.albedo_color, true)
					break
	print("PHOTO SURFACES: %s, %d bounded regions" % [campus, count])
	return valid

func panel_regions(profile: Dictionary, points: PackedVector2Array) -> Array:
	var result: Array = []
	for panel in profile.get("panels", []):
		if panel.rows.is_empty():
			continue
		var edge := int(panel.edge)
		var length := points[edge].distance_to(points[(edge + 1) % points.size()])
		var first := 1.0
		var last := 0.0
		var bottom := INF
		var top := -INF
		for row in panel.rows:
			var start := float(row.get("from", 0.0))
			var finish := float(row.get("to", 1.0))
			if is_equal_approx(start, finish):
				var half := (float(row.width) * 0.5 + 0.15) / length
				start = maxf(0.0, start - half)
				finish = minf(1.0, finish + half)
			first = minf(first, start)
			last = maxf(last, finish)
			bottom = minf(bottom, float(row.bottom))
			top = maxf(top, float(row.bottom) + float(row.height))
		# Each panel is an already registered continuous photographed face.
		# Cover the envelope of its known window rows, not separate bright strips
		# around individual windows. Never extend past that horizontal/height span.
		result.append({"edge": panel.edge, "span": [first, last], "bottom": bottom, "top": top})
	return result

func clip_shell(surface: SurfaceTool, node: MeshInstance3D, origin: Vector2, axis: Vector2, outward: Vector2, rect: Rect2) -> int:
	var arrays: Array = node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var total := vertices.size() if indices.is_empty() else indices.size()
	var clip := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var normal := Vector3(outward.x, 0.0, outward.y)
	var added := 0
	for index in range(0, total, 3):
		var triangle := PackedVector2Array()
		for corner in 3:
			var vertex: Vector3 = node.transform * vertices[index + corner if indices.is_empty() else indices[index + corner]]
			var relative := Vector2(vertex.x, vertex.z) - origin
			if absf(relative.dot(outward)) > 0.002:
				break
			triangle.append(Vector2(relative.dot(axis), vertex.y))
		if triangle.size() != 3 or absf((triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])) < 0.00001:
			continue
		for piece in Geometry2D.intersect_polygons(triangle, clip):
			var order := Geometry2D.triangulate_polygon(piece)
			for item in order:
				var uv: Vector2 = piece[item]
				var position := origin + axis * uv.x + outward * 0.012
				surface.set_normal(normal)
				surface.set_uv(Vector2(uv.x, -uv.y))
				surface.add_vertex(Vector3(position.x, uv.y, position.y))
				added += 1
	return added
