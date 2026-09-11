extends SceneTree

var scene := Node3D.new()
var materials: Dictionary = {}
var manifest: Dictionary
var generated_count := 0
var roads: Array = []

func _initialize() -> void:
	call_deferred("build")

func material(key: String, color: Color) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.resource_name = key
	mat.albedo_color = color
	mat.roughness = 0.83
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if key == "Window glass":
		mat.metallic = 0.65
		mat.roughness = 0.19
	elif key not in ["Court markings", "Window frames"]:
		var noise := FastNoiseLite.new()
		noise.seed = 731
		noise.frequency = 0.045
		noise.fractal_octaves = 4
		var texture := NoiseTexture2D.new()
		texture.width = 256
		texture.height = 256
		texture.seamless = true
		texture.noise = noise
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.58,0.58,0.58))
		ramp.set_color(1, Color(1,1,1))
		texture.color_ramp = ramp
		mat.albedo_texture = texture
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE * (0.35 if key in ["Academic", "Residence", "Gate"] else 0.8)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if key == "Water":
			mat.metallic = 0.35
			mat.roughness = 0.23
	materials[key] = mat
	return mat

func mesh_node(parent: Node3D, mesh: Mesh, mat: Material, title: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	node.owner = scene
	return node

func box(parent: Node3D, at: Vector3, size: Vector3, mat: Material, title := "Detail") -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var node := mesh_node(parent, shape, mat, title)
	node.position = at
	return node

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func polygon(parent: Node3D, points: PackedVector2Array, height: float, mat: Material, title: String, base := 0.0) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	assert(not indices.is_empty(), "Invalid source polygon: " + title)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for index in indices:
		st.add_vertex(Vector3(points[index].x, height, points[index].y))
	if height - base > 0.2:
		for i in points.size():
			var p := points[i]
			var q := points[(i+1)%points.size()]
			var a := Vector3(p.x, base, p.y)
			var b := Vector3(q.x, base, q.y)
			var c := Vector3(q.x, height, q.y)
			var d := Vector3(p.x, height, p.y)
			triangle(st, a, b, c)
			triangle(st, a, c, d)
	st.generate_normals()
	mesh_node(parent, st.commit(), mat, title)

func line(parent: Node3D, a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	var node := box(parent, (a+b)*0.5, Vector3(width, 0.08, a.distance_to(b)), mat)
	node.rotation.y = atan2((b-a).x, (b-a).z)

func facade(parent: Node3D, points: PackedVector2Array, height: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var clockwise := Geometry2D.is_polygon_clockwise(points)
	for i in points.size():
		var p := points[i]
		var q := points[(i+1)%points.size()]
		var length := p.distance_to(q)
		if length < 5:
			continue
		var direction := (q-p).normalized()
		var outward := Vector2(direction.y, -direction.x) * (1.0 if not clockwise else -1.0)
		var count := maxi(1, int(length/4.6))
		for floor_index in range(maxi(1,int((height-3)/3.8))):
			var y := 2.5 + floor_index * 3.8
			for column in range(count):
				var middle := p.lerp(q, (column+0.5)/count) + outward*0.08
				var left := middle-direction*1.15
				var right := middle+direction*1.15
				var a := Vector3(left.x,y,left.y)
				var b := Vector3(right.x,y,right.y)
				var c := Vector3(right.x,y+1.8,right.y)
				var d := Vector3(left.x,y+1.8,left.y)
				triangle(st,a,b,c)
				triangle(st,a,c,d)
				var trim := material("Window frames",Color("aaa9a2"))
				for offset in [-1.2,0.0,1.2]:
					var pos: Vector2 = middle + direction*offset + outward*0.05
					var frame := box(parent,Vector3(pos.x,y+0.9,pos.y),Vector3(0.065,1.94,0.16),trim,"FacadeDetail")
					frame.rotation.y = -atan2(direction.y,direction.x)
				for level in [0.0,1.8]:
					var pos: Vector2 = middle + outward*0.09
					var sill := box(parent,Vector3(pos.x,y+level,pos.y),Vector3(2.52,0.10,0.28),trim,"FacadeDetail")
					sill.rotation.y = -atan2(direction.y,direction.x)
		# Continuous stone base and roof coping give walls human-scale depth.
		for elevation in [0.45,height-0.18]:
			var mid := (p+q)*0.5 + outward*0.10
			var band := box(parent,Vector3(mid.x,elevation,mid.y),Vector3(length,0.65,0.26),material("Stone trim",Color("8c8980")),"FacadeDetail")
			band.rotation.y = -atan2(direction.y,direction.x)
	st.generate_normals()
	mesh_node(parent,st.commit(),material("Window glass",Color("35464f")),"Windows")

func oval(parent: Node3D, center: Vector2, radii: Vector2, elevation: float, mat: Material) -> void:
	var points := PackedVector2Array()
	for i in 80:
		var angle := TAU*i/80.0
		points.append(center + Vector2(cos(angle)*radii.x,sin(angle)*radii.y))
	polygon(parent,points,elevation,mat,"Oval")

func sports(parent: Node3D, points: PackedVector2Array, kind: String) -> void:
	var bounds := Rect2(points[0],Vector2.ZERO)
	for p in points:
		bounds = bounds.expand(p)
	var center := bounds.get_center()
	var white := material("Court markings",Color("f6eedc"))
	if kind == "track":
		var radii := bounds.size*Vector2(0.47,0.47)
		oval(parent,center,radii,0.25,material("Running track",Color("b77765")))
		for lane in range(6):
			var r := radii-Vector2.ONE*(lane*1.5+1.0)
			for i in 80:
				var a := TAU*i/80.0
				var b := TAU*(i+1)/80.0
				line(parent,Vector3(center.x+cos(a)*r.x,0.35,center.y+sin(a)*r.y),Vector3(center.x+cos(b)*r.x,0.35,center.y+sin(b)*r.y),0.18,white)
		oval(parent,center,radii-Vector2(13,15),0.4,material("Field grass",Color("739578")))
		var width := radii.x*1.2
		var depth := radii.y*1.25
		var corners := [Vector3(center.x-width/2,0.5,center.y-depth/2),Vector3(center.x+width/2,0.5,center.y-depth/2),Vector3(center.x+width/2,0.5,center.y+depth/2),Vector3(center.x-width/2,0.5,center.y+depth/2)]
		for i in 4:
			line(parent,corners[i],corners[(i+1)%4],0.25,white)
		line(parent,Vector3(center.x-width/2,0.5,center.y),Vector3(center.x+width/2,0.5,center.y),0.25,white)
	else:
		var count := 4 if kind == "basketball" else 2
		for court in count:
			var c := Vector2(center.x,bounds.position.y+bounds.size.y*(court+0.5)/count)
			var size := Vector2(bounds.size.x*0.78,bounds.size.y/count*0.8)
			box(parent,Vector3(c.x,0.3,c.y),Vector3(size.x,0.08,size.y),material("Court surface",Color("638c91")))
			var corners := [Vector3(c.x-size.x/2,0.4,c.y-size.y/2),Vector3(c.x+size.x/2,0.4,c.y-size.y/2),Vector3(c.x+size.x/2,0.4,c.y+size.y/2),Vector3(c.x-size.x/2,0.4,c.y+size.y/2)]
			for i in 4:
				line(parent,corners[i],corners[(i+1)%4],0.2,white)
			line(parent,Vector3(c.x-size.x/2,0.4,c.y),Vector3(c.x+size.x/2,0.4,c.y),0.2,white)


func merge_meshes(parent: Node3D) -> void:
	var buckets: Dictionary = {}
	for child in parent.get_children():
		if child is MeshInstance3D:
			var key: String = child.material_override.resource_name + ("_Solid" if child.get_meta("walk_collision",false) else "")
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append(child)
		elif child is Node3D:
			merge_meshes(child)
	for key in buckets:
		var nodes: Array = buckets[key]
		if nodes.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)
		for node in nodes:
			st.append_from(node.mesh,0,node.transform)
		var mat: Material = nodes[0].material_override
		var collision: bool = nodes[0].get_meta("walk_collision",false)
		for node in nodes:
			parent.remove_child(node)
			node.free()
		var merged := mesh_node(parent,st.commit(),mat,key.replace(" ","_"))
		merged.set_meta("walk_collision",collision)

func build() -> void:
	scene.name = "DevelopmentCampus"
	root.add_child(scene)
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	box(scene,Vector3(0,-6,55),Vector3(1280,12,930),material("Campus base",Color("74795b")),"CampusBase")
	roads = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/roads.json")).roads
	for road in roads:
		for i in range(road.points.size()-1):
			var a := Vector3(road.points[i][0],0.04,road.points[i][1])
			var b := Vector3(road.points[i+1][0],0.04,road.points[i+1][1])
			line(scene,a,b,road.width+3.0,material("Road edge",Color("a9a69c")))
			line(scene,a+Vector3.UP*0.06,b+Vector3.UP*0.06,road.width,material("Road",Color("555a5b")))
	for feature in manifest.features:
		var group := Node3D.new()
		group.name = "Feature_" + feature.id
		group.set_meta("source_id",feature.id)
		group.set_meta("display_name",feature.name)
		group.set_meta("height_is_approximate",true)
		scene.add_child(group)
		group.owner = scene
		var points := PackedVector2Array()
		for point in feature.points:
			points.append(Vector2(point[0],point[1]))
		var kind: String = feature.kind
		var height: float = feature.height
		match kind:
			"building":
				if feature.id in ["77914","77917"]:
					preload("res://tools/build_photo_facades.gd").new().build(self,group,points,feature.id=="77917")
					generated_count += 1
					continue
				var color := Color("967c6c") if "宿舍" in feature.name else Color("b9b6ab")
				polygon(group,points,height,material("Residence" if "宿舍" in feature.name else "Academic",color),"Building")
				polygon(group,points,height+0.45,material("Roof",Color("92938b")),"Roof",height)
				facade(group,points,height)
			"water":
				polygon(group,points,0.2,material("Water",Color("526b6a")),"Lake")
			"hill":
				polygon(group,points,0.12,material("Hill footprint",Color("7e9a7c")),"HillBase")
				var center := Vector2.ZERO
				for p in points:
					center += p/points.size()
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_smooth_group(-1)
				for i in points.size():
					var p := points[i]
					var q := points[(i+1)%points.size()]
					triangle(st,Vector3(p.x,0.2,p.y),Vector3(q.x,0.2,q.y),Vector3(center.x,height,center.y))
				st.generate_normals()
				mesh_node(group,st.commit(),material("Hill",Color("73795d")),"SchematicTerrain")
			"track", "basketball", "tennis":
				polygon(group,points,0.15,material("Sports base",Color("bdbaa0")),"SportsBase")
				sports(group,points,kind)
			"gate":
				polygon(group,points,0.16,material("Paving",Color("a9a79e")),"GateFootprint")
				var bounds := Rect2(points[0],Vector2.ZERO)
				for p in points:
					bounds = bounds.expand(p)
				var center := bounds.get_center()
				var width := minf(bounds.size.x,32)
				box(group,Vector3(center.x-width/2,2.5,center.y),Vector3(1.6,5,1.6),material("Gate",Color("d8cfba")))
				box(group,Vector3(center.x+width/2,2.5,center.y),Vector3(1.6,5,1.6),materials.Gate)
				box(group,Vector3(center.x,5,center.y),Vector3(width+2,1.2,1.8),materials.Gate)
			_:
				polygon(group,points,0.1,material("Paving" if kind=="plaza" else "Reserve",Color("a9a79e") if kind=="plaza" else Color("adba99")),"Ground")
		generated_count += 1
	preload("res://tools/build_vegetation.gd").new().build(self)
	merge_meshes(scene)
	for mat in materials.values():
		if mat.albedo_texture is NoiseTexture2D and mat.albedo_texture.get_image() == null:
			await mat.albedo_texture.changed
	var packed := PackedScene.new()
	assert(packed.pack(scene)==OK)
	assert(ResourceSaver.save(packed,"res://assets/campuses/eda/models/development_campus.tscn")==OK)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(scene,state)==OK)
	assert(document.write_to_filesystem(state,"res://assets/campuses/eda/models/development_campus.glb")==OK)
	print("MODEL PASS: %d official polygons, generated TSCN and GLB" % generated_count)
	quit()
