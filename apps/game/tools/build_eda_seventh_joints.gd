extends RefCounted

var facade
var surface: SurfaceTool
var openings: Array[Rect2] = []

func line(rect: Rect2) -> void:
	var pieces: Array[Rect2] = [rect]
	for opening in openings:
		var remaining: Array[Rect2] = []
		for piece in pieces:
			if not piece.intersects(opening):
				remaining.append(piece)
				continue
			var cut := piece.intersection(opening)
			for split in [Rect2(piece.position,Vector2(cut.position.x-piece.position.x,piece.size.y)),Rect2(Vector2(cut.end.x,piece.position.y),Vector2(piece.end.x-cut.end.x,piece.size.y)),Rect2(Vector2(cut.position.x,piece.position.y),Vector2(cut.size.x,cut.position.y-piece.position.y)),Rect2(Vector2(cut.position.x,cut.end.y),Vector2(cut.size.x,piece.end.y-cut.end.y))]:
				if split.size.x>0.0001 and split.size.y>0.0001: remaining.append(split)
		pieces=remaining
	for piece in pieces:
		var corners := PackedVector2Array([piece.position,Vector2(piece.end.x,piece.position.y),piece.end,Vector2(piece.position.x,piece.end.y)])
		for indices in [[0,1,2],[0,2,3]]:
			var vertices := PackedVector3Array()
			for index in indices:
				var xy := corners[index]
				var p: Vector2 = facade.path.origin+facade.path.axis*xy.x+facade.path.outward*0.012
				vertices.append(facade.path.mapped(Vector3(p.x,xy.y,p.y)))
			var outward := Vector3(facade.path.outward.x,0,facade.path.outward.y)
			if (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).dot(outward)<0:
				var swap := vertices[1]
				vertices[1]=vertices[2]
				vertices[2]=swap
			for vertex in vertices: surface.add_vertex(vertex)

func build(end, spec: Dictionary, podium: float, height: float, storey: float) -> void:
	facade=end
	var length: float = facade.path.length
	var width: float = length*float(spec.strip_width_fraction)
	var panel: Dictionary = spec.upper_grille
	openings.append(Rect2(Vector2(length*(float(panel.center_fraction)-float(panel.width_fraction)*0.5),podium+storey*(12.0-3.65*0.5)),Vector2(length*float(panel.width_fraction),storey*3.65)).grow(0.035))
	for pair in 7:
		var fractions: Array = spec.outer_strips.duplicate()
		if pair<5:
			fractions.append_array(spec.inner_strips)
			fractions.append(spec.window_fraction)
		for fraction in fractions:
			openings.append(Rect2(Vector2(length*float(fraction)-width*0.5,podium+storey*(pair*2+1-0.825)),Vector2(width,storey*1.65)).grow(0.035))
	surface=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The module is proportional; stop short of the curved returns rather than
	# projecting straight joints through the rounded corners or glazing.
	for row in range(1,29):
		var y: float = podium+storey*row*0.5
		if y<height-0.2: line(Rect2(0.90,y-0.006,length-1.80,0.012))
	var fractions: Array = spec.outer_strips.duplicate()
	fractions.append_array(spec.inner_strips)
	fractions.append(spec.window_fraction)
	for fraction in fractions:
		for side in [-1.0,1.0]:
			var x: float = length*float(fraction)+side*(width*0.5+0.045)
			line(Rect2(x-0.006,podium,0.012,height-podium-0.1))
	surface.generate_normals()
	surface.index()
	var material: Material = facade.host.material("Seventh end panel joints",Color("aeb1ab"))
	material.albedo_texture=null
	material.roughness=0.9
	var node: MeshInstance3D = facade.host.mesh_node(facade.group,surface.commit(),material,"SeventhEndPanelJoints")
	node.set_meta("walk_collision",false)
