extends RefCounted
## Raised brick edges on the registered causeway only; dimensions are estimates.
const ROAD_GEOMETRY = preload("res://scripts/shared/road_geometry.gd")
const ROAD_BUILDER = preload("res://tools/build_roads.gd")
const TOP_LIFT := 0.10 # Existing path is terrain + 0.02 m: an estimated 0.08 m rise.
const WIDTH := 0.12
var path := PackedVector2Array()

func regions(roads: Array, manifest: Dictionary) -> Array[PackedVector2Array]:
	var selected: Dictionary = {}
	for road: Dictionary in roads:
		if int(road.osm_way_id)==1076344124:
			assert(int(road.osm_version)==2)
			selected=road.duplicate(true)
	assert(not selected.is_empty())
	selected.points=selected.points.slice(0,10)
	var vegetation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/vegetation.json"))
	var verified := false
	for zone: Dictionary in vegetation.linear_zones:
		if zone.id=="lake-causeway-willows":
			assert(selected.points==zone.expected_points,"Causeway anchor changed")
			verified=true
	assert(verified)
	path.clear()
	for p: Array in selected.points: path.append(Vector2(p[0],p[1]))
	var bounds := Rect2(path[0],Vector2.ZERO)
	for p in path: bounds=bounds.expand(p)
	bounds=bounds.grow(8.0)
	var cuts: Array[PackedVector2Array]=[]
	# All adjacent walk/carriageway ribbons cut through the curb, including the
	# unselected continuation at vertex 9. Never bridge across a road junction.
	var adjoining: Array=[]
	for road: Dictionary in roads:
		var overlaps := false
		for i in road.points.size()-1:
			var a:=Vector2(road.points[i][0],road.points[i][1])
			var b:=Vector2(road.points[i+1][0],road.points[i+1][1])
			if bounds.intersects(Rect2(a,Vector2.ZERO).expand(b),true): overlaps=true
		if overlaps:
			var ribbon: Dictionary=road.duplicate()
			ribbon.edge_width=0.002 if int(road.osm_way_id)==1076344124 else 0.05
			adjoining.append(ribbon)
	cuts.append_array(ROAD_GEOMETRY.polygons(adjoining,0.05))
	for overlay: Dictionary in manifest.get("ground_overlays",[]):
		var ring:=PackedVector2Array()
		for p: Array in overlay.outer: ring.append(Vector2(p[0],p[1]))
		if Geometry2D.is_polygon_clockwise(ring): ring.reverse()
		cuts.append(ring)
	return ROAD_BUILDER.new().tessellate(ROAD_GEOMETRY.polygons([selected],WIDTH),cuts)

func coordinate(p: Vector3, vertical: bool) -> Vector2:
	var distance := INF
	var station := 0.0
	var uv := Vector2.ZERO
	for i in path.size()-1:
		var axis: Vector2=(path[i+1]-path[i]).normalized()
		var q:=Vector2(p.x,p.z)
		var along: float=clampf((q-path[i]).dot(axis),0.0,path[i].distance_to(path[i+1]))
		var d: float=q.distance_squared_to(path[i]+axis*along)
		if d<distance:
			distance=d
			uv=Vector2(station+along,p.y if vertical else (q-path[i]).dot(Vector2(-axis.y,axis.x)))
		station+=path[i].distance_to(path[i+1])
	return uv

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, vertical: bool) -> void:
	if (c-a).cross(b-a).length_squared()<=0.00000000001: return
	var points: Array[Vector3]=[a,b,c]
	if (c-a).cross(b-a).dot(outward)<0: points.reverse()
	for p in points:
		st.set_uv(coordinate(p,vertical))
		st.add_vertex(p)

func build(host) -> void:
	var roads: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads
	var quads:=regions(roads,host.manifest)
	var mat:=preload("res://tools/eda_surface_details.gd").new().ground_material("EDA causeway raised brick edging",Color("b6936b"),3)
	var node: MeshInstance3D=ROAD_BUILDER.new().emit(host,quads,TOP_LIFT-0.08,mat)
	var terrain:=preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	terrain.fit_road(node)
	var faces:=node.mesh.get_faces()
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var boundary: Dictionary={}
	for i in range(0,faces.size(),3):
		var v: Array[Vector3]=[faces[i],faces[i+1],faces[i+2]]
		if (v[2]-v[0]).cross(v[1]-v[0]).y<0: v.reverse()
		triangle(st,v[0],v[1],v[2],Vector3.UP,false)
		for j in 3:
			var a:=v[j]
			var b:=v[(j+1)%3]
			var ka:=Vector3i(roundi(a.x*10000),roundi(a.y*10000),roundi(a.z*10000))
			var kb:=Vector3i(roundi(b.x*10000),roundi(b.y*10000),roundi(b.z*10000))
			var key:=str(ka)+"/"+str(kb) if str(ka)<str(kb) else str(kb)+"/"+str(ka)
			if boundary.has(key): boundary[key].count+=1
			else: boundary[key]={"a":a,"b":b,"count":1}
	for edge: Dictionary in boundary.values():
		if edge.count!=1: continue
		var a: Vector3=edge.a
		var b: Vector3=edge.b
		var lower_a:=a-Vector3.UP*TOP_LIFT
		var lower_b:=b-Vector3.UP*TOP_LIFT
		var outward:=Vector3.UP.cross(b-a).normalized()
		triangle(st,lower_a,b,a,outward,true)
		triangle(st,lower_a,lower_b,b,outward,true)
	st.index()
	st.generate_normals()
	node.mesh=st.commit()
	node.name="CausewayBrickCurb"
	node.set_meta("road_surface",false)
	node.set_meta("walk_collision",true)
	node.set_meta("height_is_estimated",true)
