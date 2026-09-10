extends Control

signal pressed
const DEFAULT_SCALE := 2.0 # Godot UI pixels per world metre.
const MIN_SCALE := 0.5
const MAX_SCALE := 8.0
const ZOOM_STEP := 1.2
var map_scale := DEFAULT_SCALE
var view_center := Vector2.ZERO

func constrain_view() -> void:
	var half_view := size / (2.0 * map_scale)
	for axis in 2:
		if half_view[axis]*2 >= map_bounds.size[axis]:
			view_center[axis] = map_bounds.get_center()[axis]
		else:
			view_center[axis] = clampf(view_center[axis],map_bounds.position[axis]+half_view[axis],map_bounds.end[axis]-half_view[axis])

func zoom_at(point: Vector2, multiplier: float) -> void:
	var anchor := view_center + (point-size*0.5)/map_scale
	map_scale = clampf(map_scale*multiplier,MIN_SCALE,MAX_SCALE)
	view_center = anchor - (point-size*0.5)/map_scale
	constrain_view()
	queue_redraw()

func pan_by(relative: Vector2) -> void:
	view_center -= relative/map_scale
	constrain_view()
	queue_redraw()

var campus: Node3D
var round_map := true
var elapsed := 0.0
var roads: Array = []
var map_bounds := Rect2(-90,-90,180,180)

func configure(world: Node3D, circular: bool) -> void:
	campus = world
	round_map = circular
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if circular else Control.CURSOR_ARROW
	if not campus.manifest.features.is_empty():
		roads = campus.roads
		map_bounds = Rect2(Vector2(campus.spawn_position.x,campus.spawn_position.z),Vector2.ZERO)
		for feature in campus.manifest.features:
			for point in feature.points:
				map_bounds = map_bounds.expand(Vector2(point[0],point[1]))
		for road in roads:
			for point in road.points:
				map_bounds = map_bounds.expand(Vector2(point[0],point[1]))
	view_center = map_bounds.get_center()
	constrain_view()
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 0.1:
		elapsed = 0
		queue_redraw()

func _has_point(point: Vector2) -> bool:
	return point.distance_to(size*0.5) <= size.x*0.5 if round_map else Rect2(Vector2.ZERO,size).has_point(point)

func _gui_input(event: InputEvent) -> void:
	if round_map and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit()
		accept_event()
	elif not round_map:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_at(event.position,ZOOM_STEP)
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_at(event.position,1.0/ZOOM_STEP)
				accept_event()
		elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			pan_by(event.relative)
			accept_event()

func _draw() -> void:
	if not is_instance_valid(campus) or not is_instance_valid(campus.player):
		return
	var center := size*0.5
	var radius := minf(size.x,size.y)*0.5-3
	var clip := PackedVector2Array()
	if round_map:
		for i in 64:
			clip.append(center+Vector2(cos(TAU*i/64.0),sin(TAU*i/64.0))*radius)
	else:
		clip = PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)])
	draw_colored_polygon(clip,Color("293931"))
	var player_point := Vector2(campus.player.position.x,campus.player.position.z)
	if not round_map:
		constrain_view()
	var origin := player_point if round_map else view_center
	var scale_factor := radius/100.0 if round_map else map_scale
	for road in roads:
		for i in range(road.points.size()-1):
			var a := Vector2(road.points[i][0],road.points[i][1])
			var b := Vector2(road.points[i+1][0],road.points[i+1][1])
			var normal := (b-a).normalized().orthogonal()*float(road.width)*0.5
			paint(PackedVector2Array([a+normal,b+normal,b-normal,a-normal]),origin,scale_factor,clip,Color("778177"))
	for feature in campus.manifest.features:
		if feature.kind == "reference":
			continue
		var color := Color("a8ad9e") if feature.kind=="building" else Color("51684e")
		if feature.kind=="water":
			color = Color("456e7a")
		elif feature.kind=="road" or feature.kind=="plaza" or feature.kind=="gate":
			color = Color("778177")
		for polygon_points in feature.get("render_polygons",[feature.points]):
			var poly := PackedVector2Array()
			for p in polygon_points:
				poly.append(Vector2(p[0],p[1]))
			paint(poly,origin,scale_factor,clip,color)
	if campus.manifest.features.is_empty():
		paint(PackedVector2Array([Vector2(-5,-75),Vector2(5,-75),Vector2(5,75),Vector2(-5,75)]),origin,scale_factor,clip,Color("778177"))
		paint(PackedVector2Array([Vector2(-42,-21),Vector2(-14,-21),Vector2(-14,-3),Vector2(-42,-3)]),origin,scale_factor,clip,Color("a8ad9e"))
	var marker := center+(player_point-origin)*scale_factor
	var direction := Vector2(-sin(campus.player.rotation.y),-cos(campus.player.rotation.y))
	var side := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([marker+direction*8,marker-direction*5+side*5,marker-direction*5-side*5]),Color("f0dfaa"))
	if round_map:
		draw_arc(center,radius,0,TAU,64,Color("bcc5b3"),2,true)

func paint(poly: PackedVector2Array, origin: Vector2, scale_factor: float, clip: PackedVector2Array, color: Color) -> void:
	var transformed := PackedVector2Array()
	for p in poly:
		transformed.append(size*0.5+(p-origin)*scale_factor)
	for piece in clipped_polygons(transformed,clip):
		if piece.size() >= 3:
			draw_colored_polygon(piece,color)

static func clipped_polygons(poly: PackedVector2Array, clip: PackedVector2Array) -> Array[PackedVector2Array]:
	var pieces := Geometry2D.intersect_polygons(poly,clip)
	for piece in pieces:
		if piece.size() >= 3 and Geometry2D.triangulate_polygon(piece).is_empty():
			# Clipping a concave footprint can create a ring touching itself at a vertex.
			# Clip its source triangles instead, preserving the visible area without a convex hull.
			var triangles := Geometry2D.triangulate_polygon(poly)
			var result: Array[PackedVector2Array] = []
			for i in range(0,triangles.size(),3):
				var triangle := PackedVector2Array([poly[triangles[i]],poly[triangles[i+1]],poly[triangles[i+2]]])
				for part in Geometry2D.intersect_polygons(triangle,clip):
					if part.size() >= 3 and not Geometry2D.triangulate_polygon(part).is_empty():
						result.append(part)
			return result
	return pieces
