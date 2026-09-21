extends RefCounted

func build(facade, points: PackedVector2Array, markers: Array) -> void:
	var red: Material = facade.host.material("EDA residence number red",Color("a94559"))
	red.albedo_texture = null
	for marker in markers:
		facade.facade_path = preload("res://tools/residence_facade_path.gd").new()
		facade.facade_path.configure(points,marker.vertices)
		var path = facade.facade_path
		var at: Vector2 = path.origin+path.axis*path.length*float(marker.fraction)
		var normal := Vector3(path.outward.x,0,path.outward.y)
		var horizontal := Vector3(path.outward.y,0,-path.outward.x)
		var diameter: float = marker.diameter
		for ring in [[diameter/2.0,0.04,0.28,facade.rail],[diameter/2.0-0.035,0.025,0.308,facade.frame]]:
			var disk := CylinderMesh.new()
			disk.top_radius=ring[0]; disk.bottom_radius=ring[0]; disk.height=ring[1]
			disk.radial_segments=48
			var node: MeshInstance3D=facade.host.mesh_node(facade.group,disk,ring[3],"ResidenceNumberPlate")
			node.basis=Basis(horizontal,normal,horizontal.cross(normal))
			node.position=Vector3(at.x,float(marker.center_y),at.y)+normal*float(ring[2])
			node.set_meta("walk_collision",false)
			path.deform(node)
		var text := TextMesh.new()
		text.font=load("res://assets/fonts/CampusSans.ttf")
		text.text=str(marker.text); text.font_size=64; text.pixel_size=0.012
		text.depth=0.012; text.curve_step=0.5
		text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		var bounds := text.get_aabb()
		var letter_scale: float = diameter*0.78/bounds.size.y
		var baked:=SurfaceTool.new()
		baked.append_from(text,0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*letter_scale),-bounds.get_center()*letter_scale))
		baked.index()
		var letter: MeshInstance3D=facade.host.mesh_node(facade.group,baked.commit(),red,"ResidenceNumberLetter")
		letter.basis=Basis(horizontal,Vector3.UP,normal)
		letter.position=Vector3(at.x,float(marker.center_y),at.y)+normal*0.337
		letter.set_meta("walk_collision",false)
		path.deform(letter)
