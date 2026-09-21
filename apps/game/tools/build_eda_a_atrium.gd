extends RefCounted

# All dimensions are proportional candidates supplied by the registration profile.
# Local X follows the photographed eastward view; local Z is its right/south side.
var host
var parent: Node3D
var center := Vector2.ZERO
var axis := Vector2.RIGHT
var across := Vector2.DOWN
var mats: Dictionary
var ramps: SurfaceTool
var guards: SurfaceTool

func position(x: float, y: float, z: float) -> Vector3:
	var p := center+axis*x+across*z
	return Vector3(p.x,y,p.y)

func block(at: Vector3, size: Vector3, key: String, title: String, solid := false) -> MeshInstance3D:
	var node: MeshInstance3D = host.box(parent,position(at.x,at.y,at.z),size,mats[key],title)
	node.rotation.y=-atan2(axis.y,axis.x)
	node.set_meta("walk_collision",solid)
	return node

func rod(a: Vector3, b: Vector3, radius: float, key: String, title: String, solid := false) -> void:
	var from := position(a.x,a.y,a.z)
	var to := position(b.x,b.y,b.z)
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=from.distance_to(to)
	mesh.radial_segments=12 if radius<0.1 else 24
	mesh.rings=1
	var node: MeshInstance3D = host.mesh_node(parent,mesh,mats[key],title)
	node.position=(from+to)*0.5
	node.quaternion=Quaternion(Vector3.UP,(to-from).normalized())
	node.set_meta("walk_collision",solid)

func rail(a: Vector3, b: Vector3) -> void:
	guard(a,b)
	var count := maxi(1,ceili(a.distance_to(b)/1.2))
	for i in count+1:
		var p := a.lerp(b,float(i)/count)
		rod(p,p+Vector3.UP*1.1,.025,"metal","AAtriumRailPost")
	for i in 6:
		var lift := Vector3.UP*(.18+float(i)*.184)
		rod(a+lift,b+lift,.022 if i<5 else .032,"metal","AAtriumRail")

func cutouts(settings: Dictionary) -> Dictionary:
	var result := {"body":[],"roof":[]}
	var direction := Vector2(settings.axis[0],settings.axis[1]).normalized()
	var right := Vector2(-direction.y,direction.x)
	for c in settings.centers:
		var origin := Vector2(c[0],c[1])
		for kind in ["body","roof"]:
			var extra := float(settings.gallery_width) if kind=="body" else 0.0
			var half := Vector2(float(settings.length)*.5+extra,float(settings.width)*.5+extra)
			var ring := PackedVector2Array()
			for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				ring.append(origin+direction*corner.x*half.x+right*corner.y*half.y)
			result[kind].append(ring)
	return result

func build(builder, group: Node3D, settings: Dictionary) -> void:
	host=builder
	parent=group
	mats={}
	ramps=SurfaceTool.new()
	ramps.begin(Mesh.PRIMITIVE_TRIANGLES)
	guards=SurfaceTool.new()
	guards.begin(Mesh.PRIMITIVE_TRIANGLES)
	for item in [["wall","dadbd2"],["floor","c6c3b6"],["tread","c9c3af"],["metal","8b9692"],["glass","b1cacb"]]:
		var mat: StandardMaterial3D = host.material("EDA A atrium "+item[0],Color(item[1]))
		mat.albedo_texture=null
		mat.cull_mode=BaseMaterial3D.CULL_BACK
		mats[item[0]]=mat
	# Subtle, non-patterned material response: pale plaster, matte stone and dark treads.
	for key in ["floor","tread"]:
		mats[key].albedo_texture=load("res://assets/textures/buildings/mineral_render_albedo.png")
		mats[key].uv1_triplanar=true
		mats[key].uv1_world_triplanar=true
		mats[key].uv1_scale=Vector3.ONE*.8
		mats[key].texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mats.wall.roughness=.9
	mats.floor.roughness=.72
	mats.tread.roughness=.85
	mats.metal.roughness=.32
	mats.metal.metallic=.65
	mats.glass.roughness=.22
	mats.glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mats.glass.albedo_color.a=.38
	var base_axis := Vector2(settings.axis[0],settings.axis[1]).normalized()
	for index in settings.centers.size():
		center=Vector2(settings.centers[index][0],settings.centers[index][1])
		axis=base_axis*(-1.0 if index==0 else 1.0)
		across=Vector2(-axis.y,axis.x)
		build_one(settings,index)
	var ramp_mat: StandardMaterial3D = host.material("EDA A atrium unique stair walk collision",Color.WHITE)
	ramp_mat.cull_mode=BaseMaterial3D.CULL_BACK
	var ramp_node: MeshInstance3D = host.mesh_node(parent,ramps.commit(),ramp_mat,"AAtriumStairWalkCollision")
	ramp_node.visible=false
	ramp_node.set_meta("walk_collision",true)
	var guard_mat: StandardMaterial3D = host.material("EDA A atrium unique guard collision",Color.WHITE)
	guard_mat.cull_mode=BaseMaterial3D.CULL_BACK
	var guard_node: MeshInstance3D = host.mesh_node(parent,guards.commit(),guard_mat,"AAtriumGuardCollision")
	guard_node.visible=false
	guard_node.set_meta("walk_collision",true)

