extends SceneTree
## Offline, material-batched background meshes. No collision or runtime generator.

func _initialize() -> void:
	for campus: String in ["lingshui", "eda", "panjin"]:
		build(campus)
	quit()

func attach_mesh(parent: Node3D, scene: Node3D, title: String, st: SurfaceTool, material: Material) -> void:
	st.index()
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = st.commit()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.owner = scene

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func build(campus: String) -> void:
	var path := "res://assets/campuses/%s/" % campus
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + "data/surroundings.json"))
	var scene := Node3D.new()
	scene.name = "Surroundings"
	scene.set_meta("source", data.source)
	scene.set_meta("visual_only", true)
	var terrain := Node3D.new()
	terrain.name = "RegionalTerrain"
	scene.add_child(terrain)
	terrain.owner = scene
	var mountains := Node3D.new()
	mountains.name = "Daheishan" if campus == "eda" else "DistantTerrain"
	scene.add_child(mountains)
	mountains.owner = scene
	var ground := ShaderMaterial.new()
	ground.shader = load("res://assets/terrain/surroundings.gdshader")
	var chunks: Dictionary = {}
	var vertices := PackedVector3Array()
	for i in range(0, data.vertices.size(), 3):
		vertices.append(Vector3(data.vertices[i], data.vertices[i+1], data.vertices[i+2]))
	# Shared smooth normals avoid visible seams between the 600m culling chunks.
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0, data.indices.size(), 3):
		var a := int(data.indices[i])
		var b := int(data.indices[i+1])
		var c := int(data.indices[i+2])
		var normal := (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		for index in [a,b,c]: normals[index] += normal
	for i in normals.size(): normals[i] = normals[i].normalized()
	for i in range(0, data.indices.size(), 3):
		var a: Vector3 = vertices[int(data.indices[i])]
		var key := Vector2i(floori(a.x/600.0), floori(a.z/600.0))
		if not chunks.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			chunks[key] = st
		var st: SurfaceTool = chunks[key]
		for j in 3:
			var index := int(data.indices[i+j])
			st.set_normal(normals[index])
			st.set_color(Color(float(data.forest[index]),float(data.transition[index]),0))
			st.add_vertex(vertices[index])
	for key: Vector2i in chunks:
		var st: SurfaceTool = chunks[key]
		st.index()
		var node := MeshInstance3D.new()
		node.name = "Tile_%d_%d" % [key.x, key.y]
		node.mesh = st.commit()
		node.material_override = ground
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mountains if campus == "eda" and key.x < -1 else terrain).add_child(node)
		node.owner = scene
	var batches: Dictionary = {}
	for building: Dictionary in data.buildings:
		var color := Color.from_string(building.color, Color("d0d0c9"))
		var key := color.to_html()
		if not batches.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_smooth_group(-1)
			batches[key] = st
		var st: SurfaceTool = batches[key]
		var y := float(building.base_y)
		var top := y + float(building.height)
		for ring: Array in [building.outer] + building.holes:
			var polygon := PackedVector2Array()
			for p: Array in ring: polygon.append(Vector2(p[0],p[1]))
			var clockwise := Geometry2D.is_polygon_clockwise(polygon)
			var hole: bool = ring != building.outer
			for i in ring.size():
				var p: Array = ring[i]
				var q: Array = ring[(i+1)%ring.size()]
				var a := Vector3(p[0], y, p[1])
				var b := Vector3(q[0], y, q[1])
				var c := Vector3(q[0], top, q[1])
				var d := Vector3(p[0], top, p[1])
				if clockwise != hole:
					triangle(st,a,c,b)
					triangle(st,a,d,c)
				else:
					triangle(st,a,b,c)
					triangle(st,a,c,d)
		for roof: Array in building.roof:
			var a := Vector3(roof[0][0],top,roof[0][1])
			var b := Vector3(roof[1][0],top,roof[1][1])
			var c := Vector3(roof[2][0],top,roof[2][1])
			if (c-a).cross(b-a).y < 0:
				triangle(st,a,c,b)
			else:
				triangle(st,a,b,c)
	for key: String in batches:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(key)
		material.roughness = 0.95
		attach_mesh(scene, scene, "Buildings_"+key, batches[key], material)
	if not data.canopy.is_empty():
		build_canopy(mountains, scene, data.canopy)
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, path + "models/surroundings.tscn") == OK)
	print(campus, " background: ", chunks.size(), " terrain chunks, ", data.buildings.size(), " building parts")
	scene.free()

func build_canopy(parent: Node3D, scene: Node3D, entries: Array) -> void:
	# A few rounded crowns provide distant forest relief, not surveyed trees.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 6
	sphere.rings = 2
	sphere.radius = 0.4
	sphere.height = 0.8
	for offset: Vector3 in [Vector3(-0.22,0.38,0),Vector3(0.21,0.48,0.08),Vector3(0,0.7,-0.18)]:
		st.append_from(sphere,0,Transform3D(Basis.IDENTITY,offset))
	var mesh := st.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("344a30")
	material.roughness = 1.0
	mesh.surface_set_material(0,material)
	var cells: Dictionary = {}
	for entry: Array in entries:
		var cell := Vector2i(floori(float(entry[0])/600.0),floori(float(entry[2])/600.0))
		if not cells.has(cell): cells[cell] = []
		cells[cell].append(entry)
	for cell: Vector2i in cells:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = cells[cell].size()
		for i in cells[cell].size():
			var e: Array = cells[cell][i]
			var basis := Basis(Vector3.UP,float(e[4])).scaled(Vector3.ONE*float(e[3]))
			multimesh.set_instance_transform(i,Transform3D(basis,Vector3(e[0],e[1],e[2])))
		var node := MultiMeshInstance3D.new()
		node.name = "Canopy_%d_%d" % [cell.x,cell.y]
		node.multimesh = multimesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
		node.owner = scene
