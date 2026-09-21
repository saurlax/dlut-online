extends RefCounted

func build(host) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/vegetation.json"))
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	preload("res://tools/build_eda_court_paving.gd").new().build(host,terrain,data)
	var stone: StandardMaterial3D = host.material("EDA courtyard tree pit edging",Color("a39b82"))
	var cover: StandardMaterial3D = host.material("EDA courtyard tree pit cover",Color("8d9184"))
	for mat in [stone,cover]:
		mat.albedo_texture = load("res://assets/textures/buildings/mineral_render_albedo.png")
		mat.uv1_scale = Vector3.ONE*0.8
	var axis := Vector2(0.0,-1.0)
	for zone: Dictionary in data.linear_zones:
		if zone.id != "academic-c-west-ginkgo-rows": continue
		axis = (Vector2(zone.expected_points[1][0],zone.expected_points[1][1])-Vector2(zone.expected_points[0][0],zone.expected_points[0][1])).normalized()
	var side := Vector2(-axis.y,axis.x)
	for plant: Dictionary in data.instances:
		if plant.zone != "academic-c-west-ginkgo-rows": continue
		var center := Vector2(plant.position[0],plant.position[2])
		# 1.8 m outer square, four edging stones and four removable cover pieces.
		# Heights and dimensions are visual estimates; each corner follows terrain.
		for rect in [Rect2(-0.9,-0.9,1.8,0.12),Rect2(-0.9,0.78,1.8,0.12),Rect2(-0.9,-0.78,0.12,1.56),Rect2(0.78,-0.78,0.12,1.56)]:
			patch(host,terrain,center,axis,side,rect,0.10,stone)
		for sx in [-1.0,1.0]:
			for sz in [-1.0,1.0]:
				# L-shaped quarter, central trunk opening and three through-slots.
				# Slot dimensions (25 x 180 mm) are visual estimates.
				for rect in [Rect2(0.018,0.22,0.202,0.545),Rect2(0.22,0.018,0.545,0.382),Rect2(0.22,0.58,0.545,0.185),Rect2(0.22,0.4,0.14,0.18),Rect2(0.385,0.4,0.065,0.18),Rect2(0.475,0.4,0.065,0.18),Rect2(0.565,0.4,0.2,0.18)]:
					patch(host,terrain,center,axis*sx,side*sz,rect,0.035,cover)
				rounded_opening(host,terrain,center,axis*sx,side*sz,cover)

func rounded_opening(host, terrain, center: Vector2, axis: Vector2, side: Vector2, material: Material) -> void:
	# Complete each inner corner around an approximately 0.44 m circular hole.
	# Keep the existing 36 mm joints between the four removable cover pieces.
	var radius := 0.22
	var gap := 0.018
	var local := PackedVector2Array([Vector2(gap,radius),Vector2(radius,radius),Vector2(radius,gap)])
	var start := asin(gap/radius)
	for i in range(1,12):
		var angle := lerpf(start,PI/2-start,i/12.0)
		local.append(Vector2(cos(angle),sin(angle))*radius)
	var corners := PackedVector2Array()
	for p in local: corners.append(center+axis*p.x+side*p.y)
	surface(host,terrain,corners,0.035,material)

func patch(host, terrain, center: Vector2, axis: Vector2, side: Vector2, rect: Rect2, height: float, material: Material) -> void:
	var corners := PackedVector2Array()
	for p in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:
		corners.append(center+axis*p.x+side*p.y)
	surface(host,terrain,corners,height,material)

func surface(host, terrain, corners: PackedVector2Array, height: float, material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var indices := Geometry2D.triangulate_polygon(corners)
	for i in range(0,indices.size(),3):
		var verts: Array[Vector3] = []
		for j in 3:
			var p := corners[indices[i+j]]
			verts.append(Vector3(p.x,terrain.elevation(p.x,p.y)+height,p.y))
		if (verts[2]-verts[0]).cross(verts[1]-verts[0]).y<0: verts.reverse()
		for v in verts:
			st.set_uv(Vector2(v.x,v.z))
			st.add_vertex(v)
	# Vertical sides close the raised edging against the ground.
	for i in corners.size():
		var a := corners[i]
		var b := corners[(i+1)%corners.size()]
		var low_a := Vector3(a.x,terrain.elevation(a.x,a.y)-0.01,a.y)
		var low_b := Vector3(b.x,terrain.elevation(b.x,b.y)-0.01,b.y)
		var vertices: Array[Vector3] = [low_a,low_b,low_b+Vector3.UP*(height+0.01),low_a,low_b+Vector3.UP*(height+0.01),low_a+Vector3.UP*(height+0.01)]
		var front := (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).normalized()
		var inward := Geometry2D.is_point_in_polygon((a+b)*0.5+Vector2(front.x,front.z)*0.001,corners)
		for triangle in 2:
			var face := vertices.slice(triangle*3,triangle*3+3)
			if inward: face.reverse()
			for v: Vector3 in face:
				st.set_uv(Vector2(v.x+v.z,v.y))
				st.add_vertex(v)
	st.generate_normals()
	host.mesh_node(host.scene,st.commit(),material,"CourtyardTreePit")
	host.scene.get_child(host.scene.get_child_count()-1).set_meta("walk_collision",true)
