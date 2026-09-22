extends RefCounted
## Bounded west-wing exterior panels; all dimensions remain estimates.
var host
var origin:Vector2
var axis:Vector2
var outward:Vector2
var length:float
func frame(points:PackedVector2Array,edge:int)->void:
	origin=points[edge]
	var end:=points[(edge+1)%points.size()]
	axis=(end-origin).normalized()
	length=origin.distance_to(end)
	outward=Vector2(axis.y,-axis.x)
	if Geometry2D.is_point_in_polygon((origin+end)/2+outward,points):outward=-outward
func panel(x:float,y:float,width:float,height:float,offset:float,depth:float,mat:Material)->void:
	var center:=origin+axis*x+outward*offset
	host.edge_box(center-axis*width/2,center+axis*width/2,y,height,depth,mat)

func cornice(points:PackedVector2Array,profile:Dictionary,pale:StandardMaterial3D)->void:
	var path:=PackedVector2Array()
	var offsets:=PackedVector2Array()
	for region in profile.surfaces:
		frame(points,int(region.edge))
		if path.is_empty():
			path.append(origin+axis*length*float(region.span[0]))
			offsets.append(outward)
		else:
			var bisector:Vector2=(offsets[-1]+outward).normalized()
			offsets[-1]=bisector/bisector.dot(outward)
		path.append(origin+axis*length*float(region.span[1]))
		offsets.append(outward)
	var finish:StandardMaterial3D=pale.duplicate()
	finish.resource_name="Library west projecting cornice"
	finish.cull_mode=BaseMaterial3D.CULL_BACK
	for lip in profile.cornice.lips:
		var ring:=PackedVector2Array()
		for i in path.size():ring.append(path[i]+offsets[i]*float(profile.cornice.inner_offset))
		for i in range(path.size()-1,-1,-1):ring.append(path[i]+offsets[i]*float(lip.projection))
		var top:float=lip.center_y+lip.thickness/2
		var bottom:float=lip.center_y-lip.thickness/2
		var st:=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)
		var indices:=Geometry2D.triangulate_polygon(ring)
		assert(not indices.is_empty())
		for i in range(0,indices.size(),3):
			for j in [0,1,2]:st.add_vertex(Vector3(ring[indices[i+j]].x,top,ring[indices[i+j]].y))
			for j in [2,1,0]:st.add_vertex(Vector3(ring[indices[i+j]].x,bottom,ring[indices[i+j]].y))
		for i in ring.size():
			var a:=ring[i]
			var b:=ring[(i+1)%ring.size()]
			var vertices:Array[Vector3]=[Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),Vector3(b.x,top,b.y),Vector3(a.x,top,a.y)]
			var normal:Vector2=Vector2((b-a).y,-(b-a).x).normalized()
			if Geometry2D.is_point_in_polygon((a+b)/2+normal*0.001,ring):normal=-normal
			if (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).dot(Vector3(normal.x,0,normal.y))<0:vertices.reverse()
			for j in [0,1,2,0,2,3]:st.add_vertex(vertices[j])
		st.generate_normals()
		st.index()
		var node:MeshInstance3D=host.builder.mesh_node(host.group,st.commit(),finish,"LibraryWestCornice")
		node.set_meta("walk_collision",false)

func build(facade,points:PackedVector2Array,profile:Dictionary)->void:
	host=facade
	var wall:StandardMaterial3D=host.builder.material("Library west grey render",Color("89877e"))
	wall.albedo_texture=null
	wall.roughness=0.9
	var pale:StandardMaterial3D=host.builder.material("Library west pale frame",Color("c4c4b9"))
	pale.albedo_texture=null
	var glass:StandardMaterial3D=host.builder.material("Library west glazing",Color("46616a"))
	glass.albedo_texture=null
	glass.metallic=0.45
	glass.roughness=0.24
	var metal:StandardMaterial3D=host.builder.material("Photo aluminium",Color("333c3d"))
	for region in profile.surfaces:
		frame(points,int(region.edge))
		var left:=float(region.span[0])*length
		var right:=float(region.span[1])*length
		var bottom:float=profile.get("ground_floor",{}).get("surface_bottom",4.8)
		panel((left+right)/2,(17.6+bottom)/2,right-left,17.6-bottom,0.025,0.04,wall)
		for y in [8.8,13.2]: panel((left+right)/2,y,right-left,0.35,0.055,0.04,pale)
	cornice(points,profile,pale)
	for window_index in profile.windows.size():
		var region:Dictionary=profile.windows[window_index]
		frame(points,int(region.edge))
		var left:=float(region.span[0])*length
		var right:=float(region.span[1])*length
		var bays:=int(region.bays)
		var pitch:float=(right-left)/bays
		var width:float=pitch*float(region.width_fraction)
		var height:float=region.height
		for original_y in region.centers_y:
			var y:float=original_y
			if window_index in PackedInt32Array(profile.get("ground_floor",{}).get("extend_window_indices",[])):
				var top:float=y+height/2
				var sill:float=profile.ground_floor.sill_y
				height=top-sill;y=(top+sill)/2
			for bay in bays:
				var center:float=left+(bay+0.5)*pitch
				panel(center,float(y),width,height,0.1,0.08,glass)
				for j in int(region.columns)+1:
					panel(center-width/2+width*j/int(region.columns),float(y),0.055,height+0.08,0.18,0.1,metal)
				for j in int(region.rows)+1:
					panel(center,float(y)-height/2+height*j/int(region.rows),width+0.08,0.055,0.18,0.1,metal)
				if region.get("pale_frame",false):
					for x in [center-width/2-0.16,center+width/2+0.16]:panel(x,float(y),0.28,height+0.56,0.12,0.18,pale)
					for yy in [float(y)-height/2-0.16,float(y)+height/2+0.16]:panel(center,yy,width+0.56,0.28,0.12,0.18,pale)