func build_one(s: Dictionary, index: int) -> void:
	var length := float(s.length)
	var width := float(s.width)
	var gallery := float(s.gallery_width)
	var storey := float(s.storey)
	var slab := float(s.get("slab_thickness",.35))
	var stair_width := float(s.get("stair_width",2.2))
	var stair_z := -width*.5+stair_width*.5
	var steps := int(s.get("stair_steps",24))
	assert(steps%2==0)
	var tread := float(s.get("stair_tread",.29))
	var landing := float(s.get("stair_landing",1.3))
	var run := steps*tread+landing
	var start := length*.5-run
	var foot_length := float(s.get("stair_foot_landing",1.3))
	block(Vector3(0,.03-slab*.5,0),Vector3(length+gallery*2,slab,width+gallery*2),"floor","AAtriumGround",true)
	# White linings stay inside the cut cavity; they add no speculative doorways.
	var wall_height := float(s.get("roof_y",21.18))
	for side in [-1.0,1.0]:
		lining(s,index,"side",side,length*.5+gallery,width*.5+gallery,wall_height)
		lining(s,index,"end",side,width*.5+gallery,length*.5+gallery,wall_height)
	# Box slabs provide opaque white soffits beneath the surrounding roof ring.
	for side in [-1.0,1.0]:
		block(Vector3(0,wall_height-.09,side*(width+gallery)*.5),Vector3(length,.18,gallery),"wall","AAtriumSideCeiling",true)
		block(Vector3(side*(length+gallery)*.5,wall_height-.09,0),Vector3(gallery,.18,width+gallery*2),"wall","AAtriumEndCeiling",true)
	# This short landing joins the north gallery to the first flight at the same level.
	block(Vector3(start-foot_length*.5,storey-slab*.5,stair_z),Vector3(foot_length,slab,stair_width),"floor","AAtriumStairFootLanding",true)
	# The landing west edge is open: the photographed lower stair arrives here.
	rail(Vector3(start-foot_length,storey,-width*.5+stair_width),Vector3(start,storey,-width*.5+stair_width))
	for level in range(1,5):
		var y := level*storey
		for side in [-1.0,1.0]:
			block(Vector3(0,y-slab*.5,side*(width+gallery)*.5),Vector3(length,slab,gallery),"floor","AAtriumSideGallery",true)
			block(Vector3(side*(length+gallery)*.5,y-slab*.5,0),Vector3(gallery,slab,width+gallery*2),"floor","AAtriumEndGallery",true)
			# The north second-floor railing leaves access to the evidenced stair foot.
			if level==1 and side<0:
				rail(Vector3(-length*.5,y,-width*.5),Vector3(start-foot_length,y,-width*.5))
				rail(Vector3(start,y,-width*.5),Vector3(length*.5,y,-width*.5))
			else:
				rail(Vector3(-length*.5,y,side*width*.5),Vector3(length*.5,y,side*width*.5))
			# East third-floor end gallery receives the upper stair flight.
			var first_z := -width*.5+stair_width if level==2 and side>0 else -width*.5
			rail(Vector3(side*length*.5,y,first_z),Vector3(side*length*.5,y,width*.5))
	var column_count := int(s.get("column_intervals",4))
	for i in column_count+1:
		for side in [-1.0,1.0]:
			var x := lerpf(-length*.5,length*.5,float(i)/column_count)
			rod(Vector3(x,0,side*(width*.5+.35)),Vector3(x,wall_height,side*(width*.5+.35)),.34,"wall","AAtriumColumn",true)
	# The foreground flight rises from the ground to the second-floor landing.
	# Its lower end is cropped; use a proportional straight run, without an unseen half-landing.
	var lower_steps := int(s.get("stair_lower_steps",24))
	var lower_tread := float(s.get("stair_lower_tread",tread))
	var lower_end := start-foot_length
	var lower_start := lower_end-lower_steps*lower_tread
	var ground_top := .03
	ramp(lower_start,lower_end,ground_top,storey,stair_z-stair_width*.5,stair_z+stair_width*.5)
	for step in lower_steps:
		var top := lerpf(ground_top,storey,float(step+1)/lower_steps)
		block(Vector3(lower_start+(step+.5)*lower_tread,top-.11,stair_z),Vector3(lower_tread,.22,stair_width),"tread","AAtriumLowerStairTread")
		block(Vector3(lower_start+step*lower_tread+.025,top+.004,stair_z),Vector3(.045,.008,stair_width),"metal","AAtriumLowerStairNosing")
	for side in [-1.0,1.0]:
		rail(Vector3(lower_start,ground_top,stair_z+side*stair_width*.5),Vector3(lower_end,storey,stair_z+side*stair_width*.5))
	for flight in 2:
		var x0 := start+flight*(steps/2*tread+landing)
		var y0 := storey+flight*storey*.5
		ramp(x0,x0+steps/2*tread,y0,y0+storey*.5,stair_z-stair_width*.5,stair_z+stair_width*.5)
		for step in steps/2:
			var top := y0+(step+1)*storey/steps
			block(Vector3(x0+(step+.5)*tread,top-.11,stair_z),Vector3(tread,.22,stair_width),"tread","AAtriumStairTread")
			block(Vector3(x0+step*tread+.025,top+.004,stair_z),Vector3(.045,.008,stair_width),"metal","AAtriumStairNosing")
		for side in [-1.0,1.0]:
			rail(Vector3(x0,y0,stair_z+side*stair_width*.5),Vector3(x0+steps/2*tread,y0+storey*.5,stair_z+side*stair_width*.5))
		if flight==0:
			var middle := x0+steps/2*tread
			block(Vector3(middle+landing*.5,storey*1.5-slab*.5,stair_z),Vector3(landing,slab,stair_width),"floor","AAtriumStairLanding",true)
			for side in [-1.0,1.0]:
				rail(Vector3(middle,storey*1.5,stair_z+side*stair_width*.5),Vector3(middle+landing,storey*1.5,stair_z+side*stair_width*.5))
	var roof_y := float(s.get("roof_y",20.3))
	var crown := float(s.get("roof_rise",1.1))
	var ribs := int(s.get("roof_beams",9))
	var strips := 8
	for i in ribs:
		var x := lerpf(-length*.5,length*.5,float(i)/(ribs-1))
		block(Vector3(x,roof_y-.45,0),Vector3(.34,.9,width),"wall","AAtriumRoofBeam")
		for j in strips:
			var z0 := lerpf(-width*.5,width*.5,float(j)/strips)
			var z1 := lerpf(-width*.5,width*.5,float(j+1)/strips)
			var y0 := roof_y+crown*(1.0-pow(z0/(width*.5),2))
			var y1 := roof_y+crown*(1.0-pow(z1/(width*.5),2))
			rod(Vector3(x,y0,z0),Vector3(x,y1,z1),.045,"metal","AAtriumRoofRib")
	for j in strips:
		var z0 := lerpf(-width*.5,width*.5,float(j)/strips)
		var z1 := lerpf(-width*.5,width*.5,float(j+1)/strips)
		var y0 := roof_y+crown*(1.0-pow(z0/(width*.5),2))
		var y1 := roof_y+crown*(1.0-pow(z1/(width*.5),2))
		var pane := block(Vector3(0,(y0+y1)*.5,(z0+z1)*.5),Vector3(length,.035,Vector2(z1-z0,y1-y0).length()),"glass","AAtriumRoofGlass",true)
		pane.rotate_object_local(Vector3.RIGHT,-atan2(y1-y0,z1-z0))
		rod(Vector3(-length*.5,y0,z0),Vector3(length*.5,y0,z0),.04,"metal","AAtriumRoofLongitudinal")
	rod(Vector3(-length*.5,roof_y,width*.5),Vector3(length*.5,roof_y,width*.5),.04,"metal","AAtriumRoofLongitudinal")
	# Each end is a closed thin extrusion of the same eight-segment roof profile.
	var end_profile := PackedVector2Array()
	for j in strips+1:
		var z := lerpf(-width*.5,width*.5,float(j)/strips)
		end_profile.append(Vector2(z,roof_y+crown*(1.0-pow(z/(width*.5),2))))
	for side in [-1.0,1.0]:
		roof_end(end_profile,side*length*.5,.035)


