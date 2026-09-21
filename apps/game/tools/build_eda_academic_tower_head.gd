extends RefCounted

func vertex(facade, x: float, y: float, local: Vector2) -> Vector3:
	var p: Vector2 = facade.origin+facade.axis*(x+local.x)+facade.out*local.y
	return Vector3(p.x,y,p.y)

func quad(surface: SurfaceTool, corners: Array[Vector3], normal: Vector3) -> void:
	for triangle in [[0,1,2],[0,2,3]]:
		var a: Vector3 = corners[triangle[0]]
		var b: Vector3 = corners[triangle[1]]
		var c: Vector3 = corners[triangle[2]]
		if (c-a).cross(b-a).dot(normal)<0:
			var swap := b
			b=c
			c=swap
		var face_normal := (c-a).cross(b-a).normalized()
		for p in [a,b,c]:
			surface.set_normal(face_normal)
			surface.add_vertex(p)

func build(facade, x: float, profile: Dictionary, material: Material) -> void:
	var half_width: float = float(profile.width)/2.0
	var half_depth := 1.15
	var radii := Vector2(float(profile.head_aperture[0]),float(profile.head_aperture[1]))/2.0
	assert(radii.x>0 and radii.y>0 and radii.x<half_width and radii.y<half_depth)
	var angles: Array[float] = []
	for i in 48: angles.append(TAU*i/48.0)
	# Include rectangle corners so the outer silhouette is not chamfered.
	for sx in [-1.0,1.0]:
		for sz in [-1.0,1.0]: angles.append(fposmod(atan2(sz*half_depth/radii.y,sx*half_width/radii.x),TAU))
	angles.sort()
	var top: float = float(profile.head_beam_y)+0.1
	var bottom := top-0.2
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in angles.size():
		var inner: Array[Vector2] = []
		var outer: Array[Vector2] = []
		for angle in [angles[i],angles[(i+1)%angles.size()]]:
			var point := Vector2(cos(angle)*radii.x,sin(angle)*radii.y)
			var direction := point.normalized()
			inner.append(point)
			outer.append(direction*minf(half_width/maxf(absf(direction.x),0.000001),half_depth/maxf(absf(direction.y),0.000001)))
		var ia := vertex(facade,x,top,inner[0])
		var ib := vertex(facade,x,top,inner[1])
		var oa := vertex(facade,x,top,outer[0])
		var ob := vertex(facade,x,top,outer[1])
		var drop := Vector3(0,bottom-top,0)
		quad(surface,[ia,ib,ob,oa],Vector3.UP)
		quad(surface,[ia+drop,ib+drop,ob+drop,oa+drop],Vector3.DOWN)
		var center := vertex(facade,x,top,Vector2.ZERO)
		quad(surface,[ia,ib,ib+drop,ia+drop],center-(ia+ib)/2.0)
		quad(surface,[oa,ob,ob+drop,oa+drop],(oa+ob)/2.0-center)
	surface.index()
	var node: MeshInstance3D = facade.host.mesh_node(facade.group,surface.commit(),material,"AcademicTowerHead")
	node.set_meta("walk_collision",true)
