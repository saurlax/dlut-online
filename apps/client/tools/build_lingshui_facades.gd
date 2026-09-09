extends RefCounted

# Explicit edge indices and photo coverage live in references/lingshui/facades.json.
# All ornament is merged by material by the caller; only structural columns collide.
func build(builder, group: Node3D, points: PackedVector2Array, profile: Dictionary) -> void:
	var height: float = profile.height
	var floors: int = int(profile.floors)
	var stone: Material = builder.material("Lingshui stone trim", Color("d0c7b3"))
	var glass: Material = builder.material("Window glass", Color("354951"))
	var frame: Material = builder.material("Window frames", Color("777970"))
	var clockwise := Geometry2D.is_polygon_clockwise(points)
	for edge_value in profile.edges:
		var edge := int(edge_value)
		var p := points[edge]
		var q := points[(edge+1)%points.size()]
		var direction := (q-p).normalized()
		var outward := Vector2(direction.y,-direction.x) * (-1.0 if clockwise else 1.0)
		var length := p.distance_to(q)
		if length < 2.0:
			continue
		var rotation := -atan2(direction.y,direction.x)
		var is_lingxi: bool = profile.style == "lingxi"
		var count := maxi(1, roundi(length/(2.8 if is_lingxi else 3.8)))
		var spacing := length/count
		for floor_index in floors:
			var y := 1.0 + floor_index*(height-2.0)/floors
			for column in count:
				var fraction := (column+0.5)/count
				if is_lingxi and fraction > 0.26 and fraction < 0.74:
					continue
				if profile.style == "bochuan" and edge == int(profile.primary_edge):
					continue
				var pos := p.lerp(q,fraction) + outward*0.07
				var width := spacing*(0.35 if is_lingxi else 0.57)
				var window_height := (height-2.0)/floors*0.63
				panel(builder,group,pos,y+window_height/2.0,Vector3(width,window_height,0.12),rotation,glass,"Windows")
				for side in [-1,1]:
					panel(builder,group,pos+direction*side*width/2.0+outward*0.09,y+window_height/2.0,Vector3(0.075,window_height+0.12,0.16),rotation,frame,"WindowFrames")
				panel(builder,group,pos+outward*0.09,y+window_height/2.0,Vector3(0.055,window_height,0.16),rotation,frame,"WindowFrames")
				for level in [y,y+window_height]:
					panel(builder,group,pos+outward*0.10,level,Vector3(width+0.2,0.10,0.22),rotation,stone,"Sills")
		if is_lingxi:
			var center := p.lerp(q,0.5)+outward*0.11
			var glass_width := length*0.44
			panel(builder,group,center,height*0.47,Vector3(glass_width,height*0.8,0.18),rotation,glass,"AtriumExterior")
			for i in range(1,6):
				panel(builder,group,center+outward*0.15,2.0+i*4.0,Vector3(glass_width,0.36,0.3),rotation,frame,"CurtainFrames")
			for i in range(13):
				panel(builder,group,center+direction*glass_width*(i/12.0-0.5)+outward*0.15,height*0.47,Vector3(0.08,height*0.8,0.2),rotation,frame,"CurtainFrames")
			var brick: Material = builder.material("Lingshui "+profile.color,Color(profile.color))
			for fraction in [0.25,0.75]:
				panel(builder,group,p.lerp(q,fraction)+outward*0.4,height*0.48,Vector3(1.6,height*0.91,0.9),rotation,brick,"BrickPiers")
			panel(builder,group,center+outward*0.4,height-1.3,Vector3(glass_width+4.0,2.0,1.0),rotation,brick,"BrickLintel")
		else:
			for column in range(count+1):
				var pos := p.lerp(q,float(column)/count)+outward*0.13
				panel(builder,group,pos,height*0.49,Vector3(0.28,height*0.96,0.27),rotation,stone,"StonePiers")
			for level in [0.4,height-0.45,height-3.8]:
				panel(builder,group,(p+q)*0.5+outward*0.15,level,Vector3(length,0.30,0.35),rotation,stone,"Cornice")
		if profile.style == "main" and edge == int(profile.primary_edge):
			var center := (p+q)*0.5
			var timber: Material = builder.material("Lingshui closed timber doors",Color("524a3c"))
			for fraction in [0.22,0.50,0.78]:
				var door_pos := p.lerp(q,fraction)+outward*0.25
				panel(builder,group,door_pos,1.9,Vector3(2.9,3.8,0.18),rotation,timber,"ClosedDoors")
				panel(builder,group,door_pos+outward*0.13,2.8,Vector3(2.45,0.9,0.1),rotation,glass,"DoorLights")
				panel(builder,group,door_pos+outward*0.20,1.8,Vector3(0.08,3.6,0.1),rotation,stone,"DoorMullions")
			var roof := panel(builder,group,center+outward*1.8,8.1,Vector3(length,0.55,3.6),rotation,stone,"PorticoRoof")
			roof.set_meta("walk_collision",true)
			for column in range(6):
				var pos := p.lerp(q,(column+0.2)/5.4)+outward*3.0
				var pillar := panel(builder,group,pos,3.95,Vector3(0.7,7.9,0.8),rotation,stone,"PorticoColumn")
				pillar.set_meta("walk_collision",true)
		if profile.style == "bochuan" and edge == int(profile.primary_edge):
			var middle := (p+q)*0.5
			var masonry: Material = builder.material("Lingshui "+profile.color,Color(profile.color))
			# Photo 77447-5: a broad solid frieze, recessed high strip and square reliefs.
			panel(builder,group,middle+outward*0.32,14.0,Vector3(length,7.0,0.45),rotation,masonry,"LibraryFrieze")
			panel(builder,group,middle+outward*0.34,21.2,Vector3(length*0.94,2.6,0.25),rotation,glass,"LibraryHighWindow")
			panel(builder,group,middle+outward*0.35,6.2,Vector3(length*0.58,4.2,0.22),rotation,glass,"LibraryClosedEntry")
			for column in range(8):
				var pos := p.lerp(q,(column+0.5)/8.0)
				panel(builder,group,pos+outward*0.6,11.0,Vector3(0.55,16.0,1.3),rotation,stone,"FrontFins")
				panel(builder,group,pos+outward*0.58,12.6,Vector3(0.9,0.9,0.4),rotation,stone,"SquareRelief")
				panel(builder,group,pos+outward*0.81,12.6,Vector3(0.46,0.46,0.12),rotation,frame,"ReliefInset")
			for fraction in [0.18,0.82]:
				var pos := p.lerp(q,fraction)+outward*0.6
				panel(builder,group,pos,22.0,Vector3(2.3,3.1,0.8),rotation,stone,"UpperSquareFrame")
				panel(builder,group,pos+outward*0.45,22.0,Vector3(1.55,2.25,0.2),rotation,glass,"UpperSquareGlass")

func panel(builder, group: Node3D, pos: Vector2, y: float, size: Vector3, rotation: float, mat: Material, title: String) -> MeshInstance3D:
	var node: MeshInstance3D = builder.box(group,Vector3(pos.x,y,pos.y),size,mat,title)
	node.rotation.y = rotation
	return node
