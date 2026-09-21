extends RefCounted
## Approximate outdoor equipment anchored to the registered pitch end lines.

func tube(builder, group: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material, solid := true) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12 if solid else 5
	mesh.rings = 1
	var node: MeshInstance3D = builder.mesh_node(group,mesh,mat,"GoalFrame")
	node.position = (a+b)*0.5
	node.basis = Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	node.set_meta("walk_collision",solid)

func net_rope(builder, group: Node3D, a: Vector3, b: Vector3, mat: Material) -> void:
	if a.distance_to(b)>0.005:
		tube(builder,group,a,b,0.0025,mat,false)

func build(builder, group: Node3D, feature: Dictionary) -> void:
	var outline: Dictionary = feature.sports_lines[0]
	assert(outline.osm_id=="way/1076344143" and int(outline.osm_version)==1)
	assert(outline.points.size()==4)
	var corners: Array[Vector2] = []
	for p in outline.points: corners.append(Vector2(p[0],p[1]))
	var north := (corners[0]+corners[3])*0.5
	var south := (corners[1]+corners[2])*0.5
	var frame: StandardMaterial3D = builder.material("EDA goal aluminium",Color("b5bdba"))
	frame.albedo_texture = null
	frame.metallic = 0.65
	frame.roughness = 0.42
	var net: StandardMaterial3D = builder.material("EDA goal net",Color("cad0bd"))
	net.albedo_texture = null
	net.roughness = 0.94
	for pair in [[0,3],[1,2]]:
		var a: Vector2 = corners[pair[0]]
		var b: Vector2 = corners[pair[1]]
		var across := (b-a).normalized()
		var rear := (north-south).normalized() * (1.0 if pair[0]==0 else -1.0)
		var center := (a+b)*0.5
		var left := Vector3(center.x-across.x*3.66,0.3,center.y-across.y*3.66)
		var right := Vector3(center.x+across.x*3.66,0.3,center.y+across.y*3.66)
		var lift := Vector3.UP*2.44
		var depth := Vector3(rear.x,0,rear.y)*2.1
		for ends in [[left,left+lift],[right,right+lift],[left+lift,right+lift]]:
			tube(builder,group,ends[0],ends[1],0.045,frame)
		for ends in [[left,left+depth],[right,right+depth],[left+depth,right+depth],[left+lift,left+depth],[right+lift,right+depth]]:
			tube(builder,group,ends[0],ends[1],0.028,frame)
		var slope := lift.distance_to(depth)
		for i in 62:
			var t := float(i)/61.0
			net_rope(builder,group,(left+lift).lerp(right+lift,t),(left+depth).lerp(right+depth,t),net)
		var rows := ceili(slope/0.12)
		for i in rows+1:
			var t := float(i)/rows
			net_rope(builder,group,(left+lift).lerp(left+depth,t),(right+lift).lerp(right+depth,t),net)
		for base in [left,right]:
			for i in 21:
				var t := float(i)/20.0
				net_rope(builder,group,base+lift*t,base+lift*t+depth*(1.0-t),net)
			for i in 19:
				var t := float(i)/18.0
				net_rope(builder,group,base+depth*t,base+depth*t+lift*(1.0-t),net)
