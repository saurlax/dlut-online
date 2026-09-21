extends RefCounted

func build(facade, points: PackedVector2Array, profile: Dictionary) -> void:
	var gold: StandardMaterial3D=facade.builder.material("Library gold lettering",Color("b7a268"))
	gold.albedo_texture=null
	gold.metallic=0.7
	gold.roughness=0.36
	var pale: StandardMaterial3D=facade.builder.material("Library sign header",Color("c4c4b9"))
	pale.albedo_texture=null
	var tile := ShaderMaterial.new()
	tile.resource_name="Library east sign tiles"
	tile.shader=load("res://assets/campuses/eda/materials/academic_tile.gdshader")
	tile.set_shader_parameter("tile_color",Color("69716d"))
	tile.set_shader_parameter("pale_color",Color("69716d"))
	for face in profile.faces:
		var a := points[int(face.edge)]
		var b := points[(int(face.edge)+1)%points.size()]
		var axis := (b-a).normalized()
		var out := Vector2(axis.y,-axis.x)
		if Geometry2D.is_point_in_polygon((a+b)/2+out,points): out=-out
		var p := a.lerp(b,float(face.fraction))
		if face.vertical:
			var half := float(face.pier_width)/2
			var first := p-axis*half+out*0.04
			var last := p+axis*half+out*0.04
			var vertices := [Vector3(first.x,0.3,first.y),Vector3(last.x,0.3,last.y),Vector3(last.x,17.1,last.y),Vector3(first.x,17.1,first.y)]
			var uv := [Vector2.ZERO,Vector2(half*2,0),Vector2(half*2,16.8),Vector2(0,16.8)]
			var order := [0,1,2,0,2,3]
			if (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).dot(Vector3(out.x,0,out.y))<0: order=[0,2,1,0,3,2]
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in order:
				st.set_uv(uv[i]);st.add_vertex(vertices[i])
			st.generate_normals();st.index()
			var panel: MeshInstance3D=facade.builder.mesh_node(facade.group,st.commit(),tile,"LibrarySignPier")
			panel.set_meta("walk_collision",false)
			for y in [8.8,13.2]:
				facade.edge_box(first,last,y,0.16,0.03,pale)
		else:
			var half := float(face.header_width)/2
			facade.edge_box(p-axis*half+out*0.12,p+axis*half+out*0.12,float(face.y),1.05,0.12,pale)
		var text := TextMesh.new()
		text.font=load("res://assets/fonts/CampusSans.ttf")
		text.font_size=32
		text.curve_step=1.0
		text.pixel_size=float(face.pixel_size)*4
		text.depth=0.055
		text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		text.text="图\n书\n馆" if face.vertical else "图书馆"
		var baked := SurfaceTool.new()
		baked.create_from(text,0)
		baked.index()
		var node: MeshInstance3D=facade.builder.mesh_node(facade.group,baked.commit(),gold,"LibraryLetters")
		node.basis=Basis(Vector3(out.y,0,-out.x),Vector3.UP,Vector3(out.x,0,out.y))
		p+=out*(0.13 if face.vertical else 0.24)
		node.position=Vector3(p.x,float(face.y),p.y)
		node.set_meta("walk_collision",false)
