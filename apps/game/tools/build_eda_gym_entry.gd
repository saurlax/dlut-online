extends RefCounted

func build(facade, glass: Material, steel: Material, stone: Material) -> void:
	var joints: StandardMaterial3D = facade.host.material("EDA gym entry panel joints",Color("50595c"))
	joints.albedo_texture=null
	joints.roughness=0.9
	var gold: StandardMaterial3D=facade.host.material("EDA gym gold lettering",Color("b7a268"))
	gold.albedo_texture=null
	gold.metallic=0.7
	gold.roughness=0.36
	var lettering:=TextMesh.new()
	lettering.font=load("res://assets/fonts/CampusSans.ttf")
	lettering.font_size=32
	lettering.curve_step=1.0
	lettering.pixel_size=0.048
	lettering.depth=0.055
	lettering.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	lettering.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	lettering.text="体育馆"
	var baked:=SurfaceTool.new()
	baked.create_from(lettering,0)
	baked.index()
	var sign:MeshInstance3D=facade.host.mesh_node(facade.group,baked.commit(),gold,"GymLettering")
	sign.rotation.y=PI/2
	sign.position=Vector3(-261.0,6.4,-50)
	sign.set_meta("walk_collision",false)
	# The shallow header and side returns frame the closed entrance glazing.
	facade.box(Vector3(-260.87,5.38,-50),Vector3(0.62,0.36,24.0),stone)
	for z in [-61.85,-38.15]:
		facade.box(Vector3(-260.87,4.1,z),Vector3(0.62,2.2,0.3),stone)
	var openings := [Vector2(-61.5,-56.3),Vector2(-54.9,-45.1),Vector2(-43.7,-38.5)]
	for span in openings:
		facade.box(Vector3(-261.1,4.1,(span.x+span.y)/2),Vector3(0.1,2.2,span.y-span.x),glass)
	# Thin joints on the existing grey surround, excluding the three glazed groups.
	for i in range(1,33):
		var z := -66.5+i
		var bottom := 3.0
		for opening in openings:
			if z>opening.x and z<opening.y: bottom=5.2
		facade.box(Vector3(-261.16,(bottom+7.4)/2,z),Vector3(0.025,7.4-bottom,0.012),joints)
	for row in range(1,8):
		var y := 3.0+row*0.55
		var spans := [Vector2(-66.5,-33.5)] if y>5.2 else [Vector2(-66.5,-61.5),Vector2(-56.3,-54.9),Vector2(-45.1,-43.7),Vector2(-38.5,-33.5)]
		for span in spans:
			facade.box(Vector3(-261.16,y,(span.x+span.y)/2),Vector3(0.025,0.012,span.y-span.x),joints)
	for bank in 3:
		var span: Vector2 = openings[bank]
		var width := span.y-span.x
		var columns := 8 if bank==1 else 4
		for i in columns+1:
			facade.box(Vector3(-260.97,4.1,span.x+width*i/columns),Vector3(0.12,2.2,0.055),steel)
		for y in [3.0,4.85,5.2]:
			facade.box(Vector3(-260.97,y,(span.x+span.y)/2),Vector3(0.12,0.055,width),steel)
		if bank==1:
			facade.box(Vector3(-260.97,4.1,(span.x+span.y)/2),Vector3(0.12,0.055,width),steel)
		else:
			for pair in 2:
				var z := span.x+width*(pair*2+1)/4
				for side in [-1.0,1.0]:
					facade.box(Vector3(-260.87,3.95,z+side*0.12),Vector3(0.035,0.55,0.025),steel)
