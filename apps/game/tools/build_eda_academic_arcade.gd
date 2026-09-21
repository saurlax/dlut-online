extends RefCounted

const CEILING := 8.68
var opening := PackedVector2Array()

func configure(points: PackedVector2Array) -> void:
	var join = preload("res://tools/build_eda_library_ring.gd").new()
	var edges := PackedInt32Array(range(6,15))
	for vertex in range(6,16):
		opening.append(join.corner(points,edges,vertex,mini(vertex,14),0.85))
	for vertex in range(15,5,-1):
		opening.append(join.corner(points,edges,vertex,mini(vertex,14),-1.6))

func body(facade, points: PackedVector2Array, top: float, base: float, material: Material) -> void:
	if base>=CEILING:
		facade.shell(points,top,base,material)
		return
	var clipped := Geometry2D.clip_polygons(points,opening)
	assert(clipped.size()==1,"Academic outdoor arcade must leave one closed building shell")
	facade.shell(clipped[0],minf(top,CEILING),base,material)
	if top>CEILING: facade.shell(points,top,CEILING,material)

func finishes(facade, stone: Material) -> void:
	var paving: StandardMaterial3D = facade.host.material("Academic rotunda arcade paving",Color("96978b"))
	paving.albedo_texture = load("res://assets/textures/buildings/mineral_render_albedo.png")
	paving.uv1_triplanar = true
	paving.uv1_scale = Vector3.ONE*0.8
	facade.shell(opening,0.03,-0.08,paving)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(opening)
	assert(not indices.is_empty(),"Invalid academic arcade soffit")
	for i in range(0,indices.size(),3):
		var vertices: Array[Vector3] = []
		for j in 3:
			var p := opening[indices[i+j]]
			vertices.append(Vector3(p.x,CEILING,p.y))
		if (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).y>0: vertices.reverse()
		for vertex in vertices: surface.add_vertex(vertex)
	surface.generate_normals()
	surface.index()
	var node: MeshInstance3D = facade.host.mesh_node(facade.group,surface.commit(),stone,"AcademicArcadeSoffit")
	node.set_meta("walk_collision",true)
