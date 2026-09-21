extends RefCounted
const Profile=preload("res://tools/eda_sports_entry_profile.gd")
var p:Dictionary
var base:float
var group:Node3D
var host
var axis:Vector2
var side:Vector2
var half:float
func vertex(s:float,c:float,y:float)->Vector3:
	var q:=Profile.point(p,s,c)
	return Vector3(q.x,base+y,q.y)
func quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3,normal:=Vector3.UP)->void:
	for tri in [[a,b,c],[a,c,d]]:
		if (tri[2]-tri[0]).cross(tri[1]-tri[0]).length_squared()<0.000000001:continue
		if (tri[2]-tri[0]).cross(tri[1]-tri[0]).dot(normal)<0:tri.reverse()
		for v:Vector3 in tri:
			var q:=Vector2(v.x,v.z)-Vector2(p.origin_xz[0],p.origin_xz[1])
			var uv:=Vector2(q.dot(axis),q.dot(side))
			if absf(normal.y)<0.5:
				var tangent:=Vector2(normal.z,-normal.x).normalized()
				uv=Vector2(q.dot(tangent),v.y-base)
			st.set_uv(uv)
			st.add_vertex(v)
func patch(st:SurfaceTool,a:float,b:float,ya:float,yb:float)->void:
	quad(st,vertex(a,-half,ya),vertex(b,-half,yb),vertex(b,half,yb),vertex(a,half,ya))
func mesh(st:SurfaceTool,mat:Material,label:String,solid:bool,visible:=true)->void:
	st.index();st.generate_normals()
	var node:MeshInstance3D=host.mesh_node(group,st.commit(),mat,label)
	node.set_meta("walk_collision",solid);node.visible=visible
func cut_base(feature:Node3D)->void:
	var outline:=Profile.mask(p)
	for node in feature.get_children():
		if not node is MeshInstance3D or node.material_override.resource_name!="Sports base":continue
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var faces:PackedVector3Array=node.mesh.get_faces()
		var tessellator:=preload("res://tools/build_roads.gd").new()
		for i in range(0,faces.size(),3):
			var ring:=PackedVector2Array()
			for j in 3:
				var v:Vector3=node.transform*faces[i+j]
				ring.append(Vector2(v.x,v.z))
			if Geometry2D.is_polygon_clockwise(ring):ring.reverse()
			for piece in tessellator.tessellate([ring],[outline]):
				for j in [0,2,1,0,3,2]:st.add_vertex(Vector3(piece[j].x,float(p.existing_base_offset_m),piece[j].y))
		st.index();st.generate_normals();node.mesh=st.commit();node.transform=Transform3D.IDENTITY
