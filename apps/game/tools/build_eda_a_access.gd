extends RefCounted
## Entrance lobby limited to the registered glazing span and western atrium.

const WIDTH := 1.6
const HEIGHT := 2.7
const HALL_HEIGHT := 3.65
const WALL_INSET := 0.2
const JOIN_OVERLAP := 0.12
var door_center := Vector2.ZERO
var door_axis := Vector2.RIGHT
var outward := Vector2.DOWN
var connector := PackedVector2Array()
var hall_outline := PackedVector2Array()
var hall_depth := 0.0
var hall_width := 0.0
var floor_outline := PackedVector2Array()
var ceiling_outline := PackedVector2Array()
var west_index := -1
var west_edge := -1
var openings: Array[PackedVector2Array] = []
var united_opening := PackedVector2Array()
var hall_opening := PackedVector2Array()
var lobby_union := PackedVector2Array()
var jambs: Array[Vector2] = []
var arrivals: Array[Vector2] = []
var lining_cuts: Array[Dictionary] = []

func rectangle(x0: float, x1: float, d0: float, d1: float) -> PackedVector2Array:
	var ring := PackedVector2Array()
	for v in [Vector2(x0,d0),Vector2(x1,d0),Vector2(x1,d1),Vector2(x0,d1)]:
		ring.append(door_center+door_axis*v.x-outward*v.y)
	if Geometry2D.is_polygon_clockwise(ring): ring.reverse()
	return ring

