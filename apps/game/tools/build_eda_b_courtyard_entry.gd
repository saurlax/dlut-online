extends RefCounted
## B courtyard exterior entrance. Dimensions are proportional estimates.
## The original building shell stays closed; only exterior circulation is added.
var facade
var center:Vector2
var axis:Vector2
var out:Vector2
func block(x:float,y:float,z:float,size:Vector3,mat:Material,solid:=false):
	var p:=center+axis*x+out*z
	var n:MeshInstance3D=facade.host.box(facade.group,Vector3(p.x,y,p.y),size,mat,"BCourtyardDetail")
	n.rotation.y=-atan2(axis.y,axis.x)
	n.set_meta("walk_collision",solid)
	n.set_meta("b_courtyard_detail",true)
	if mat is ShaderMaterial:
		var arrays:Array=n.mesh.surface_get_arrays(0)
		var uv:=PackedVector2Array()
		var verts:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for i in verts.size():
			var v:=verts[i]
			uv.append(Vector2(v.z+z if absf(normals[i].x)>.5 else v.x+x,-v.y-y))
		arrays[Mesh.ARRAY_TEX_UV]=uv
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);n.mesh=mesh
	return n
func build(f,points:PackedVector2Array,data:Dictionary):
	var edge:=int(data.edge)
	var fraction:=float(data.fraction)
	facade=f
	center=points[edge].lerp(points[edge+1],fraction)
	axis=(points[edge+1]-points[edge]).normalized()
	out=Vector2(axis.y,-axis.x)
	if Geometry2D.is_point_in_polygon(center+out,points):out=-out
	var wall:=ShaderMaterial.new()
	wall.resource_name="EDA B courtyard brick"
	wall.shader=load("res://assets/campuses/eda/materials/academic_tile.gdshader").duplicate()
	wall.shader.code=wall.shader.code.replace("cull_disabled","cull_back")
	wall.set_shader_parameter("tile_color",Color("77766b"))
	wall.set_shader_parameter("pale_color",Color("939184"))
	var pale:Material=f.host.material("EDA B courtyard pale",Color("b5b5a6"))
	var metal:Material=f.host.material("EDA B courtyard railing",Color("929990"))
	var glass:Material=f.host.material("EDA B courtyard glazing",Color("34494c"))
	for m in [pale,metal,glass]:
		m.cull_mode=BaseMaterial3D.CULL_BACK
		m.albedo_texture=null
	glass.metallic=.35
	glass.roughness=.3
	# Closed rear facade group; no room or door opening.
	var rear_end:=minf(4.35,points[edge].distance_to(points[edge+1])*(1.0-fraction))
	block((rear_end-4.35)/2,4.0,.035,Vector3(rear_end+4.35,7.6,.05),wall)
	block(0,1.97,.14,Vector3(3.9,3.04,.12),glass)
	for x in [-1.95,-1.25,0,1.25,1.95]:block(x,1.97,.22,Vector3(.055,3.1,.1),metal)
	for y in [.45,2.5,3.49]:block(0,y,.22,Vector3(3.95,.055,.1),metal)
	for x in [-3.35,3.35]:
		block(x,2.0,.13,Vector3(1.15,2.5,.12),glass)
		for dx in [-.59,.59]:block(x+dx,2.0,.21,Vector3(.065,2.62,.1),metal)
		for y in [.73,2.2,3.27]:block(x,y,.21,Vector3(1.2,.07,.1),metal)
	block(0,6.15,.14,Vector3(7.1,2.8,.12),glass)
	for i in 9:block(-3.55+i*7.1/8,6.15,.23,Vector3(.06,2.86,.1),metal)
	for y in [4.75,6.95,7.55]:block(0,y,.23,Vector3(7.16,.06,.1),metal)
	# Front screen at 3m, three apertures; square vents in upper side bands.
	for x in [-14.3,-4.85,4.85,14.3]:block(x,4.55,3,Vector3(1.0,9.1,.38),wall,true)
	block(0,8.5,3,Vector3(8.7,1.2,.38),wall,true)
	for side in [-1,1]:
		block(side*9.575,7.025,3,Vector3(8.45,1.05,.38),wall,true)
		block(side*9.575,8.55,3,Vector3(8.45,1.1,.38),wall,true)
		var spacing:float=8.45/7
		for i in 8:
			var x:float=5.35+i*spacing
			var w:float=spacing-.38
			if i==0 or i==7:w=spacing*.5-.19
			var xx:float=x
			if i==0:xx+=w/2
			elif i==7:xx-=w/2
			block(side*xx,7.775,3,Vector3(w,.45,.38),wall,true)
	block(0,9.14,3,Vector3(29.6,.16,.48),pale,true)
	# Entry platform, upper balcony and external flights.
	block(0,.33,1.7,Vector3(8.7,.24,3.4),pale,true)
	for s in 3:block(0,.075*(s+1),3.4+(.9-.3*s)/2,Vector3(8.7,.15*(s+1),.9-.3*s),pale,true)
	block(0,4.59,1.9,Vector3(9.7,.32,3.8),pale,true)
	for side in [-1,1]:
		var toe:float=13.77
		for step in 24:
			var run:float=step*.28+(1.2 if step>=12 else 0)
			var y:float=(step+1)*4.75/24
			block(side*(toe-run-.14),y/2,1.85,Vector3(.28,y,1.85),pale,false)
		block(side*(toe-3.36-.6),2.375/2,1.85,Vector3(1.2,2.375,1.85),pale,true)
		block(side*5.1,4.59,1.85,Vector3(1.7,.32,1.85),pale,false)
		ramp(side*5.85,4.75,side*4.25,4.75,.925,2.775)
		var outline:=PackedVector2Array([Vector2(toe,.0),Vector2(toe,.12),Vector2(toe-3.36,2.495),Vector2(toe-4.56,2.495),Vector2(toe-7.92,4.87),Vector2(toe-7.92,0)])
		if side<0:
			for j in outline.size():outline[j].x=-outline[j].x
		prism(outline,2.78,3.03,wall)
		# Thin visible parapet covers the stair body; no speculative below-stair rooms.

		for step in 25:
			var run:float=step*.28+(1.2 if step>=12 else 0)
			var y:float=step*4.75/24
			block(side*(toe-run),y+.5,2.79,Vector3(.04,1,.04),metal)
		# Rail segmented alongside both straight flights, with horizontal intermediate landing.
		for flight in 2:
			var run0:float=flight*4.56
			var y0:float=flight*2.375
			var a:=Vector3(side*(toe-run0),y0+1,2.79)
			var b:=Vector3(side*(toe-run0-3.36),y0+3.375,2.79)
			rail(a,b,metal)
		rail(Vector3(side*(toe-3.36),3.375,2.79),Vector3(side*(toe-4.56),3.375,2.79),metal)
	for side in [-1,1]:
		ramp(side*13.77,4.75/24,side*10.41,2.375,.925,2.775)
		ramp(side*9.61,2.375,side*9.21,2.375+4.75/24,.925,2.775)
		ramp(side*9.21,2.375+4.75/24,side*5.85,4.75,.925,2.775)
		ramp(side*14.17,0,side*13.77,4.75/24,.925,2.775)
	# The middle and upper slabs are solid; the flights use invisible smooth collision.
	for i in 33:block(-4.7+i*9.4/32,5.25,3.77,Vector3(.025,1,.025),metal)
	for y in [4.9,5.75]:block(0,y,3.77,Vector3(9.5,.05,.05),metal)
	for x in [-13.8,-4.35,4.35,13.8]:block(x,8.8,1.5,Vector3(.3,.25,3),pale,true)
	var merged:=SurfaceTool.new();merged.begin(Mesh.PRIMITIVE_TRIANGLES)
	var old:Array[Node]=[]
	for child in facade.group.get_children():
		if child is MeshInstance3D and child.get_meta("b_courtyard_ramp",false):
			merged.append_from(child.mesh,0,child.transform);old.append(child)
	merged.index()
	var ramp_mat:Material=facade.host.material("EDA B courtyard stair collision",Color.WHITE)
	var collision:MeshInstance3D=facade.host.mesh_node(facade.group,merged.commit(),ramp_mat,"BCourtyardWalkingSurface")
	collision.visible=false;collision.set_meta("walk_collision",true);collision.set_meta("b_courtyard_detail",true)
	for child in old:facade.group.remove_child(child);child.free()
	marker(pale)

