extends RefCounted
## Gameplay basin, not bathymetry. Original elevation samples remain unchanged.
const Water = preload("res://scripts/shared/water.gd")
const Roads = preload("res://tools/build_roads.gd")

func regions(manifest: Dictionary, terrain: RefCounted, campus: String) -> Array:
	var result: Array = []
	for feature: Dictionary in manifest.features:
		if feature.kind != "water": continue
		var name := "Feature_" + str(feature.id) + ("_" + str(int(feature.part)) if feature.has("part") else "")
		var polygons: Array = feature.get("render_polygons", [feature.get("points", [])])
		for polygon: Array in polygons:
			if polygon.size() < 3: continue
			var ring := packed(polygon)
			var bounds := Rect2(ring[0], Vector2.ZERO)
			var height := 0.0
			for p in ring:
				bounds = bounds.expand(p)
				height += terrain.elevation(p.x, p.y) / ring.size()
			var holes: Array[PackedVector2Array] = []
			for hole: Array in feature.get("holes", []): holes.append(packed(hole))
			var level := float(terrain.data.feature_base_y.get(name, height)) + (0.2 if campus == "eda" else 0.05)
			result.append({"polygon":ring, "holes":holes, "bounds":bounds.grow(0.001), "level":level, "source":name})
	return result

func packed(points: Array) -> PackedVector2Array:
	var ring := PackedVector2Array()
	for p: Array in points: ring.append(Vector2(p[0], p[1]))
	if Geometry2D.is_polygon_clockwise(ring): ring.reverse()
	return ring

func terrain_triangle(st: SurfaceTool, points: PackedVector3Array, regions: Array, terrain: RefCounted) -> void:
	var ring := PackedVector2Array()
	for p in points: ring.append(Vector2(p.x, p.z))
	if Geometry2D.is_polygon_clockwise(ring): ring.reverse()
	var bounds := Rect2(ring[0], Vector2.ZERO)
	for p in ring: bounds = bounds.expand(p)
	var cuts: Array[PackedVector2Array] = []
	for region: Dictionary in regions:
		if not bounds.intersects(region.bounds): continue
		for piece in Geometry2D.intersect_polygons(ring, region.polygon):
			if Geometry2D.is_polygon_clockwise(piece): piece.reverse()
			cuts.append(piece)
			var rings: Array[PackedVector2Array] = [piece]
			for quad in Roads.new().tessellate(rings, region.holes):
				emit_quad(st, quad, region, terrain, false)
		# Preserve islands as dry ground.
		for hole: PackedVector2Array in region.holes:
			for piece in Geometry2D.intersect_polygons(ring, hole):
				var islands: Array[PackedVector2Array] = [piece]
				for quad in Roads.new().tessellate(islands): emit_quad(st, quad, {}, terrain, false)
	if cuts.is_empty():
		for p in points: st.add_vertex(p)
		return
	var rings: Array[PackedVector2Array] = [ring]
	for quad in Roads.new().tessellate(rings, cuts): emit_quad(st, quad, {}, terrain, false)

func emit_quad(st: SurfaceTool, quad: PackedVector2Array, region: Dictionary, terrain: RefCounted, surface: bool) -> void:
	for indices in [[0,2,1], [0,3,2]]:
		emit(st, quad[indices[0]], quad[indices[1]], quad[indices[2]], region, terrain, surface)

func emit(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, region: Dictionary, terrain: RefCounted, surface: bool) -> void:
	if absf((b-a).cross(c-a)) < 0.000001: return
	if not region.is_empty() and maxf(a.distance_squared_to(b), maxf(b.distance_squared_to(c), c.distance_squared_to(a))) > 4.0:
		if a.distance_squared_to(b) >= maxf(b.distance_squared_to(c), c.distance_squared_to(a)):
			emit(st,a,(a+b)*0.5,c,region,terrain,surface)
			emit(st,(a+b)*0.5,b,c,region,terrain,surface)
		elif b.distance_squared_to(c) >= c.distance_squared_to(a):
			emit(st,a,b,(b+c)*0.5,region,terrain,surface)
			emit(st,a,(b+c)*0.5,c,region,terrain,surface)
		else:
			emit(st,a,b,(c+a)*0.5,region,terrain,surface)
			emit(st,(c+a)*0.5,b,c,region,terrain,surface)
		return
	for p in [a,b,c]:
		if surface: st.set_uv(Vector2(smoothstep(0.0, 3.0, Water.shore_distance(region,p)), 0.0))
		var y: float = terrain.elevation(p.x,p.y)
		if not region.is_empty():
			y = float(region.level) if surface else lerpf(y, float(region.level)-Water.DEPTH, smoothstep(0.0, Water.SHORE_WIDTH, Water.shore_distance(region,p)))
		st.add_vertex(Vector3(p.x,y,p.y))

func replace_surfaces(model: Node3D, regions: Array, terrain: RefCounted) -> void:
	var cleared := {}
	for region: Dictionary in regions:
		var group := model.get_node(NodePath(region.source))
		if not cleared.has(region.source):
			for child in group.get_children():
				group.remove_child(child)
				child.free()
			group.position = Vector3.ZERO
			cleared[region.source] = true
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings: Array[PackedVector2Array] = [region.polygon]
		for quad in Roads.new().tessellate(rings, region.holes): emit_quad(st,quad,region,terrain,true)
		st.index()
		st.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.name = "Water"
		mesh.mesh = st.commit()
		mesh.material_override = preload("res://assets/water/campus_water.tres")
		mesh.extra_cull_margin = 0.3
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(mesh)
		mesh.owner = model
