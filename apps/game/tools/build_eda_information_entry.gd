extends RefCounted

var facade
var builder
var group: Node3D
var center: Vector2
var axis: Vector2
var outward: Vector2

func point(x: float, y: float, z: float) -> Vector3:
	var p := center+axis*x+outward*z
	return Vector3(p.x,y,p.y)

func block(x: float, y: float, z: float, size: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var node: MeshInstance3D = builder.box(group,point(x,y,z),size,material,"InformationEntry")
	node.rotation.y = -atan2(axis.y,axis.x)
	node.set_meta("walk_collision",solid)
	return node

func build(host, points: PackedVector2Array, profile: Dictionary) -> void:
	facade = host
	builder = facade.builder
	group = facade.group
	var a := points[int(profile.edge)]
	var b := points[(int(profile.edge)+1)%points.size()]
	axis = (b-a).normalized()
	outward = Vector2(axis.y,-axis.x)
	center = a.lerp(b,(float(profile.span[0])+float(profile.span[1]))/2)
	assert(not Geometry2D.is_point_in_polygon(center+outward,points))
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	var base_y := float(terrain.data.feature_base_y[String(group.name)])
	var landing := float(profile.landing_height)
	var depth := float(profile.landing_depth)
	var width := float(profile.stair_width)
	var count := int(profile.steps)
	var tread := float(profile.tread)
	var toe := depth+count*tread
	var low := -INF
	for x in [-width/2,0.0,width/2]:
		var p := point(x,0,toe)
		low = maxf(low,terrain.elevation(p.x,p.z)-base_y)
	low += 0.02
	var riser := (landing-low)/count
	assert(riser>0.10 and riser<0.23,"Entry stairs need a terrain/height review")
	var stone: StandardMaterial3D = builder.material("Information entry stone",Color("aba597"))
	stone.albedo_texture = load("res://assets/textures/buildings/mineral_render_albedo.png")
	stone.uv1_scale = Vector3.ONE*0.5
	var metal: StandardMaterial3D = builder.material("Information entry stainless",Color("a0acac"))
	metal.albedo_texture = null
	metal.metallic = 0.7
	metal.roughness = 0.3
	var glass: StandardMaterial3D = builder.material("Information entry glazing",Color("365968"))
	glass.albedo_texture = null
	glass.metallic = 0.55
	glass.roughness = 0.2
	# Exterior landing and closed facade only; no interior is inferred.
	block(0,(landing+low-0.3)/2,depth/2,Vector3(width,landing-low+0.3,depth),stone,true)
	for step in count:
		var top := low+riser*(step+1)
		block(0,(top+low-0.3)/2,toe-(step+0.5)*tread,Vector3(width,top-low+0.3,tread),stone)
	# A separate invisible walk surface avoids vertical risers snagging the
	# shared capsule controller. Visual steps remain independent of collision.
	var collision_material: StandardMaterial3D = builder.material("Information stair collision",Color.WHITE)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var strips: Array[PackedVector3Array] = []
	strips.append(PackedVector3Array([point(-width/2,low+riser,toe),point(width/2,low+riser,toe),point(width/2,landing,depth),point(-width/2,landing,depth)]))
	for i in 14:
		var left := -width/2+i*width/14
		var right := -width/2+(i+1)*width/14
		var p := point(left,0,toe+0.7)
		var q := point(right,0,toe+0.7)
		p.y = terrain.elevation(p.x,p.z)-base_y+0.01
		q.y = terrain.elevation(q.x,q.z)-base_y+0.01
		strips.append(PackedVector3Array([p,q,point(right,low+riser,toe),point(left,low+riser,toe)]))
	for strip in strips:
		for indices in [[0,1,2],[0,2,3]]:
			var p := strip[indices[0]]
			var q := strip[indices[1]]
			var r := strip[indices[2]]
			st.add_vertex(p)
			if (q-p).cross(r-p).y>0:
				st.add_vertex(r)
				st.add_vertex(q)
			else:
				st.add_vertex(q)
				st.add_vertex(r)
	st.generate_normals()
	var ramp: MeshInstance3D = builder.mesh_node(group,st.commit(),collision_material,"InformationStairCollision")
	ramp.visible = false
	ramp.set_meta("walk_collision",true)
	var tubes := preload("res://tools/build_eda_goals.gd").new()
	for x in [-width/2+0.2,width/2-0.2]:
		for height in [0.45,0.75,1.05]:
			tubes.tube(builder,group,point(x,low+riser+height,toe-tread/2),point(x,landing+height,depth),0.022,metal)
			tubes.tube(builder,group,point(x,landing+height,depth),point(x,landing+height,0.6),0.022,metal)
		for step in range(0,count,4):
			var z := toe-(step+0.5)*tread
			var y := low+riser*(step+1)
			tubes.tube(builder,group,point(x,y,z),point(x,y+1.05,z),0.025,metal)
		for z in [0.6,depth]:
			tubes.tube(builder,group,point(x,landing,z),point(x,landing+1.05,z),0.025,metal)
	var first := a.lerp(b,float(profile.span[0]))+outward*0.22
	var last := a.lerp(b,float(profile.span[1]))+outward*0.22
	var glass_height := float(profile.glass_top)-landing
	var columns := int(profile.glass_columns)
	var rows := int(profile.glass_rows)
	for column in columns:
		for row in rows:
			facade.edge_box(first.lerp(last,float(column)/columns),first.lerp(last,float(column+1)/columns),landing+glass_height*(row+0.5)/rows,glass_height/rows,0.08,glass)
	for column in columns+1:
		var p := first.lerp(last,float(column)/columns)+outward*0.06
		facade.edge_box(p-axis*0.025,p+axis*0.025,landing+glass_height/2,glass_height,0.1,metal)
	for row in rows+1:
		facade.edge_box(first+outward*0.06,last+outward*0.06,landing+glass_height*row/rows,0.04,0.1,metal)
	# Four closed double-door frames, with separate narrow pull handles.
	for door in 9:
		block(-4.4+door*1.1,landing+1.3,0.36,Vector3(0.065,2.6,0.12),metal)
	block(0,landing+2.6,0.36,Vector3(8.9,0.08,0.12),metal)
	for pair in 4:
		for offset in [-0.13,0.13]:
			block(-3.3+pair*2.2+offset,landing+1.2,0.47,Vector3(0.025,0.65,0.055),metal)
	var canopy_y := float(profile.canopy_height)
	var canopy_width := float(profile.canopy_width)
	var canopy_depth := float(profile.canopy_depth)
	var canopy: StandardMaterial3D = builder.material("Information canopy glass",Color("89a4a0"))
	canopy.albedo_texture = null
	canopy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	canopy.albedo_color.a = 0.55
	canopy.metallic = 0.4
	canopy.roughness = 0.25
	block(0,canopy_y,canopy_depth/2,Vector3(canopy_width,0.07,canopy_depth),canopy,true)
	for i in 9:
		var x := -canopy_width/2+i*canopy_width/8
		block(x,canopy_y-0.07,canopy_depth/2,Vector3(0.065,0.12,canopy_depth),metal)
		if i%2==0: tubes.tube(builder,group,point(x,canopy_y+2.1,0.3),point(x,canopy_y,canopy_depth-0.15),0.018,metal,false)
	for z in [0.35,canopy_depth/2,canopy_depth]:
		block(0,canopy_y-0.07,z,Vector3(canopy_width,0.12,0.065),metal)
	var sign: StandardMaterial3D = builder.material("Information entry display",Color("191d20"))
	sign.albedo_texture = null
	block(0,canopy_y-0.38,canopy_depth,Vector3(canopy_width,0.55,0.18),sign)