func rail(a:Vector3,b:Vector3,mat:Material):
	var pa:=center+axis*a.x+out*a.z
	var pb:=center+axis*b.x+out*b.z
	var aa:=Vector3(pa.x,a.y,pa.y)
	var bb:=Vector3(pb.x,b.y,pb.y)
	var n:MeshInstance3D=facade.host.box(facade.group,(aa+bb)/2,Vector3(.045,aa.distance_to(bb),.045),mat,"BCourtyardRail")
	var up:Vector3=(bb-aa).normalized()
	var x:=Vector3(0,1,0).cross(up).normalized()
	n.basis=Basis(x,up,x.cross(up).normalized())
	n.set_meta("walk_collision",false)

func prism(poly:PackedVector2Array,z0:float,z1:float,mat:Material):
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ids:=Geometry2D.triangulate_polygon(poly)
	for z in [z0,z1]:
		for i in range(0,ids.size(),3):
			var tri:Array[Vector3]=[]
			for j in 3:tri.append(Vector3(poly[ids[i+j]].x,poly[ids[i+j]].y,z))
			emit(st,tri,Vector3(0,0,-1 if z==z0 else 1))
	var area:=0.0
	for i in poly.size():area+=poly[i].cross(poly[(i+1)%poly.size()])
	var clockwise:=area<0
	for i in poly.size():
		var a:=poly[i];var b:=poly[(i+1)%poly.size()]
		var delta:=b-a
		var normal:=Vector3(delta.y,-delta.x,0).normalized()
		if clockwise:normal=-normal
		var a0:=Vector3(a.x,a.y,z0);var b0:=Vector3(b.x,b.y,z0)
		var a1:=Vector3(a.x,a.y,z1);var b1:=Vector3(b.x,b.y,z1)
		emit(st,[a0,b0,b1],normal);emit(st,[a0,b1,a1],normal)
	st.generate_normals();st.index()
	var n:MeshInstance3D=facade.host.mesh_node(facade.group,st.commit(),mat,"BCourtyardStairSkirt")
	n.position=Vector3(center.x,0,center.y);n.rotation.y=-atan2(axis.y,axis.x)
	# Local +Z of the rotation may be inward: reflect vertices, preserving winding.
	if Vector2(-axis.y,axis.x).dot(out)<0:
		var arrays:Array=n.mesh.surface_get_arrays(0)
		var verts:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var index:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for i in verts.size():
			verts[i].z=-verts[i].z;normals[i].z=-normals[i].z
		arrays[Mesh.ARRAY_NORMAL]=normals
		for i in range(0,index.size(),3):
			var temp:=index[i+1];index[i+1]=index[i+2];index[i+2]=temp
		arrays[Mesh.ARRAY_VERTEX]=verts;arrays[Mesh.ARRAY_INDEX]=index
		var corrected:=ArrayMesh.new();corrected.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		n.mesh=corrected
	n.set_meta("walk_collision",true);n.set_meta("b_courtyard_detail",true)