func ramp(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
	var corners: Array[Vector3] = [position(x0,y0,z0),position(x1,y1,z0),position(x1,y1,z1),position(x0,y0,z1)]
	for i in 4:
		corners.append(corners[i]-Vector3.UP*.18)
	for face in [[0,3,2,1],[7,4,5,6],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
		var a: Vector3 = corners[face[0]]
		var b: Vector3 = corners[face[1]]
		var c: Vector3 = corners[face[2]]
		var d: Vector3 = corners[face[3]]
		var normal := (b-a).cross(c-a).normalized()
		# Godot front faces have clockwise vertex order.
		for vertex in [a,c,b,a,d,c]:
			ramps.set_normal(normal)
			ramps.add_vertex(vertex)

func guard(a: Vector3, b: Vector3) -> void:
	var along := Vector2(b.x-a.x,b.z-a.z).normalized()
	var offset := Vector3(-along.y,0,along.x)*.035
	var local: Array[Vector3] = [a-offset,b-offset,b+offset,a+offset]
	var corners: Array[Vector3] = []
	for i in 8:
		var p := local[i%4]+Vector3.UP*(1.1 if i>=4 else 0.0)
		corners.append(position(p.x,p.y,p.z))
	var centroid := Vector3.ZERO
	for p in corners:
		centroid+=p/8.0
	for face in [[0,1,2,3],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
		var p: Vector3 = corners[face[0]]
		var q: Vector3 = corners[face[1]]
		var r: Vector3 = corners[face[2]]
		var t: Vector3 = corners[face[3]]
		var normal := (q-p).cross(r-p).normalized()
		if normal.dot((p+q+r+t)*.25-centroid)<0.0:
			normal=-normal
			var swap := q
			q=t
			t=swap
		for vertex in [p,r,q,p,t,r]:
			guards.set_normal(normal)
			guards.add_vertex(vertex)

func roof_end(profile: PackedVector2Array, x: float, thickness: float) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(profile)
	assert(not indices.is_empty())
	var middle := Vector3.ZERO
	for p in profile:
		middle+=position(x,p.y,p.x)/profile.size()
	for side in [-1.0,1.0]:
		for i in range(0,indices.size(),3):
			var a := profile[indices[i]]
			var b := profile[indices[i+1]]
			var c := profile[indices[i+2]]
			outward_triangle(mesh,position(x+side*thickness*.5,a.y,a.x),position(x+side*thickness*.5,b.y,b.x),position(x+side*thickness*.5,c.y,c.x),middle)
	for i in profile.size():
		var p := profile[i]
		var q := profile[(i+1)%profile.size()]
		var a := position(x-thickness*.5,p.y,p.x)
		var b := position(x+thickness*.5,p.y,p.x)
		var c := position(x+thickness*.5,q.y,q.x)
		var d := position(x-thickness*.5,q.y,q.x)
		outward_triangle(mesh,a,b,c,middle)
		outward_triangle(mesh,a,c,d,middle)
	# The parent batches this surface with indexed BoxMesh panes.
	mesh.index()
	var node: MeshInstance3D = host.mesh_node(parent,mesh.commit(),mats.glass,"AAtriumRoofEndGlass")
	node.set_meta("walk_collision",true)

func outward_triangle(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.dot((a+b+c)/3.0-inside)<0.0:
		normal=-normal
		var swap := b
		b=c
		c=swap
	for vertex in [a,c,b]:
		mesh.set_normal(normal)
		mesh.add_vertex(vertex)

func lining(settings: Dictionary, index: int, kind: String, side: float, half_span: float, wall_offset: float, wall_height: float) -> void:
	var cuts: Array = settings.get("entry_lining_cuts",[]).duplicate()
	var active: Array[Vector3] = []
	var stations: Array[float] = [-half_span,half_span]
	for cut in cuts:
		if int(cut.index)!=index or String(cut.kind)!=kind or not is_equal_approx(float(cut.side),side):
			continue
		var begin := clampf(float(cut.start),-half_span,half_span)
		var end := clampf(float(cut.end),-half_span,half_span)
		var height := clampf(float(cut.height),0.0,wall_height)
		assert(end>begin and height>0.0,"Invalid atrium lining opening")
		active.append(Vector3(begin,end,height))
		if not stations.has(begin): stations.append(begin)
		if not stations.has(end): stations.append(end)
	stations.sort()
	# Split on all boundaries so overlapping lower openings form their exact union.
	for i in stations.size()-1:
		var begin: float = stations[i]
		var end: float = stations[i+1]
		var midpoint := (begin+end)*.5
		var bottom := 0.0
		for cut in active:
			if midpoint>cut.x and midpoint<cut.y: bottom=maxf(bottom,cut.z)
		if wall_height-bottom<.0001 or end-begin<.0001: continue
		var at := Vector3(midpoint,(bottom+wall_height)*.5,side*(wall_offset-.035))
		var size := Vector3(end-begin,wall_height-bottom,.07)
		var title := "AAtriumSideLining"
		if kind=="end":
			at=Vector3(side*(wall_offset-.035),at.y,midpoint)
			size=Vector3(.07,size.y,end-begin)
			title="AAtriumEndLining"
		block(at,size,"wall",title)
