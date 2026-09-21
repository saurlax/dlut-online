extends RefCounted

var surface: SurfaceTool
var facade
var center: Vector2
var scale: Vector2

func triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b-a).cross(c-a).dot(normal)>0:
		var swap := b
		b=c
		c=swap
	for vertex in [a,b,c]: surface.add_vertex(vertex)

func point(p: Vector2, depth: float) -> Vector3:
	var xy := center+p*scale
	var ground: Vector2 = facade.path.origin+facade.path.axis*xy.x+facade.path.outward*depth
	return Vector3(ground.x,xy.y,ground.y)

func polygon(points: PackedVector2Array) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	assert(not indices.is_empty(),"Invalid seventh residence lettering contour")
	var outward := Vector3(facade.path.outward.x,0,facade.path.outward.y)
	for i in range(0,indices.size(),3):
		for depth in [0.19,0.25]:
			triangle(point(points[indices[i]],depth),point(points[indices[i+1]],depth),point(points[indices[i+2]],depth),outward if depth>0.2 else -outward)
	var clockwise := Geometry2D.is_polygon_clockwise(points)
	for i in points.size():
		var a := points[i]
		var b := points[(i+1)%points.size()]
		var edge := (b-a)*scale
		var normal_2d := Vector2(edge.y,-edge.x)*(-1 if clockwise else 1)
		var normal := Vector3(facade.path.axis.x*normal_2d.x,normal_2d.y,facade.path.axis.y*normal_2d.x)
		triangle(point(a,0.19),point(b,0.19),point(b,0.25),normal)
		triangle(point(a,0.19),point(b,0.25),point(a,0.25),normal)

func rect(x: float, y: float, width: float, height: float) -> void:
	polygon(PackedVector2Array([Vector2(x,y),Vector2(x+width,y),Vector2(x+width,y+height),Vector2(x,y+height)]))

func build(end, x: float, y: float, width: float, height: float, material: Material) -> void:
	facade=end
	center=Vector2(x-width/2,y-height/2)
	scale=Vector2(width/3.4,height)
	surface=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	# Serif capitals with curved bowls, using normalized outlines rather than a runtime font.
	rect(0.15,0,0.22,1)
	rect(0,0,0.5,0.09)
	rect(0,0.91,0.5,0.09)
	var bowl := PackedVector2Array()
	for i in 25:
		var angle := -PI/2+PI*i/24
		bowl.append(Vector2(0.37+0.66*cos(angle),0.5+0.5*sin(angle)))
	for i in range(24,-1,-1):
		var angle := -PI/2+PI*i/24
		bowl.append(Vector2(0.37+0.43*cos(angle),0.5+0.40*sin(angle)))
	polygon(bowl)
	var u := PackedVector2Array([Vector2(1.28,1),Vector2(1.5,1),Vector2(1.5,0.38)])
	for i in 25:
		var angle := PI+PI*i/24
		u.append(Vector2(1.76+0.26*cos(angle),0.38+0.27*sin(angle)))
	u.append_array(PackedVector2Array([Vector2(2.02,1),Vector2(2.13,1),Vector2(2.13,0.38)]))
	for i in range(24,-1,-1):
		var angle := PI+PI*i/24
		u.append(Vector2(1.705+0.425*cos(angle),0.38+0.38*sin(angle)))
	polygon(u)
	rect(1.17,0.91,0.45,0.09)
	rect(1.9,0.91,0.35,0.09)
	polygon(PackedVector2Array([Vector2(2.36,1),Vector2(3.4,1),Vector2(3.4,0.73),Vector2(3.3,0.73),Vector2(3.19,0.9),Vector2(2.99,0.9),Vector2(2.99,0.09),Vector2(3.16,0.09),Vector2(3.16,0),Vector2(2.6,0),Vector2(2.6,0.09),Vector2(2.77,0.09),Vector2(2.77,0.9),Vector2(2.57,0.9),Vector2(2.46,0.73),Vector2(2.36,0.73)]))
	surface.generate_normals()
	surface.index()
	var node: MeshInstance3D = facade.host.mesh_node(facade.group,surface.commit(),material,"SeventhDUTLetters")
	node.set_meta("walk_collision",false)
	facade.path.deform(node)