func build(builder)->void:
	host=builder;p=Profile.load_profile()
	var feature:Node3D=host.scene.get_node("Feature_"+p.feature_id)
	base=feature.position.y
	assert(absf(base-float(p.expected_base_y))<0.002,"Sports entrance base changed")
	cut_base(feature)
	group=Node3D.new();group.name="SportsEastEntry";host.scene.add_child(group);group.owner=host.scene
	group.set_meta("static_collision_group",true);group.set_meta("absolute_terrain_y",true);group.set_meta("dimensions_are_approximate",true)
	axis=Vector2(p.outward_xz[0],p.outward_xz[1]);side=Vector2(p.cross_xz[0],p.cross_xz[1])
	half=float(p.clear_width_m)/2+float(p.cheek_width_m)
	var top:=float(p.upper_surface_offset_m)
	var lip:=float(p.upper_lip_m)
	var going:=float(p.going_m)
	var rise:=float(p.riser_m)
	var count:=int(p.risers)
	var toe:=lip+(count-1)*going
	var low:=top-count*rise
	var landing_end:=toe+float(p.lower_landing_m)
	var end:=float(p.end_station_m)
	var existing:=float(p.existing_base_offset_m)
	var stone:=SurfaceTool.new();var support:=SurfaceTool.new();var walk:=SurfaceTool.new();var paving:=SurfaceTool.new()
	for st in [stone,support,walk,paving]:st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_smooth_group(-1)
	var stone_start:=lip-float(p.upper_stone_strip_m)
	patch(paving,0,stone_start,top,top)
	patch(stone,stone_start,lip,top,top)
	for i in count:
		var s:=lip+i*going
		var high:=top-i*rise
		quad(stone,vertex(s,-half,high),vertex(s,half,high),vertex(s,half,high-rise),vertex(s,-half,high-rise),Vector3(axis.x,0,axis.y))
		if i<count-1:patch(stone,s,s+going,high-rise,high-rise)
	patch(stone,toe,landing_end,low,low)
	patch(stone,landing_end,end,low,existing)
	patch(walk,0,lip,top,top)
	patch(walk,lip,toe+going,top,low)
	patch(walk,toe+going,landing_end,low,low)
	patch(walk,landing_end,end,low,existing)
	# Only local side closures meet the pre-existing flattened sports base.
	for sign_side:float in [-1.0,1.0]:
		for span in [[0.0,lip-.3,top,top],[toe+.3,landing_end,low,low],[landing_end,end,low,existing]]:
			var a:float=span[0];var b:float=span[1];var y:float=span[2];var yb:float=span[3]
			var outward:=Vector3(side.x,0,side.y)*sign_side
			# The closed cheek supplies the side face beside the flight itself.
			quad(support,vertex(a,half*sign_side,y),vertex(b,half*sign_side,yb),vertex(b,half*sign_side,existing),vertex(a,half*sign_side,existing),outward)
			quad(support,vertex(a,half*sign_side,y),vertex(b,half*sign_side,yb),vertex(b,half*sign_side,existing),vertex(a,half*sign_side,existing),-outward)
	var finish:=preload("res://tools/eda_surface_details.gd").new()
	var material:=finish.ground_material("EDA sports entry stone",Color("969991"),7)
	material.shader=material.shader.duplicate()
	material.shader.code=material.shader.code.replace("cull_disabled","cull_back")
	var bricks:=finish.ground_material("EDA sports entry brick paving",Color("8c8d78"),2)
	bricks.shader=material.shader
	mesh(paving,bricks,"EntryBrickPaving",false)
	mesh(stone,material,"EntryStone",false)
	mesh(support,material,"EntrySideClosure",true)
	mesh(walk,host.material("EDA sports entry collision",Color.WHITE),"EntryWalk",true,false)
	var cheek:=SurfaceTool.new();cheek.begin(Mesh.PRIMITIVE_TRIANGLES);cheek.set_smooth_group(-1)
	var rail:StandardMaterial3D=host.material("EDA stand rail",Color("9aaba8"));rail.albedo_texture=null;rail.metallic=.6;rail.roughness=.38
	var tubes:=preload("res://tools/build_eda_goals.gd").new()
	for sign_side:float in [-1.0,1.0]:
		var c0:=float(p.clear_width_m)/2*sign_side
		var c1:=half*sign_side
		var a:=lip-.3;var b:=toe+.3
		var ya:=top+.22;var yb:=existing+.12
		quad(cheek,vertex(a,c0,ya),vertex(b,c0,yb),vertex(b,c1,yb),vertex(a,c1,ya))
		quad(cheek,vertex(a,c0,low-.05),vertex(a,c1,low-.05),vertex(b,c1,low-.05),vertex(b,c0,low-.05),Vector3.DOWN)
		for pair in [[c0,-sign_side],[c1,sign_side]]:
			var c:float=pair[0];var n:=Vector3(side.x,0,side.y)*float(pair[1])
			quad(cheek,vertex(a,c,low-.05),vertex(b,c,low-.05),vertex(b,c,yb),vertex(a,c,ya),n)
		quad(cheek,vertex(a,c0,low-.05),vertex(a,c1,low-.05),vertex(a,c1,ya),vertex(a,c0,ya),Vector3(-axis.x,0,-axis.y))
		quad(cheek,vertex(b,c0,low-.05),vertex(b,c1,low-.05),vertex(b,c1,yb),vertex(b,c0,yb),Vector3(axis.x,0,axis.y))
		var center:float=(c0+c1)*.5
		for t in [0.0,.5,1.0]:
			var s:=lerpf(a,b,t);var y:=lerpf(ya,yb,t)
			tubes.tube(host,group,vertex(s,center,y),vertex(s,center,y+.9),.025,rail)
		for h in [.42,.9]:tubes.tube(host,group,vertex(a,center,ya+h),vertex(b,center,yb+h),.025,rail)
	mesh(cheek,material,"EntryCheeks",true)
