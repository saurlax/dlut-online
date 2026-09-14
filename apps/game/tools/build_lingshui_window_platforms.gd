extends RefCounted

# Only explicitly registered, photo-visible window platforms are generated.
func build(builder, group: Node3D, p: Vector2, q: Vector2, outward: Vector2, entries: Array) -> void:
	var direction := (q-p).normalized()
	var rotation := -atan2(direction.y,direction.x)
	var concrete: Material = builder.material("Window platform concrete",Color("999488"))
	var metal: Material = builder.material("Window platform metal",Color("555c56"))
	for entry in entries:
		var rail_material: Material = builder.material("Photo platform rail " + str(entry.metal_color),Color(str(entry.metal_color))) if entry.has("metal_color") else metal
		var center := p.lerp(q,float(entry.fraction))
		var width: float = entry.width
		var depth: float = entry.depth
		var top: float = entry.top
		var thickness: float = entry.thickness
		var rail_height: float = entry.rail_height
		var slab: MeshInstance3D = box(builder,group,center+outward*depth/2,top-thickness/2,Vector3(width,thickness,depth),rotation,concrete)
		slab.set_meta("walk_collision",true)
		# Rails are visual details; only the solid slab enters the collision world.
		for y in [top+0.12,top+rail_height]:
			box(builder,group,center+outward*depth,y,Vector3(width,0.035,0.035),rotation,rail_material)
			for side in [-1,1]:
				box(builder,group,center+direction*side*width/2+outward*depth/2,y,Vector3(0.035,0.035,depth),rotation,rail_material)
		for i in range(int(entry.front_bars)+1):
			var offset := width*(float(i)/int(entry.front_bars)-0.5)
			box(builder,group,center+direction*offset+outward*depth,top+rail_height/2,Vector3(0.025,rail_height,0.025),rotation,rail_material)
		for side in [-1,1]:
			for fraction in [0.0,0.5]:
				box(builder,group,center+direction*side*width/2+outward*depth*fraction,top+rail_height/2,Vector3(0.025,rail_height,0.025),rotation,rail_material)
		if entry.has("radial_ornaments"):
			var ornament: Dictionary = entry.radial_ornaments
			for i in int(ornament.front_count):
				var offset := width*((i+0.5)/int(ornament.front_count)-0.5)
				radial(builder,group,center+direction*offset+outward*depth,direction,top+rail_height/2,Vector2(ornament.half_width,ornament.half_height),rail_material)
			for side in [-1,1]:
				radial(builder,group,center+direction*side*width/2+outward*depth/2,outward,top+rail_height/2,Vector2(ornament.side_half_width,ornament.half_height),rail_material)

# Photo-visible cross and diagonal rods; the pattern is decorative, not collision.
func radial(builder, group: Node3D, center: Vector2, direction: Vector2, y: float, half_size: Vector2, mat: Material) -> void:
	var rotation := -atan2(direction.y,direction.x)
	var points := PackedVector2Array([Vector2(-half_size.x,0),Vector2(0,half_size.y),Vector2(half_size.x,0),Vector2(0,-half_size.y)])
	for i in 4:
		rod(builder,group,center,direction,y,points[i],points[(i+1)%4],rotation,mat)
	for endpoint in [Vector2(half_size.x,0),Vector2(0,half_size.y),half_size,Vector2(half_size.x,-half_size.y)]:
		rod(builder,group,center,direction,y,-endpoint,endpoint,rotation,mat)

func rod(builder, group: Node3D, center: Vector2, direction: Vector2, y: float, a: Vector2, b: Vector2, rotation: float, mat: Material) -> void:
	var middle := (a+b)/2
	var pos := center+direction*middle.x
	var node: MeshInstance3D = builder.box(group,Vector3(pos.x,y+middle.y,pos.y),Vector3(a.distance_to(b),0.025,0.025),mat,"PlatformRailOrnament")
	node.basis = Basis(Vector3.UP,rotation)*Basis(Vector3.BACK,(b-a).angle())

func box(builder, group: Node3D, pos: Vector2, y: float, size: Vector3, rotation: float, mat: Material) -> MeshInstance3D:
	var node: MeshInstance3D = builder.box(group,Vector3(pos.x,y,pos.y),size,mat,"WindowPlatform")
	node.rotation.y = rotation
	return node
