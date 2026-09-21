extends RefCounted

var host
var group: Node3D
var registration: Dictionary = {}
var osm_points := PackedVector2Array()

func south_z(x: float) -> float:
	return -15.255+(x+362.382)*(-3.469/101.256)

func mapped(vertex: Vector3) -> Vector3:
	var west: float = registration.wall_frame.west_x
	var east: float = registration.wall_frame.east_x
	var north: float = registration.wall_frame.north_z
	var u := (vertex.x-west)/(east-west)
	var v := (vertex.z-north)/(south_z(vertex.x)-north)
	var top := osm_points[0].lerp(osm_points[3],u)
	var bottom := osm_points[1].lerp(osm_points[2],u)
	var point := top.lerp(bottom,v)
	return Vector3(point.x,vertex.y,point.y)

func register_details(base_node: MeshInstance3D) -> void:
	for node: MeshInstance3D in group.get_children():
		if node==base_node: continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_smooth_group(-1)
		for vertex: Vector3 in node.mesh.get_faces():
			surface.add_vertex(mapped(node.transform*vertex))
		surface.generate_normals()
		surface.index()
		node.mesh = surface.commit()
		node.transform = Transform3D.IDENTITY

func roof_y(x: float) -> float:
	var t := clampf((x+379.0)/125.0,0.0,1.0)
	return 13.5+3.5*pow(2.0*t-1.0,2)

func box(at: Vector3, size: Vector3, mat: Material, solid := false) -> MeshInstance3D:
	var node: MeshInstance3D = host.box(group,at,size,mat,"GymDetail")
	node.set_meta("walk_collision",solid)
	return node

func surface(vertices: Array, mat: Material, solid := true) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in vertices: st.add_vertex(vertex)
	st.generate_normals()
	st.index()
	var node: MeshInstance3D = host.mesh_node(group,st.commit(),mat,"GymShell")
	node.set_meta("walk_collision",solid)

func quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,mat: Material,solid := true) -> void:
	surface([a,b,c,a,c,d],mat,solid)

func north_columns(steel: Material) -> void:
	# Bounded visible row; stations and diameter are proportional estimates.
	assert(not registration.is_empty())
	var west: float = registration.wall_frame.west_x
	var east: float = registration.wall_frame.east_x
	var north: float = registration.wall_frame.north_z
	for station in [0.18,0.29,0.40,0.51,0.62]:
		var x := lerpf(east,west,station)
		var top := roof_y(x)-0.45
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.11
		mesh.bottom_radius = 0.11
		mesh.height = top-3.0
		mesh.radial_segments = 24
		mesh.rings = 1
		var node: MeshInstance3D = host.mesh_node(group,mesh,steel,"GymNorthColumn")
		node.position = Vector3(x,(top+3.0)*0.5,north-0.8)
		node.set_meta("walk_collision",true)

