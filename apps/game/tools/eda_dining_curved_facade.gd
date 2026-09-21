extends "res://tools/build_eda_academic.gd"

# One analytic ellipse for the registered round body; the straight wing stays fixed.
var anchors := PackedVector2Array()
var stations := PackedFloat64Array()
var angles := PackedFloat64Array()
var ellipse_center := Vector2.ZERO
var ellipse_radii := Vector2.ONE
var ellipse_rotation := 0.0
var first_edge := -1
var last_edge := -1
var active_edge := -1
var chord_step := 0.45

func configure_curve(points: PackedVector2Array, settings: Dictionary) -> void:
	if settings.is_empty(): return
	anchors=points
	first_edge=int(settings.first_vertex)
	last_edge=int(settings.last_vertex)-1
	chord_step=float(settings.max_segment_m)
	var center: Array=settings.ellipse.center_xz
	var radii: Array=settings.ellipse.radii_m
	ellipse_center=Vector2(float(center[0]),float(center[1]))
	ellipse_radii=Vector2(float(radii[0]),float(radii[1]))
	ellipse_rotation=float(settings.ellipse.rotation_rad)
	angles=PackedFloat64Array(settings.ellipse.vertex_angles_rad)
	assert(angles.size()==last_edge-first_edge+2)
	stations.clear()
	stations.append(0.0)
	for i in range(1,points.size()): stations.append(stations[-1]+points[i].distance_to(points[i-1]))
	assert(curve_point(first_edge,0).distance_to(points[first_edge])<0.001)
	assert(curve_point(last_edge,1).distance_to(points[last_edge+1])<0.001)

func curve_angle(edge: int, t: float) -> float:
	var i:=edge-first_edge
	return lerpf(angles[i],angles[i+1],t)

func curve_point(edge: int, t: float) -> Vector2:
	var angle:=curve_angle(edge,t)
	return ellipse_center+Vector2(ellipse_radii.x*cos(angle),ellipse_radii.y*sin(angle)).rotated(ellipse_rotation)

func curve_tangent(edge: int, t: float) -> Vector2:
	var angle:=curve_angle(edge,t)
	var direction:=signf(angles[edge-first_edge+1]-angles[edge-first_edge])
	return (Vector2(-ellipse_radii.x*sin(angle),ellipse_radii.y*cos(angle)).rotated(ellipse_rotation)*direction).normalized()

func curve_segments(edge: int, fraction_span: float = 1.0) -> int:
	# Radius bound limits actual ellipse chords, not the old polygon chord length.
	var sweep:=absf(angles[edge-first_edge+1]-angles[edge-first_edge])*absf(fraction_span)
	return maxi(1,ceili(sweep*maxf(ellipse_radii.x,ellipse_radii.y)/chord_step))

func refined_outline(points: PackedVector2Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for edge in points.size():
		if edge<first_edge or edge>last_edge:
			result.append(points[edge])
			continue
		var count:=curve_segments(edge)
		for i in count: result.append(curve_point(edge,float(i)/count))
	return result

func shell(points: PackedVector2Array, top: float, base: float, mat: Material, openings: Array = []) -> void:
	assert(openings.is_empty(),"Dining shell has no registered openings")
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var indices:=Geometry2D.triangulate_polygon(points)
	assert(not indices.is_empty(),"Invalid refined dining outline")
	for i in range(0,indices.size(),3):
		for cap in [base,top]:
			var vertices: Array[Vector3]=[]
			for j in 3:
				var p:=points[indices[i+j]]
				vertices.append(Vector3(p.x,cap,p.y))
			var normal:=Vector3.UP if cap==top else Vector3.DOWN
			if (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).dot(normal)<0: vertices.reverse()
			for vertex in vertices:
				st.set_uv(Vector2(vertex.x,vertex.z))
				st.add_vertex(vertex)
	for i in points.size():
		var a:=points[i]
		var b:=points[(i+1)%points.size()]
		var tangent: Vector2=(b-a).normalized()
		var normal:=Vector2(tangent.y,-tangent.x)
		if Geometry2D.is_point_in_polygon((a+b)/2+normal*0.01,points): normal=-normal
		quad(st,Vector3(a.x,base,a.y),Vector3(b.x,base,b.y),Vector3(b.x,top,b.y),Vector3(a.x,top,a.y),Vector3(normal.x,0,normal.y))
	st.generate_normals()
	st.index()
	var node: MeshInstance3D=host.mesh_node(group,st.commit(),mat,"DiningCurvedShell")
	node.set_meta("walk_collision",true)

func frame_for(points: PackedVector2Array, edge: int, end_vertex := -1) -> void:
	super.frame_for(points,edge,end_vertex)
	active_edge=edge if end_vertex<0 and edge>=first_edge and edge<=last_edge else -1

func at_station(x: float, y: float, offset: float) -> Vector3:
	var t:=x/length
	var p:=curve_point(active_edge,t)
	var tangent:=curve_tangent(active_edge,t)
	var normal:=Vector2(tangent.y,-tangent.x)
	if normal.dot(out)<0: normal=-normal
	p+=normal*offset
	return Vector3(p.x,y,p.y)

func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	var vertices: Array[Vector3]=[a,b,c,a,c,d]
	if (c-a).cross(b-a).dot(outward)<0: vertices=[a,c,b,a,d,c]
	for v in vertices:
		st.set_uv(Vector2(v.x+v.z,v.y))
		st.add_vertex(v)

func panel(x: float, y: float, width: float, height: float, depth: float, offset: float, mat: Material, solid := false) -> void:
	if active_edge<0:
		super.panel(x,y,width,height,depth,offset,mat,solid)
		return
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var count:=curve_segments(active_edge,width/length)
	var previous: Array[Vector3]=[]
	for i in count+1:
		var station:=x-width/2+width*i/count
		var ring: Array[Vector3]=[
			at_station(station,y-height/2,offset-depth/2),at_station(station,y-height/2,offset+depth/2),
			at_station(station,y+height/2,offset+depth/2),at_station(station,y+height/2,offset-depth/2)]
		var center:=at_station(station,y,offset)
		if i>0:
			var prev_center:=at_station(x-width/2+width*(i-1)/count,y,offset)
			for side in 4:
				var next: int=(side+1)%4
				var outward: Vector3=(ring[side]+ring[next]+previous[side]+previous[next])/4-(center+prev_center)/2
				quad(st,previous[side],ring[side],ring[next],previous[next],outward)
		if i==0 or i==count:
			var tangent:=curve_tangent(active_edge,station/length)
			var outward:=Vector3(tangent.x,0,tangent.y)*(-1 if i==0 else 1)
			quad(st,ring[0],ring[1],ring[2],ring[3],outward)
		previous=ring
	st.generate_normals()
	st.index()
	var node: MeshInstance3D=host.mesh_node(group,st.commit(),mat,"DiningCurvedDetail")
	node.set_meta("walk_collision",solid)
	preload("res://tools/eda_surface_details.gd").tint_glazing(node,mat,x,y)
