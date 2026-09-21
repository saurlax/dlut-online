extends RefCounted
## A registered bridge alignment with independently adjustable approach flights.
var host
var group: Node3D
var terrain
var profile: Dictionary
var start := Vector2.ZERO
var axis := Vector2.RIGHT
var across := Vector2.DOWN
var length := 0.0
var west_run := 0.0
var east_run := 0.0
var west_y := 0.0
var east_y := 0.0
var surfaces: Dictionary = {}
var materials: Dictionary = {}

func build(builder, settings: Dictionary, ground) -> Node3D:
	host=builder
	terrain=ground
	profile=settings
	start=Vector2(settings.west[0],settings.west[1])
	var finish := Vector2(settings.east[0],settings.east[1])
	length=start.distance_to(finish)
	axis=(finish-start).normalized()
	across=Vector2(-axis.y,axis.x)
	west_run=float(settings.west_steps)*float(settings.west_tread)
	east_run=float(settings.east_steps)*float(settings.east_tread)
	west_y=terrain.elevation(start.x,start.y)+.03
	east_y=terrain.elevation(finish.x,finish.y)+.03
	group=Node3D.new()
	group.name="XueyuanBridge"
	host.scene.add_child(group)
	group.owner=host.scene
	group.set_meta("absolute_terrain_y",true)
	group.set_meta("osm_id",settings.osm_id)
	group.set_meta("osm_version",int(settings.osm_version))
	group.set_meta("dimensions_are_approximate",true)
	group.set_meta("static_collision_group",true)
	make_material("frame", "EDA Xueyuan bridge frame",Color("d8dbd2"),.7)
	make_material("metal", "EDA Xueyuan bridge metal",Color("9baba9"),.35)
	make_material("deck", "EDA Xueyuan bridge deck",Color("83938c"),.82)
	make_material("stairs", "EDA Xueyuan bridge steps",Color("a1a198"),.85)
	make_material("canopy", "EDA Xueyuan bridge canopy",Color("438f90"),.3)
	make_material("underdeck", "EDA Xueyuan bridge underside ribs",Color("666962"),.86)
	make_material("collision", "EDA Xueyuan bridge walking collision",Color.WHITE,1)
	var width := float(settings.deck_width)
	for i in 64:
		deck_segment(lerpf(west_run,length-east_run,float(i)/64),lerpf(west_run,length-east_run,float(i+1)/64))
	underdeck_ribs()
	flight(false)
	flight(true)
	apron(false)
	apron(true)
	var rib_count := ceili(length/float(settings.rib_spacing))
	for i in rib_count+1:
		var station := length*i/rib_count
		rib(station)
		for side in [-1.0,1.0]:
			member(Vector3(station,walk_y(station),side*(width/2+.03)),Vector3(station,walk_y(station)+1.15,side*(width/2+.03)),.055,.055,"metal")
	for i in rib_count:
		var s0 := length*i/rib_count
		var s1 := length*(i+1)/rib_count
		# Both sides remain open above the handrails, below the canopy spring.
		for side in [-1.0,1.0]:
			for h in [.25,.55,.85,1.15]:
				member(Vector3(s0,walk_y(s0)+h,side*(width/2+.03)),Vector3(s1,walk_y(s1)+h,side*(width/2+.03)),.045,.045,"metal",h==1.15)
		for segment in 16:
			var a := PI*segment/16
			var b := PI*(segment+1)/16
			canopy_panel(s0,s1,a,b)
		for angle in [0.0,PI/4,PI/2,PI*.75,PI]:
			member(roof_point(s0,angle),roof_point(s1,angle),.045,.045,"metal")
	arches()
	for key: String in surfaces:
		var st: SurfaceTool=surfaces[key]
		st.index()
		var material_key := key.get_slice(":",0)
		var node: MeshInstance3D=host.mesh_node(group,st.commit(),materials[material_key],"Bridge"+key.replace(":","_"))
		node.set_meta("walk_collision",key.ends_with(":solid"))
		if material_key=="collision": node.visible=false
	return group

func make_material(key: String, title: String, color: Color, roughness: float) -> void:
	var material: StandardMaterial3D=host.material(title,color)
	material.albedo_texture=null
	material.cull_mode=BaseMaterial3D.CULL_BACK
	material.roughness=roughness
	if key=="metal": material.metallic=.65
	if key=="canopy":
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		material.albedo_color.a=.58
	materials[key]=material

func world(p: Vector3) -> Vector3:
	var at := start+axis*p.x+across*p.z
	return Vector3(at.x,p.y,at.y)

