extends RefCounted

# Coverage and approximation limits are explicit in references/panjin/buildings/facades.json.
# Decorations stay on the closed footprint shell and never receive collision.
func build(builder, group: Node3D, points: PackedVector2Array, profile: Dictionary) -> void:
	var glass: Material = builder.material("Window glass", Color("455651"))
	var metal: Material = builder.material("Panjin dark metal", Color("4b4b46"))
	var pale: Material = builder.material("Panjin pale metal", Color("c8c6b5"))
	var gold: Material = builder.material("Panjin gold fins", Color("c6ba87"))
	var height: float = profile.height
	var floors: int = int(profile.floors)
	var clockwise := Geometry2D.is_polygon_clockwise(points)
	for edge_value in profile.edges:
		var edge := int(edge_value)
		var p := points[edge]
		var q := points[(edge+1)%points.size()]
		var direction := (q-p).normalized()
		var outward := Vector2(direction.y,-direction.x)*(-1.0 if clockwise else 1.0)
		var length := p.distance_to(q)
		var rotation := -atan2(direction.y,direction.x)
		var middle := (p+q)*0.5
		if profile.style == "library":
			# Narrow opaque glass behind fine vertical metal screening; no alpha overdraw.
			var bays := maxi(1,roundi(length/2.0))
			for floor_index in floors:
				for bay in bays:
					var tall := floor_index in [1,2]
					var y := 0.9+floor_index*5.2
					var window_height := 3.9 if tall else 1.5
					if not tall and (bay+edge+floor_index)%3==0:
						continue
					var pos := p.lerp(q,(bay+0.5)/bays)+outward*0.08
					panel(builder,group,pos,y+window_height*0.5,Vector3(minf(0.85,length/bays*0.6),window_height,0.10),rotation,glass,"LibraryWindows")
			var fins := maxi(1,roundi(length/0.38))
			for fin in fins:
				panel(builder,group,p.lerp(q,(fin+0.5)/fins)+outward*0.18,height*0.5,Vector3(0.045,height-0.35,0.14),rotation,gold,"LibraryFins")
			for level in [0.3,5.7,10.9,16.1,21.7]:
				panel(builder,group,middle+outward*0.20,level,Vector3(length,0.13,0.22),rotation,metal,"LibraryBands")
			continue
		var bays := maxi(1,roundi(length/3.0))
		var spacing := length/bays
		for floor_index in floors:
			for bay in bays:
				var fraction := (bay+0.5)/bays
				# A01 central opening lacks a complete plan. Leave its shell undecorated.
				if profile.style == "teaching" and floor_index<4 and fraction>0.17 and fraction<0.73:
					continue
				var pos := p.lerp(q,fraction)+outward*0.08
				var window_height := height/floors*0.70
				var y := 0.7+floor_index*height/floors+window_height/2.0
				panel(builder,group,pos,y,Vector3(spacing*0.34,window_height,0.13),rotation,glass,"NarrowWindows")
				panel(builder,group,pos+outward*0.08,y,Vector3(0.06,window_height,0.14),rotation,metal,"WindowMullions")
				panel(builder,group,pos+outward*0.10,y-window_height/2.0,Vector3(spacing*0.38,0.09,0.22),rotation,pale,"WindowSills")
		for floor_index in range(floors+1):
			panel(builder,group,middle+outward*0.08,0.25+floor_index*(height-0.5)/floors,Vector3(length,0.11,0.12),rotation,metal,"FloorJoints")
		if profile.style == "teaching":
			for row in range(1,roundi(height/0.45)):
				panel(builder,group,middle+outward*0.025,row*0.45,Vector3(length,0.017,0.035),rotation,metal,"TerracottaJoints")
		elif profile.style == "laboratory" and edge in PackedInt32Array(profile.get("duct_edges",[5])):
			var count := maxi(1,roundi(length/9.0))
			for pipe in count:
				var pos := p.lerp(q,(pipe+0.4)/count)+outward*0.5
				var bottom := 8.5 if pipe%3==0 else 13.0
				panel(builder,group,pos,(bottom+height+0.7)/2.0,Vector3(0.30,height+0.7-bottom,0.30),rotation,pale,"ExtractDucts")
				panel(builder,group,pos+direction*0.48,bottom,Vector3(1.25,0.30,0.30),rotation,pale,"DuctOffsets")
				panel(builder,group,pos+direction*0.95,bottom-0.9,Vector3(0.30,1.8,0.30),rotation,pale,"DuctEnds")

func panel(builder, group: Node3D, pos: Vector2, y: float, size: Vector3, rotation: float, mat: Material, title: String) -> void:
	var node: MeshInstance3D = builder.box(group,Vector3(pos.x,y,pos.y),size,mat,title)
	node.rotation.y = rotation
