extends RefCounted

func build(facade, points: PackedVector2Array, profile: Dictionary, ceiling: float) -> void:
	var path = preload("res://tools/residence_facade_path.gd").new()
	path.configure(points,profile.facade_vertices)
	var arcade: Dictionary = profile.ground_arcade
	var first: float = path.length*float(arcade.span[0])
	var last: float = path.length*float(arcade.span[1])
	var stations: Array[float] = [first]
	for station in path.stations:
		if station>first and station<last: stations.append(station)
	stations.append(last)
	var opening := PackedVector2Array()
	for offset in [0.5,-float(arcade.depth)]:
		var ordered := stations.duplicate()
		if offset<0: ordered.reverse()
		for station in ordered:
			var p: Vector2 = path.origin+path.axis*station+path.outward*offset
			var mapped: Vector3 = path.mapped(Vector3(p.x,0,p.y))
			opening.append(Vector2(mapped.x,mapped.z))
	var ground := Geometry2D.clip_polygons(points,opening)
	var floors := Geometry2D.intersect_polygons(points,opening)
	assert(ground.size()==1 and floors.size()==1,"Residence arcade must remain a single outdoor recess")
	facade.shell(ground[0],ceiling,facade.wall,"ArcadeGroundShell")
	var ground_node: MeshInstance3D = facade.group.get_child(facade.group.get_child_count()-1)
	var finish := SurfaceTool.new()
	finish.begin(Mesh.PRIMITIVE_TRIANGLES)
	var clipper = preload("res://tools/build_photo_surfaces.gd").new()
	var vertex_count := 0
	for i in stations.size()-1:
		var ends: Array[Vector2] = []
		for station in [stations[i],stations[i+1]]:
			var p: Vector2 = path.origin+path.axis*station-path.outward*float(arcade.depth)
			var mapped: Vector3 = path.mapped(Vector3(p.x,0,p.y))
			ends.append(Vector2(mapped.x,mapped.z))
		var along := (ends[1]-ends[0]).normalized()
		var normal := Vector2(along.y,-along.x)
		if normal.dot(path.outward)<0: normal=-normal
		vertex_count += clipper.clip_shell(finish,ground_node,ends[0],along,normal,Rect2(0,0.03,ends[0].distance_to(ends[1]),ceiling-0.03))
	assert(vertex_count>0,"Arcade finish must be bounded to the recessed rear wall")
	finish.index()
	var finish_material := ShaderMaterial.new()
	finish_material.resource_name = "Residence arcade grey tiles"
	finish_material.shader = load("res://assets/campuses/eda/materials/academic_tile.gdshader")
	finish_material.set_shader_parameter("tile_color",Color("808b8c"))
	finish_material.set_shader_parameter("pale_color",Color("808b8c"))
	var finish_node: MeshInstance3D = facade.host.mesh_node(facade.group,finish.commit(),finish_material,"ArcadeRearTiles")
	finish_node.set_meta("walk_collision",false)
	var paving: StandardMaterial3D = facade.host.material("Residence arcade paving",Color("96978b"))
	paving.albedo_texture = load("res://assets/textures/buildings/mineral_render_albedo.png")
	paving.uv1_triplanar = true
	paving.uv1_scale = Vector3.ONE*0.8
	facade.shell(floors[0],0.03,paving,"ArcadeFloor",-0.08)
	var soffit := SurfaceTool.new()
	soffit.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(floors[0])
	for i in range(0,indices.size(),3):
		var vertices: Array[Vector3] = []
		for j in 3:
			var p: Vector2 = floors[0][indices[i+j]]
			vertices.append(Vector3(p.x,ceiling,p.y))
		if (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).y>0: vertices.reverse()
		for vertex in vertices: soffit.add_vertex(vertex)
	soffit.generate_normals()
	soffit.index()
	var node: MeshInstance3D = facade.host.mesh_node(facade.group,soffit.commit(),facade.frame,"ArcadeSoffit")
	node.set_meta("walk_collision",true)
	var count := int(arcade.bays)
	var width: float = arcade.column_width
	for i in range(count+1):
		var p: Vector2 = path.origin+path.axis*lerpf(first,last,float(i)/count)-path.outward*width/2
		var column: MeshInstance3D = facade.host.box(facade.group,Vector3(p.x,ceiling/2,p.y),Vector3(width,ceiling,width),facade.wall,"ArcadeColumn")
		column.rotation.y = -atan2(path.axis.y,path.axis.x)
		column.set_meta("walk_collision",true)
		path.deform(column)