func emit(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, key: String, solid: bool=false) -> void:
	var batch := key+(":solid" if solid else ":detail")
	if not surfaces.has(batch):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[batch]=st
	var st: SurfaceTool=surfaces[batch]
	var vertices: Array[Vector3]=[a,b,c]
	if (c-a).cross(b-a).dot(normal)<0: vertices.reverse()
	var face_normal := (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).normalized()
	var world_normal := Vector3(axis.x*face_normal.x+across.x*face_normal.z,face_normal.y,axis.y*face_normal.x+across.y*face_normal.z).normalized()
	for p in vertices:
		st.set_normal(world_normal)
		st.set_uv(Vector2(p.x,p.z+p.y))
		st.add_vertex(world(p))

func quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,n: Vector3,key: String,solid: bool=false) -> void:
	emit(a,b,c,n,key,solid)
	emit(a,c,d,n,key,solid)

func member(a: Vector3,b: Vector3,width: float,height: float,key: String,solid: bool=false) -> void:
	var tangent := (b-a).normalized()
	var sideways := tangent.cross(Vector3.UP).normalized()
	if sideways.length_squared()<.1: sideways=Vector3.FORWARD
	var vertical := sideways.cross(tangent).normalized()
	var points: Array[Vector3]=[]
	for end in [a,b]:
		for signs in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			points.append(end+sideways*signs.x*width/2+vertical*signs.y*height/2)
	for indices in [[0,1,2,3],[4,7,6,5],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]]:
		var center := Vector3.ZERO
		for index in indices: center+=points[index]/4
		quad(points[indices[0]],points[indices[1]],points[indices[2]],points[indices[3]],(center-(a+b)/2).normalized(),key,solid)

func walk_y(station: float) -> float:
	if station<west_run: return lerpf(west_y,float(profile.deck_y),clampf(station/west_run,0,1))
	if station>length-east_run: return lerpf(float(profile.deck_y),east_y,clampf((station-length+east_run)/east_run,0,1))
	var t := (station-west_run)/(length-east_run-west_run)
	return float(profile.deck_y)+4*t*(1-t)*float(profile.deck_crown_rise)

func flight(east: bool) -> void:
	var count := int(profile.east_steps if east else profile.west_steps)
	var run := east_run if east else west_run
	var toe_y := east_y if east else west_y
	var rise := (float(profile.deck_y)-toe_y)/count
	var tread := run/count
	var width := float(profile.deck_width)
	for i in count:
		var s0 := length-(i+1)*tread if east else i*tread
		var s1 := s0+tread
		var top := toe_y+rise*(i+1)
		member(Vector3(s0,top-.10,0),Vector3(s1,top-.10,0),width,.20,"stairs")
		# Pale front nosing follows the uphill direction of each flight.
		# It is a finish, not a light source or additional walking collision.
		var nose_start := s1-.045 if east else s0+.005
		member(Vector3(nose_start,top+.0015,0),Vector3(nose_start+.04,top+.0015,0),width,.003,"frame")
	# One continuous smooth surface includes both joins; visible treads do not collide.
	var s0 := length-run if east else 0.0
	var s1 := length if east else run
	member(Vector3(s0,walk_y(s0)-.22,0),Vector3(s1,walk_y(s1)-.22,0),width,.24,"stairs")
	quad(Vector3(s0,walk_y(s0),-width/2),Vector3(s1,walk_y(s1),-width/2),Vector3(s1,walk_y(s1),width/2),Vector3(s0,walk_y(s0),width/2),Vector3.UP,"collision",true)

func apron(east: bool) -> void:
	var s0 := length if east else -1.0
	var s1 := length+1.0 if east else 0.0
	var width := float(profile.deck_width)
	var points: Array[Vector3]=[]
	for p in [Vector2(s0,-width/2),Vector2(s1,-width/2),Vector2(s1,width/2),Vector2(s0,width/2)]:
		var at: Vector2 = start+axis*p.x+across*p.y
		var y: float=terrain.elevation(at.x,at.y)+.03
		if is_equal_approx(p.x,0.0): y=west_y
		if is_equal_approx(p.x,length): y=east_y
		points.append(Vector3(p.x,y,p.y))
	quad(points[0],points[1],points[2],points[3],Vector3.UP,"stairs",true)

func roof_point(station: float,angle: float) -> Vector3:
	return Vector3(station,walk_y(station)+float(profile.canopy_spring_height)+sin(angle)*float(profile.canopy_rise),cos(angle)*float(profile.canopy_half_width))

func canopy_panel(s0: float,s1: float,a: float,b: float) -> void:
	var p := roof_point(s0,a)
	var q := roof_point(s1,a)
	var r := roof_point(s1,b)
	var t := roof_point(s0,b)
	var normal := Vector3(0,sin((a+b)/2),cos((a+b)/2)).normalized()
	quad(p,q,r,t,normal,"canopy")
	# A separate inner skin has real inward winding, rather than double-sided material.
	var inset := normal*.018
	quad(p-inset,t-inset,r-inset,q-inset,-normal,"canopy")

