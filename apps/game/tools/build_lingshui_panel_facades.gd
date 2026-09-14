extends RefCounted

# Every row and edge is explicitly selected from a named building's source photos.
# No automatic whole-building window grid; unlisted faces retain the source mass.
func build(builder, group: Node3D, points: PackedVector2Array, profile: Dictionary) -> void:
	var glass: Material = builder.material("Window glass",Color("354951"))
	var frame: Material = builder.material("Photo facade frames " + profile.frame_color,Color(profile.frame_color))
	var trim: Material = builder.material("Photo facade trim " + profile.trim_color,Color(profile.trim_color))
	if profile.get("frame_finish","") == "metal":
		var smooth_frame: StandardMaterial3D = builder.material("Photo smooth frame " + profile.frame_color,Color(profile.frame_color))
		smooth_frame.albedo_texture = null
		smooth_frame.metallic = 0.35
		smooth_frame.roughness = 0.45
		frame = smooth_frame
	if profile.get("trim_finish","") == "smooth":
		var smooth_trim: StandardMaterial3D = builder.material("Photo smooth trim " + profile.trim_color,Color(profile.trim_color))
		smooth_trim.albedo_texture = null
		trim = smooth_trim
	var clockwise := Geometry2D.is_polygon_clockwise(points)
	var cladding := preload("res://tools/build_lingshui_cladding.gd").new()
	var platforms := preload("res://tools/build_lingshui_window_platforms.gd").new()
	var balconies := preload("res://tools/build_lingshui_balconies.gd").new()
	var grilles := preload("res://tools/build_lingshui_window_grilles.gd").new()
	for face in profile.panels:
		var edge := int(face.edge)
		var p := points[edge]
		var q := points[(edge+1)%points.size()]
		var direction := (q-p).normalized()
		var outward := Vector2(direction.y,-direction.x) * (-1.0 if clockwise else 1.0)
		var rotation := -atan2(direction.y,direction.x)
		cladding.build(builder,group,p,q,outward,face)
		platforms.build(builder,group,p,q,outward,face.get("window_platforms",[]))
		balconies.build(builder,group,p,q,outward,face.get("balconies",[]))
		for row in face.rows:
			var count := int(row.count)
			var width: float = row.width
			var height: float = row.height
			var bottom: float = row.bottom
			for i in count:
				var fraction := lerpf(float(row.get("from",0.0)),float(row.get("to",1.0)),(i+0.5)/count)
				var projection := float(row.get("projection",0.0))
				var anchor := p.lerp(q,fraction)
				var pos := anchor+outward*(0.08+projection)
				if projection > 0.0:
					bay_sides(builder,group,anchor,direction,outward,bottom,width,height,projection,rotation,glass,frame)
				panel(builder,group,pos,bottom+height/2,Vector3(width,height,0.14),rotation,glass)
				for side in [-1,1]:
					panel(builder,group,pos+direction*side*width/2+outward*0.09,bottom+height/2,Vector3(0.075,height+0.10,0.15),rotation,frame)
				for division in range(1,int(row.get("divisions",2))):
					panel(builder,group,pos+direction*width*(float(division)/int(row.get("divisions",2))-0.5)+outward*0.09,bottom+height/2,Vector3(0.055,height,0.15),rotation,frame)
				for y in [bottom,bottom+height]:
					panel(builder,group,pos+outward*0.10,y,Vector3(width+0.10,0.075,0.17),rotation,frame)
				var horizontal_fractions: Array = row.get("horizontal_fractions",[0.72] if row.get("transom",false) else [])
				for fraction_y in horizontal_fractions:
					panel(builder,group,pos+outward*0.10,bottom+height*float(fraction_y),Vector3(width,0.06,0.17),rotation,frame)
				if row.has("sill"):
					panel(builder,group,pos+outward*0.12,bottom-0.12,Vector3(width+0.24,0.20,float(row.sill)),rotation,trim)
				if row.has("apron"):
					panel(builder,group,pos+outward*0.05,bottom-float(row.apron)/2,Vector3(width,float(row.apron),0.16),rotation,trim)
				if row.has("grille"):
					grilles.build(builder,group,pos,direction,outward,bottom,width,height,row.grille)
		for band in face.get("bands",[]):
			var band_node := panel(builder,group,(p+q)*0.5+outward*float(band.get("projection",0.12)),float(band.y),Vector3(p.distance_to(q),float(band.height),float(band.get("depth",0.22))),rotation,trim)
			if band.get("structural",false):
				band_node.set_meta("walk_collision",true)
		for accent in face.get("accents",[]):
			var accent_material: Material = trim
			if accent.has("tile_color"):
				accent_material = preload("res://tools/build_lingshui_tile_material.gd").new().build(builder,str(accent.tile_color))
			if accent.has("metal_color"):
				var metal: StandardMaterial3D = builder.material("Photo facade metal " + str(accent.metal_color),Color(str(accent.metal_color)))
				metal.albedo_texture = null
				metal.metallic = 0.35
				metal.roughness = 0.45
				accent_material = metal
			panel(builder,group,p.lerp(q,float(accent.fraction))+outward*0.17,float(accent.y),Vector3(accent.size[0],accent.size[1],accent.size[2]),rotation,accent_material)
		# Shallow elliptical trim seen on the named facade, separate from collision.
		for arch in face.get("arches",[]):
			var center := p.lerp(q,float(arch.center))+outward*0.22
			var segments := int(arch.segments)
			for i in segments:
				var a := PI * i / segments
				var b := PI * (i+1) / segments
				var start := Vector2(cos(a)*float(arch.half_width),sin(a)*float(arch.rise))
				var end := Vector2(cos(b)*float(arch.half_width),sin(b)*float(arch.rise))
				var mid := (start+end)*0.5
				var pos := center+direction*mid.x
				var node: MeshInstance3D = builder.box(group,Vector3(pos.x,float(arch.bottom)+mid.y,pos.y),Vector3(start.distance_to(end)+0.02,float(arch.thickness),float(arch.depth)),trim,"PhotoFacadeDetail")
				node.basis = Basis(Vector3.UP,rotation)*Basis(Vector3.BACK,(end-start).angle())

	# A continuous miter avoids coplanar overlap and gaps at photographed corners.
	for band in profile.get("corner_bands",[]):
		var vertex := int(band.vertex)
		var corner := points[vertex]
		var previous := points[(vertex-1+points.size())%points.size()]
		var following := points[(vertex+1)%points.size()]
		var incoming := (corner-previous).normalized()
		var outgoing := (following-corner).normalized()
		var sign_value := -1.0 if clockwise else 1.0
		var normal_a := Vector2(incoming.y,-incoming.x)*sign_value
		var normal_b := Vector2(outgoing.y,-outgoing.x)*sign_value
		var start := previous.lerp(corner,float(band.previous_from))
		var end := corner.lerp(following,float(band.next_to))
		var outer := float(band.projection)+float(band.depth)/2.0
		var inner := float(band.projection)-float(band.depth)/2.0
		var outer_join: Variant = Geometry2D.line_intersects_line(corner+normal_a*outer,incoming,corner+normal_b*outer,outgoing)
		var inner_join: Variant = Geometry2D.line_intersects_line(corner+normal_a*inner,incoming,corner+normal_b*inner,outgoing)
		assert(outer_join != null and inner_join != null,"Corner band requires nonparallel edges")
		var outline := PackedVector2Array([start+normal_a*outer,outer_join,end+normal_b*outer,end+normal_b*inner,inner_join,start+normal_a*inner])
		builder.polygon(group,outline,float(band.bottom)+float(band.height),trim,"PhotoCornerCornice",float(band.bottom))

func panel(builder, group: Node3D, pos: Vector2, y: float, size: Vector3, rotation: float, mat: Material) -> MeshInstance3D:
	var node: MeshInstance3D = builder.box(group,Vector3(pos.x,y,pos.y),size,mat,"PhotoFacadeDetail")
	node.rotation.y = rotation
	return node

# Shallow enclosed bay windows are facade decoration, not walkable balconies.
func bay_sides(builder, group: Node3D, anchor: Vector2, direction: Vector2, outward: Vector2, bottom: float, width: float, height: float, depth: float, rotation: float, glass: Material, frame: Material) -> void:
	var center := anchor+outward*(0.08+depth/2)
	for side in [-1,1]:
		var end: Vector2 = center+direction*side*width/2
		panel(builder,group,end,bottom+height/2,Vector3(0.07,height,depth),rotation,glass)
		panel(builder,group,anchor+direction*side*width/2+outward*0.08,bottom+height/2,Vector3(0.075,height,0.075),rotation,frame)
	for y in [bottom,bottom+height]:
		panel(builder,group,center,y,Vector3(width+0.15,0.12,depth+0.18),rotation,frame)