func union_one(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var merged := Geometry2D.merge_polygons(a,b)
	assert(merged.size()==1,"Entrance geometry must form one connected opening")
	var result: PackedVector2Array = merged[0]
	if Geometry2D.is_polygon_clockwise(result): result.reverse()
	return result

# Split a segment at all polygon crossings, then retain only the requested side.
func segment_parts(a: Vector2, b: Vector2, polygon: PackedVector2Array, inside: bool) -> Array[Vector2]:
	var fractions: Array[float] = [0.0,1.0]
	for i in polygon.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(a,b,polygon[i],polygon[(i+1)%polygon.size()])
		if hit!=null: fractions.append(clampf((Vector2(hit)-a).dot(b-a)/a.distance_squared_to(b),0,1))
	fractions.sort()
	var result: Array[Vector2] = []
	for i in fractions.size()-1:
		var lo := fractions[i]
		var hi := fractions[i+1]
		if hi-lo<0.00001: continue
		if Geometry2D.is_point_in_polygon(a.lerp(b,(lo+hi)/2),polygon)==inside:
			result.append(a.lerp(b,lo))
			result.append(a.lerp(b,hi))
	return result

func configure(points: PackedVector2Array, entry: Dictionary, atrium_openings: Dictionary) -> void:
	var edge := int(entry.edge)
	var a := points[edge]
	var b := points[(edge+1)%points.size()]
	door_axis=(b-a).normalized()
	door_center=a.lerp(b,float(entry.fraction))
	outward=Vector2(door_axis.y,-door_axis.x)
	if Geometry2D.is_point_in_polygon(door_center+outward,points): outward=-outward
	openings.clear()
	lining_cuts.clear()
	west_index=-1
	west_edge=-1
	var west_x := INF
	for ring: PackedVector2Array in atrium_openings.body:
		openings.append(ring)
		var average := Vector2.ZERO
		for p in ring: average+=p
		average/=ring.size()
		if average.x<west_x:
			west_x=average.x
			west_index=openings.size()-1
	assert(west_index>=0,"A entrance needs a registered western atrium")
	var west := openings[west_index]
	var reach := 0.0
	for point in points: reach=maxf(reach,point.distance_to(door_center)*2)
	hall_depth=INF
	for i in west.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(door_center,door_center-outward*reach,west[i],west[(i+1)%west.size()])
		if hit!=null:
			var depth := door_center.distance_to(hit)
			if depth<hall_depth:
				hall_depth=depth
				west_edge=i
	assert(west_edge>=0,"Entrance inward axis must intersect the western atrium")
	# Dimensions are proportional estimates tied to the existing three glazing banks.
	hall_width=2.0*float(entry.bay_pitch)+float(entry.bay_width)
	hall_outline=rectangle(-hall_width/2,hall_width/2,WALL_INSET,hall_depth+JOIN_OVERLAP)
	connector=rectangle(-WIDTH/2,WIDTH/2,-.2,WALL_INSET+JOIN_OVERLAP)
	lobby_union=union_one(hall_outline,connector)
	hall_opening=union_one(west,hall_outline)
	united_opening=union_one(hall_opening,connector)
	var floor_parts := Geometry2D.clip_polygons(lobby_union,west)
	var ceiling_parts := Geometry2D.clip_polygons(hall_outline,west)
	assert(floor_parts.size()==1 and ceiling_parts.size()==1,"Lobby finishes must remain bounded and connected")
	floor_outline=floor_parts[0]
	ceiling_outline=ceiling_parts[0]
	jambs.clear()
	arrivals.clear()
	for side in [-1.0,1.0]:
		jambs.append(door_center+door_axis*side*WIDTH/2)
		arrivals.append(door_center+door_axis*side*WIDTH/2-outward*hall_depth)
	var west_center := Vector2.ZERO
	for point in west: west_center+=point
	west_center/=west.size()
	var local_axis := (west[1]-west[0]).normalized()*(-1.0 if west_index==0 else 1.0)
	var local_side := Vector2(-local_axis.y,local_axis.x)
	for i in west.size():
		var start := west[i]
		var finish := west[(i+1)%west.size()]
		var is_side := absf((finish-start).normalized().dot(local_axis))>.9
		var tangent := local_axis if is_side else local_side
		var normal := local_side if is_side else local_axis
		# The white lining lies inside the cutout: intersect its inner edge too.
		var inward := (west_center-(start+finish)/2).normalized()
		var spans := segment_parts(start,finish,hall_outline,true)
		spans.append_array(segment_parts(start+inward*.07,finish+inward*.07,hall_outline,true))
		if spans.is_empty(): continue
		var lo := INF
		var hi := -INF
		for point in spans:
			lo=minf(lo,(point-west_center).dot(tangent))
			hi=maxf(hi,(point-west_center).dot(tangent))
		lining_cuts.append({"index":west_index,"kind":"side" if is_side else "end","side":signf(((start+finish)/2-west_center).dot(normal)),"start":lo-.02,"end":hi+.02,"height":HALL_HEIGHT})

func body(facade, points: PackedVector2Array, top: float, base: float, material: Material) -> void:
	if top<=base: return
	var remaining: Array[PackedVector2Array] = []
	for i in openings.size():
		if i!=west_index: remaining.append(openings[i])
	if base<HEIGHT:
		var clipped := Geometry2D.clip_polygons(points,united_opening)
		assert(clipped.size()==1,"Door neck must leave one continuous outer shell")
		var contour: PackedVector2Array=clipped[0]
		if Geometry2D.is_polygon_clockwise(contour): contour.reverse()
		facade.shell(contour,minf(top,HEIGHT),base,material,remaining)
	if top>HEIGHT and base<HALL_HEIGHT:
		var middle: Array[PackedVector2Array] = remaining.duplicate()
		middle.append(hall_opening)
		facade.shell(points,minf(top,HALL_HEIGHT),maxf(base,HEIGHT),material,middle)
	if top>HALL_HEIGHT:
		facade.shell(points,top,maxf(base,HALL_HEIGHT),material,openings)

func lining(facade, a: Vector2, b: Vector2, height: float, wall: Material) -> void:
	if a.distance_to(b)<.005: return
	var axis := (b-a).normalized()
	var side := Vector2(axis.y,-axis.x)
	if Geometry2D.is_point_in_polygon((a+b)/2+side*.04,lobby_union): side=-side
	var center := (a+b)/2+side*.009
	var node: MeshInstance3D=facade.host.box(facade.group,Vector3(center.x,height/2,center.y),Vector3(a.distance_to(b),height,.03),wall,"AAccessWallLining")
	node.rotation.y=-atan2(axis.y,axis.x)
	node.set_meta("walk_collision",false)

func finishes(facade) -> void:
	var wall: StandardMaterial3D=facade.host.material("EDA A access lining",Color("dadbd2"))
	wall.albedo_texture=null
	wall.cull_mode=BaseMaterial3D.CULL_BACK
	var floor_material: StandardMaterial3D=facade.host.material("EDA A access floor",Color("c6c3b6"))
	floor_material.cull_mode=BaseMaterial3D.CULL_BACK
	floor_material.albedo_texture=load("res://assets/textures/buildings/mineral_render_albedo.png")
	floor_material.uv1_triplanar=true
	floor_material.uv1_world_triplanar=true
	floor_material.uv1_scale=Vector3.ONE*.8
	floor_material.roughness=.72
	horizontal(facade,floor_outline,.03,floor_material,Vector3.UP,"AAccessFloor")
	horizontal(facade,ceiling_outline,HALL_HEIGHT,wall,Vector3.DOWN,"AAccessCeiling")
	horizontal(facade,rectangle(-WIDTH/2,WIDTH/2,0,WALL_INSET),HEIGHT,wall,Vector3.DOWN,"AAccessDoorSoffit")
	for i in hall_outline.size():
		var a := hall_outline[i]
		var b := hall_outline[(i+1)%hall_outline.size()]
		# Retain the existing glazing bank interior rather than masking it with lining.
		if absf(((a+b)/2-door_center).dot(-outward)-WALL_INSET)<.001: continue
		var segments := segment_parts(a,b,openings[west_index],false)
		for j in range(0,segments.size(),2): lining(facade,segments[j],segments[j+1],HALL_HEIGHT,wall)
	for side in [-1.0,1.0]:
		var jamb: Vector2 = door_center+door_axis*side*WIDTH/2
		lining(facade,jamb,jamb-outward*WALL_INSET,HEIGHT,wall)

func horizontal(facade, polygon: PackedVector2Array, y: float, material: Material, normal: Vector3, title: String) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(polygon)
	assert(not indices.is_empty(),"A entrance surface must triangulate")
	for i in range(0,indices.size(),3):
		var triangle: Array[Vector3] = []
		for j in 3:
			var p := polygon[indices[i+j]]
			triangle.append(Vector3(p.x,y,p.y))
		if (triangle[2]-triangle[0]).cross(triangle[1]-triangle[0]).dot(normal)<0: triangle.reverse()
		for vertex in triangle:
			surface.set_normal(normal)
			surface.set_uv(Vector2(vertex.x,vertex.z))
			surface.add_vertex(vertex)
	surface.index()
	var node: MeshInstance3D=facade.host.mesh_node(facade.group,surface.commit(),material,title)
	node.set_meta("walk_collision",true)