func build(builder, parent: Node3D, points: PackedVector2Array, osm_registration: Dictionary = {}) -> void:
	host = builder
	group = parent
	registration = osm_registration
	osm_points = points
	group.set_meta("photo_reference","references/eda/buildings/gym_profile.json")
	group.set_meta("interior_available",false)
	var base: Material = host.material("EDA gym stone",Color("88897e"))
	var wall: Material = host.material("EDA gym pale wall",Color("b3b7aa"))
	var roof: Material = host.material("EDA gym metal roof",Color("7c9697"))
	var steel: Material = host.material("EDA gym steel",Color("c5ceca"))
	var glass: Material = host.material("EDA gym opaque glazing",Color("577a79"))
	for mat in [base,wall,roof,steel,glass]: mat.albedo_texture = null
	roof.metallic = 0.5
	glass.metallic = 0.3
	glass.roughness = 0.3
	# The registered source footprint is the base; roof overhangs are separate.
	host.polygon(group,points,3.0,base,"GymBase")
	var base_node: MeshInstance3D = group.get_child(group.get_child_count()-1)
	var indexed := SurfaceTool.new()
	indexed.create_from(base_node.mesh,0)
	indexed.index()
	base_node.mesh = indexed.commit()
	base_node.set_meta("walk_collision",true)
	var body := PackedVector2Array()
	if registration.is_empty():
		var clip := PackedVector2Array([Vector2(-400,-110),Vector2(-262,-110),Vector2(-262,0),Vector2(-400,0)])
		var parts := Geometry2D.intersect_polygons(points,clip)
		assert(parts.size()==1)
		body = parts[0]
	else:
		var west: float = registration.wall_frame.west_x
		var east: float = registration.wall_frame.east_x
		var north: float = registration.wall_frame.north_z
		body = PackedVector2Array([Vector2(west,north),Vector2(west,south_z(west)),Vector2(east,south_z(east)),Vector2(east,north)])
	for i in body.size():
		var p := body[i]
		var q := body[(i+1)%body.size()]
		var segments := maxi(1,ceili(p.distance_to(q)/3.0))
		for j in segments:
			var a := p.lerp(q,float(j)/segments)
			var b := p.lerp(q,float(j+1)/segments)
			quad(Vector3(a.x,3,a.y),Vector3(b.x,3,b.y),Vector3(b.x,roof_y(b.x)-0.5,b.y),Vector3(a.x,roof_y(a.x)-0.5,a.y),wall)
	# Cylindrical sagging roof, discretized only along its long axis.
	var skylights = preload("res://tools/build_eda_gym_skylights.gd").new()
	for i in 50:
		var a := -379.0+i*2.5
		var b := a+2.5
		skylights.segment(self,a,b,roof)
		for z in [-90.0,-12.0]:
			quad(Vector3(a,roof_y(a),z),Vector3(b,roof_y(b),z),Vector3(b,roof_y(b)-0.45,z),Vector3(a,roof_y(a)-0.45,z),steel)
	for x in [-379.0,-254.0]:
		box(Vector3(x,roof_y(x)-0.225,-51),Vector3(0.15,0.45,78),steel,true)
	skylights.reveals(self,steel)
	# East frontage and the visible south side are independently referenced.
	box(Vector3(-261.9,8.6,-50),Vector3(0.12,11.2,51),glass)
	for i in 24:
		box(Vector3(-261.75,8.6,-75.5+i*51.0/23.0),Vector3(0.18,11.3,0.07),steel)
	for y in [3.0,4.4,5.8,7.2,8.6,10.0,11.2,12.7,14.2]:
		box(Vector3(-261.75,y,-50),Vector3(0.18,0.08,51),steel)
	for i in 8:
		var z := -75.5+i*51.0/7.0
		var top := roof_y(-260.7)-0.45
		box(Vector3(-260.7,(top+10.75)/2,z),Vector3(0.65,top-10.75,0.65),steel,true)
		var beam := box(Vector3(-257.9,(roof_y(-261.2)+roof_y(-254.6))/2-0.7,z),Vector3(6.6,0.5,0.65),steel,true)
		beam.rotation.z = atan((roof_y(-254.6)-roof_y(-261.2))/6.6)
	# Entry surround is kept closed pending calibrated stairs and platform.
	box(Vector3(-261.5,5.2,-50),Vector3(0.65,4.4,33),base,true)
	preload("res://tools/build_eda_gym_entry.gd").new().build(self,glass,steel,base)
	for i in 11:
		var x := -370.0+i*9.5
		var z := -15.255+(x+362.382)*(-3.469/101.256)
		box(Vector3(x,7.2,z+0.08),Vector3(8.6,6.5,0.1),glass).rotation.y = atan(3.469/101.256)
		box(Vector3(x,7.2,z+0.2),Vector3(0.08,6.5,0.12),steel).rotation.y = atan(3.469/101.256)
		box(Vector3(x,6.0,z+0.2),Vector3(8.6,0.08,0.12),steel).rotation.y = atan(3.469/101.256)
		box(Vector3(x,9.0,z+0.2),Vector3(8.6,0.08,0.12),steel).rotation.y = atan(3.469/101.256)
		var h := roof_y(x)-3.45
		box(Vector3(x,3+h/2,z+1.0),Vector3(0.3,h,0.3),steel,true)

	if not registration.is_empty(): north_columns(steel)
	# Six visible roof posts; cable attachment topology remains unverified.
	var profile_path := ProjectSettings.globalize_path("res://").path_join("../../references/eda/buildings/gym_profile.json").simplify_path()
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	var posts: Dictionary = profiles["77923"].roof_posts
	for i in posts.z.size():
		var x: float = posts.x
		var base_y := roof_y(x)
		var top_y := float(posts.tops[i])
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = float(posts.bottom_radius)
		mesh.top_radius = float(posts.top_radius)
		mesh.height = top_y-base_y
		mesh.radial_segments = 12
		mesh.rings = 1
		var node: MeshInstance3D = host.mesh_node(group,mesh,steel,"GymRoofPost")
		node.position = Vector3(x,(base_y+top_y)/2,float(posts.z[i]))
		node.set_meta("walk_collision",true)
	skylights.dividers(self,steel)
	if not registration.is_empty():
		register_details(base_node)
		group.set_meta("osm_facade_registration",registration.osm_id)
	for index in group.get_child_count():
		var node: MeshInstance3D = group.get_child(index)
		preload("res://tools/eda_surface_details.gd").tint_glazing(node,node.material_override,float(index),8.6)
