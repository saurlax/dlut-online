extends RefCounted

func build(host) -> void:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/buildings/academic_facades.json"))
	var profile: Dictionary = profiles["77925"].osm_registration.entry
	var feature: Dictionary = {}
	for candidate: Dictionary in host.manifest.features:
		if candidate.id=="77925": feature=candidate
	assert(not feature.is_empty())
	var edge := int(profile.edge)
	var a := Vector2(feature.points[edge][0],feature.points[edge][1])
	var b := Vector2(feature.points[edge+1][0],feature.points[edge+1][1])
	var center := a.lerp(b,float(profile.fraction))
	var axis := (b-a).normalized()
	var outward := Vector2(axis.y,-axis.x)
	var width := float(profile.canopy_width)
	var depth := float(profile.canopy_projection)
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	var columns := ceili(width/0.5)
	var rows := ceili(depth/0.5)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in columns:
		for j in rows:
			var x0 := -width/2+width*i/columns
			var x1 := -width/2+width*(i+1)/columns
			var z0 := depth*j/rows
			var z1 := depth*(j+1)/rows
			var uv := [Vector2(x0,z0),Vector2(x1,z0),Vector2(x1,z1),Vector2(x0,z1)]
			for triangle in [[0,2,1],[0,3,2]]:
				for index in triangle:
					var p: Vector2 = center+axis*uv[index].x+outward*uv[index].y
					surface.set_uv(uv[index])
					surface.add_vertex(Vector3(p.x,terrain.elevation(p.x,p.y)+0.018,p.y))
	surface.generate_normals()
	surface.index()
	var material := ShaderMaterial.new()
	material.resource_name="Academic A covered entry paving"
	material.shader=load("res://assets/campuses/eda/materials/ground.gdshader")
	material.set_shader_parameter("surface_kind",4)
	material.set_shader_parameter("base_color",Color("91978e"))
	var node: MeshInstance3D = host.mesh_node(host.scene,surface.commit(),material,"AcademicEntryPaving")
	node.set_meta("walk_collision",true)
	node.set_meta("dimensions_are_approximate",true)
