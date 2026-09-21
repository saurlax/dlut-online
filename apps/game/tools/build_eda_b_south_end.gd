extends RefCounted
## Exterior south-end volumes. Dimensions are proportional estimates.
var origin: Vector2
var axis: Vector2
var out: Vector2
var length: float
var profile: Dictionary
var footprint: PackedVector2Array
var opening := PackedVector2Array()

func configure(points: PackedVector2Array, data: Dictionary) -> void:
	profile=data
	footprint=points
	origin=points[0]
	axis=(points[2]-origin).normalized()
	length=origin.distance_to(points[2])
	out=Vector2(axis.y,-axis.x)
	if Geometry2D.is_point_in_polygon(origin+axis*length/2+out,points): out=-out
	var start:=length*float(profile.start_fraction)
	for pair in [[start,1.0],[length+1,1.0],[length+1,-float(profile.depth)],[start,-float(profile.depth)]]:
		opening.append(origin+axis*float(pair[0])+out*float(pair[1]))

func point(x: float,y: float,z: float) -> Vector3:
	var p:=origin+axis*x+out*z
	return Vector3(p.x,y,p.y)

func body(facade,points: PackedVector2Array,top: float,base: float,material: Material) -> void:
	var floor_y:=float(profile.landing)
	if base<floor_y: facade.shell(points,minf(top,floor_y),base,material)
	if top>floor_y:
		var clipped:=Geometry2D.clip_polygons(points,opening)
		assert(clipped.size()==1,"B exterior arcade must leave one closed rear shell")
		facade.shell(clipped[0],top,maxf(base,floor_y),material)

func block(facade,x: float,y: float,z: float,size: Vector3,mat: Material,solid:=false) -> void:
	var node: MeshInstance3D=facade.host.box(facade.group,point(x,y,z),size,mat,"BSouthEnd")
	node.rotation.y=-atan2(axis.y,axis.x)
	node.set_meta("walk_collision",solid)

