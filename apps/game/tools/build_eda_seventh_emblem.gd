extends RefCounted

func build(facade, x: float, y: float, diameter: float) -> void:
	var material := StandardMaterial3D.new()
	material.resource_name = "Seventh blue and white emblem"
	material.albedo_texture = load("res://assets/textures/buildings/dut_emblem.svg")
	material.roughness = 0.42
	material.metallic = 0.2
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axis := Vector3(facade.path.axis.x,0,facade.path.axis.y)
	var outward := Vector3(facade.path.outward.x,0,facade.path.outward.y)
	var ground: Vector2 = facade.path.origin+facade.path.axis*x+facade.path.outward*0.28
	var center := Vector3(ground.x,y,ground.y)
	axis = (facade.path.mapped(center+axis*0.1)-facade.path.mapped(center-axis*0.1)).normalized()
	outward = (facade.path.mapped(center+outward*0.1)-facade.path.mapped(center)).normalized()
	center = facade.path.mapped(center)
	# A rigid circular sign stands in front of the bent facade grille.
	for i in 96:
		var a := Vector2(cos(TAU*i/96.0),sin(TAU*i/96.0))
		var b := Vector2(cos(TAU*(i+1)/96.0),sin(TAU*(i+1)/96.0))
		if axis.cross(Vector3.UP).dot(outward)>0:
			var swap := a
			a=b
			b=swap
		for p in [Vector2.ZERO,a,b]:
			surface.set_normal(outward)
			surface.set_uv(Vector2(0.5+p.x*0.5,0.5-p.y*0.5))
			surface.add_vertex(center+(axis*p.x+Vector3.UP*p.y)*diameter*0.5)
	surface.index()
	var node: MeshInstance3D = facade.host.mesh_node(facade.group,surface.commit(),material,"SeventhEmblem")
	node.set_meta("walk_collision",false)
