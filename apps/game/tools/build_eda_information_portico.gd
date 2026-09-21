extends RefCounted

func build(facade, points: PackedVector2Array, profile: Dictionary, height: float, wall: Material, trim: Material) -> Dictionary:
	var edge := int(profile.edge)
	var a := points[edge]
	var b := points[(edge+1)%points.size()]
	var axis := (b-a).normalized()
	var outward := Vector2(axis.y,-axis.x)
	assert(not Geometry2D.is_point_in_polygon((a+b)/2+outward,points))
	var finish := a.lerp(b,float(profile.end_fraction))
	var depth := float(profile.depth)
	var ceiling := float(profile.ceiling)
	# Extend the clipping rectangle beyond both exterior faces. Its rear and
	# inner side remain closed walls, so this is an outdoor recess, not a room.
	var opening := PackedVector2Array([a-axis*2+outward,finish+outward,finish-outward*depth,a-axis*2-outward*depth])
	var ground := Geometry2D.clip_polygons(points,opening)
	assert(ground.size()==1,"Information corner portico splits the ground floor")
	facade.shell(ground[0],ceiling,0,wall,"InformationGroundFloor")
	facade.shell(points,height,ceiling,wall,"InformationUpperFloors")
	var floor_rings := Geometry2D.intersect_polygons(points,opening)
	assert(floor_rings.size()==1)
	var paving: StandardMaterial3D = facade.builder.material("Information portico paving",Color("a6a397"))
	paving.albedo_texture = load("res://assets/textures/buildings/mineral_render_albedo.png")
	paving.uv1_triplanar = true
	paving.uv1_scale = Vector3.ONE*0.8
	facade.shell(floor_rings[0],0.03,-0.08,paving,"InformationPorticoFloor")
	var finish_material := ShaderMaterial.new()
	finish_material.resource_name = "Information portico small tiles"
	finish_material.shader = load("res://assets/campuses/eda/materials/academic_tile.gdshader")
	finish_material.set_shader_parameter("tile_color",Color("817c72"))
	finish_material.set_shader_parameter("pale_color",Color("817c72"))
	var finish_mesh := SurfaceTool.new()
	finish_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ground[0].size():
		var start: Vector2 = ground[0][i]
		var end: Vector2 = ground[0][(i+1)%ground[0].size()]
		var midpoint := (start+end)/2
		if midpoint.distance_to(Geometry2D.get_closest_point_to_segment(midpoint,opening[1],opening[2]))>0.002 and midpoint.distance_to(Geometry2D.get_closest_point_to_segment(midpoint,opening[2],opening[3]))>0.002: continue
		var along := (end-start).normalized()
		var normal := Vector2(along.y,-along.x)
		if Geometry2D.is_point_in_polygon(midpoint+normal*0.01,ground[0]): normal=-normal
		var vertices := [Vector3(start.x+normal.x*0.006,0.03,start.y+normal.y*0.006),Vector3(end.x+normal.x*0.006,0.03,end.y+normal.y*0.006),Vector3(end.x+normal.x*0.006,ceiling,end.y+normal.y*0.006),Vector3(start.x+normal.x*0.006,ceiling,start.y+normal.y*0.006)]
		var uv := [Vector2.ZERO,Vector2(start.distance_to(end),0),Vector2(start.distance_to(end),ceiling-0.03),Vector2(0,ceiling-0.03)]
		var order := [0,1,2,0,2,3]
		if (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).dot(Vector3(normal.x,0,normal.y))<0: order=[0,2,1,0,3,2]
		for index in order:
			finish_mesh.set_uv(uv[index])
			finish_mesh.add_vertex(vertices[index])
	finish_mesh.generate_normals()
	finish_mesh.index()
	var finish_node: MeshInstance3D = facade.builder.mesh_node(facade.group,finish_mesh.commit(),finish_material,"InformationPorticoFinish")
	finish_node.set_meta("walk_collision",false)
	# The general building shell has no underside; the exposed soffit needs
	# its own downward-facing surface and collision.
	var soffit := SurfaceTool.new()
	soffit.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := Geometry2D.triangulate_polygon(floor_rings[0])
	for i in range(0,triangles.size(),3):
		var vertices: Array[Vector3] = []
		for j in 3:
			var p := floor_rings[0][triangles[i+j]]
			vertices.append(Vector3(p.x,ceiling,p.y))
		if (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).y>0: vertices.reverse()
		for vertex in vertices: soffit.add_vertex(vertex)
	soffit.generate_normals()
	soffit.index()
	var soffit_node: MeshInstance3D = facade.builder.mesh_node(facade.group,soffit.commit(),trim,"InformationPorticoSoffit")
	soffit_node.set_meta("walk_collision",true)
	var column_at := a+axis*0.25-outward*0.25
	var column_width := float(profile.column_width)
	var column: MeshInstance3D = facade.builder.box(facade.group,Vector3(column_at.x,ceiling/2,column_at.y),Vector3(column_width,ceiling,column_width),trim,"InformationCornerColumn")
	column.rotation.y = -atan2(axis.y,axis.x)
	column.set_meta("walk_collision",true)
	var exclusions: Dictionary = {}
	for i in points.size():
		var start := points[i]
		var end := points[(i+1)%points.size()]
		var fractions: Array[float] = []
		if Geometry2D.is_point_in_polygon(start,opening): fractions.append(0.0)
		if Geometry2D.is_point_in_polygon(end,opening): fractions.append(1.0)
		for j in opening.size():
			var hit = Geometry2D.segment_intersects_segment(start,end,opening[j],opening[(j+1)%opening.size()])
			if hit!=null: fractions.append(start.distance_to(hit)/start.distance_to(end))
		if fractions.size()>=2:
			exclusions[i] = Vector2(fractions.min(),fractions.max())
	return exclusions