func finishes(facade,stone: Material,glass: Material,metal: Material) -> void:
	var floor_y:=float(profile.landing)
	var depth:=float(profile.depth)
	var start:=length*float(profile.start_fraction)
	var width:=float(profile.stair_width)
	var count:=int(profile.steps)
	var tread:=float(profile.tread)
	var toe:=length+0.2
	var top_x:=toe-count*tread
	var terrain:=preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	var base_y:=float(terrain.data.feature_base_y[String(facade.group.name)])
	var low:=-INF
	for z in [0.2,width/2,width]:
		var p:=point(toe,0,z)
		low=maxf(low,terrain.elevation(p.x,p.z)-base_y)
	low+=0.02
	var riser:=(floor_y-low)/count
	assert(riser>0.1 and riser<0.23,"B stair rise must agree with terrain")
	block(facade,(start+top_x)/2,floor_y-0.12,width/2,Vector3(top_x-start,0.24,width),stone,true)
	for step in count:
		var height:=low+(step+1)*riser
		block(facade,toe-(step+0.5)*tread,(height+low-0.25)/2,width/2,Vector3(tread,height-low+0.25,width),stone)
	# Separate smooth walking surface; the decorative risers cannot snag capsules.
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strip in [[point(toe,low+riser,0),point(toe,low+riser,width),point(top_x,floor_y,width),point(top_x,floor_y,0)], [point(toe+0.6,low,0),point(toe+0.6,low,width),point(toe,low+riser,width),point(toe,low+riser,0)]]:
		for ids in [[0,1,2],[0,2,3]]:
			var a:Vector3=strip[ids[0]];var b:Vector3=strip[ids[1]];var c:Vector3=strip[ids[2]]
			st.add_vertex(a)
			if (b-a).cross(c-a).y>0: st.add_vertex(c);st.add_vertex(b)
			else: st.add_vertex(b);st.add_vertex(c)
	st.generate_normals()
	st.index()
	var ramp_material:Material=facade.host.material("B south stair collision",Color.WHITE)
	var ramp:MeshInstance3D=facade.host.mesh_node(facade.group,st.commit(),ramp_material,"BSouthStairCollision")
	ramp.visible=false
	ramp.set_meta("walk_collision",true)
	var tubes:=preload("res://tools/build_eda_goals.gd").new()
	for z in [0.05,width-0.05]:
		for h in [0.45,1.05]:
			tubes.tube(facade.host,facade.group,point(toe-tread/2,low+riser+h,z),point(top_x,floor_y+h,z),0.025,metal,true)
			if z>width/2: tubes.tube(facade.host,facade.group,point(top_x,floor_y+h,z),point(start,floor_y+h,z),0.025,metal,true)
		for i in range(0,count,2):
			var x:=toe-(i+0.5)*tread
			var y:=low+(i+1)*riser
			tubes.tube(facade.host,facade.group,point(x,y,z),point(x,y+1.05,z),0.018,metal,false)
	for x in [start,top_x]:
		for z in [0.05,width-0.05]: tubes.tube(facade.host,facade.group,point(x,floor_y,z),point(x,floor_y+1.05,z),0.025,metal,true)
	# Balcony edge rail, leaving the stair arrival unobstructed.
	for ends in [[point(top_x+0.1,floor_y+1.05,0),point(length,floor_y+1.05,0)], [point(length,floor_y+1.05,0),point(length,floor_y+1.05,-depth)]]:
		tubes.tube(facade.host,facade.group,ends[0],ends[1],0.025,metal,true)
	for i in 25:
		var x:=lerpf(top_x+0.1,length,float(i)/24)
		tubes.tube(facade.host,facade.group,point(x,floor_y,0),point(x,floor_y+1.05,0),0.018,metal,false)
	for fraction in profile.column_fractions:
		var x:=length*float(fraction)
		var cylinder:=CylinderMesh.new()
		cylinder.height=9.6-floor_y
		cylinder.top_radius=float(profile.column_radius)
		cylinder.bottom_radius=float(profile.column_radius)
		cylinder.radial_segments=24
		cylinder.rings=1
		var column:MeshInstance3D=facade.host.mesh_node(facade.group,cylinder,stone,"BSouthColumn")
		column.position=point(x,(9.6+floor_y)/2,-0.45)
		column.set_meta("walk_collision",true)
	# The polygon shell supplies roof tops and walls; add the exposed soffit.
	var soffit:=SurfaceTool.new()
	soffit.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon in Geometry2D.intersect_polygons(footprint,opening):
		var indices:=Geometry2D.triangulate_polygon(polygon)
		for i in range(0,indices.size(),3):
			var vertices:Array[Vector3]=[]
			for j in 3: vertices.append(Vector3(polygon[indices[i+j]].x,9.6,polygon[indices[i+j]].y))
			if (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).y>0: vertices.reverse()
			for vertex in vertices: soffit.add_vertex(vertex)
	soffit.generate_normals()
	soffit.index()
	var ceiling:MeshInstance3D=facade.host.mesh_node(facade.group,soffit.commit(),stone,"BSouthSoffit")
	ceiling.set_meta("walk_collision",true)
	var projection:=float(profile.projection)
	block(facade,length/2,9.69,(projection-0.3)/2,Vector3(length+0.8,0.18,projection+0.3),stone,true)
	# Closed glazing at the back of the exterior arcade does not add an interior.
	var glazing_width:=length-start-1.2
	block(facade,(start+length)/2,6.55,-depth+0.05,Vector3(glazing_width,2.7,0.08),glass)
	for i in 7:
		var x:float=(start+length)/2-glazing_width/2+glazing_width*i/6
		block(facade,x,6.55,-depth+0.12,Vector3(0.06,2.8,0.12),metal)
	for y in [5.2,7.0,7.9]: block(facade,(start+length)/2,y,-depth+0.12,Vector3(glazing_width,0.06,0.12),metal)