func rib(station: float) -> void:
	# Shared cross sections close every joint around the elliptical ring.
	var center_y := walk_y(station)+1.4
	var sections:Array[Array]=[]
	for i in 64:
		var angle := TAU*i/64
		var p := Vector3(station,center_y+sin(angle)*2.08,cos(angle)*2.91)
		var normal := Vector3(0,sin(angle)/2.08,cos(angle)/2.91).normalized()
		sections.append([p+Vector3.LEFT*.09-normal*.08,p+Vector3.RIGHT*.09-normal*.08,p+Vector3.RIGHT*.09+normal*.08,p+Vector3.LEFT*.09+normal*.08])
	for i in 64:
		var a:Array=sections[i]
		var b:Array=sections[(i+1)%64]
		var angle := TAU*(i+.5)/64
		var outward_normal := Vector3(0,sin(angle)/2.08,cos(angle)/2.91).normalized()
		for side in 4:
			var normal:Vector3=[-outward_normal,Vector3.RIGHT,outward_normal,Vector3.LEFT][side]
			var next := (side+1)%4
			quad(a[side],b[side],b[next],a[next],normal,"frame")

func arch_point(t: float,side: float) -> Vector3:
	return Vector3(lerpf(west_run,length-east_run,t),float(profile.deck_y)+.3+4*t*(1-t)*float(profile.arch_rise),side*float(profile.arch_half_width))

func arches() -> void:
	for side in [-1.0,1.0]:
		for i in 64:
			member(arch_point(float(i)/64,side),arch_point(float(i+1)/64,side),.45,.8,"frame")
		for i in range(1,18):
			var t := float(i)/18
			var top := arch_point(t,side)
			for shift in [-1.0,1.0]:
				member(Vector3(top.x+shift*1.05,walk_y(top.x+shift*1.05)-.08,side*2.53),top,.028,.028,"metal")
	for i in range(2,17,2):
		var t := float(i)/18
		member(arch_point(t,-1),arch_point(t,1),.22,.24,"frame")

func deck_segment(s0: float, s1: float) -> void:
	# Shared vertical end sections keep the curved deck watertight at every station.
	var half_width := float(profile.deck_width)/2
	var thickness := float(profile.deck_thickness)
	var a := Vector3(s0,walk_y(s0),-half_width)
	var b := Vector3(s1,walk_y(s1),-half_width)
	var c := Vector3(s1,walk_y(s1),half_width)
	var d := Vector3(s0,walk_y(s0),half_width)
	var down := Vector3.DOWN*thickness
	quad(a,b,c,d,Vector3.UP,"deck",true)
	quad(a+down,d+down,c+down,b+down,Vector3.DOWN,"deck",true)
	quad(a,a+down,b+down,b,Vector3.FORWARD,"deck",true)
	quad(d,c,c+down,d+down,Vector3.BACK,"deck",true)
	if is_equal_approx(s0,west_run): quad(a,d,d+down,a+down,Vector3.LEFT,"deck",true)
	if is_equal_approx(s1,length-east_run): quad(b,b+down,c+down,c,Vector3.RIGHT,"deck",true)

func underdeck_ribs() -> void:
	var ribs: Dictionary = profile.underdeck_ribs
	var count := int(ribs.count)
	var pitch := float(ribs.pitch_m)
	var half_width := float(ribs.width_m)*0.5
	var depth := float(ribs.depth_m)
	assert((count-1)*pitch+half_width*2 < float(profile.deck_width))
	for rib in count:
		var z := (rib-(count-1)*0.5)*pitch
		var sections: Array[PackedVector3Array] = []
		for i in 65:
			var s := lerpf(west_run,length-east_run,float(i)/64)
			var top := walk_y(s)-float(profile.deck_thickness)+0.004
			sections.append(PackedVector3Array([Vector3(s,top,z-half_width),Vector3(s,top,z+half_width),Vector3(s,top-depth,z+half_width),Vector3(s,top-depth,z-half_width)]))
		for i in 64:
			var a := sections[i]
			var b := sections[i+1]
			for side in 4:
				var next := (side+1)%4
				var n: Vector3 = [Vector3.UP,Vector3.BACK,Vector3.DOWN,Vector3.FORWARD][side]
				quad(a[side],b[side],b[next],a[next],n,"underdeck")
		var first := sections[0]
		var last := sections[-1]
		quad(first[0],first[1],first[2],first[3],Vector3.LEFT,"underdeck")
		quad(last[0],last[1],last[2],last[3],Vector3.RIGHT,"underdeck")