func emit(st:SurfaceTool,tri:Array[Vector3],normal:Vector3):
	st.set_smooth_group(-1)
	if (tri[2]-tri[0]).cross(tri[1]-tri[0]).dot(normal)<0:tri.reverse()
	for v in tri:st.set_uv(Vector2(v.x,-v.y));st.add_vertex(v)

func ramp(x0:float,y0:float,x1:float,y1:float,z0:float,z1:float):
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners:Array[Vector3]=[]
	for v in [Vector3(x0,y0,z0),Vector3(x0,y0,z1),Vector3(x1,y1,z1),Vector3(x1,y1,z0)]:
		var p:Vector2=center+axis*v.x+out*v.z
		corners.append(Vector3(p.x,v.y,p.y))
	for ids in [[0,1,2],[0,2,3]]:
		var tri:Array[Vector3]=[corners[ids[0]],corners[ids[1]],corners[ids[2]]]
		emit(st,tri,Vector3.UP)
	st.generate_normals();st.index()
	var material:Material=facade.host.material("EDA B courtyard stair collision",Color.WHITE)
	var node:MeshInstance3D=facade.host.mesh_node(facade.group,st.commit(),material,"BCourtyardStairRamp")
	node.visible=false;node.set_meta("walk_collision",true);node.set_meta("b_courtyard_detail",true);node.set_meta("b_courtyard_ramp",true)





func marker(pale:Material):
	var at:Vector2=center+axis*4.85+out*3.22
	var disk:=CylinderMesh.new();disk.top_radius=.42;disk.bottom_radius=.42;disk.height=.035;disk.radial_segments=32
	var node:MeshInstance3D=facade.host.mesh_node(facade.group,disk,pale,"BCourtyardMarker")
	var horizontal:=Vector3(-axis.x,0,-axis.y)
	var normal:=Vector3(out.x,0,out.y)
	node.basis=Basis(horizontal,normal,horizontal.cross(normal))
	node.position=Vector3(at.x,8.2,at.y);node.set_meta("walk_collision",false)
	var blue:Material=facade.host.material("EDA B courtyard marker blue",Color("1e48b4"));blue.albedo_texture=null;blue.cull_mode=BaseMaterial3D.CULL_BACK
	var inner:=CylinderMesh.new();inner.top_radius=.375;inner.bottom_radius=.375;inner.height=.012;inner.radial_segments=32
	var field:MeshInstance3D=facade.host.mesh_node(facade.group,inner,blue,"BCourtyardMarkerField")
	field.basis=node.basis;field.position=node.position+normal*.024;field.set_meta("walk_collision",false)
	var text:=TextMesh.new();text.text="B";text.font=load("res://assets/fonts/CampusSans.ttf");text.font_size=64;text.pixel_size=.01;text.depth=.005
	var letter:MeshInstance3D=facade.host.mesh_node(facade.group,text,pale,"BCourtyardLetter")
	letter.basis=Basis(horizontal,Vector3.UP,normal)
	letter.position=Vector3(at.x,8.2,at.y)+normal*.034;letter.set_meta("walk_collision",false)
