extends RefCounted

var host
var group: Node3D
var origin: Vector2
var axis: Vector2
var out: Vector2
var length: float

func frame_for(points: PackedVector2Array, edge: int) -> void:
	origin = points[edge]
	var end := points[(edge+1)%points.size()]
	axis = (end-origin).normalized()
	length = origin.distance_to(end)
	out = Vector2(axis.y,-axis.x)
	if Geometry2D.is_point_in_polygon((origin+end)/2.0+out,points): out = -out

func panel(x: float, y: float, width: float, height: float, depth: float, offset: float, mat: Material, solid := false) -> void:
	var p := origin+axis*x+out*offset
	var node: MeshInstance3D = host.box(group,Vector3(p.x,y,p.y),Vector3(width,height,depth),mat,"AcademicDetail")
	if mat.resource_name.begins_with("Surface square_ceramic "):
		preload("res://tools/build_surface_materials.gd").new().map_box(node,Vector2(x,y))
	node.rotation.y = -atan2(axis.y,axis.x)
	node.set_meta("walk_collision",solid)

func shell(points: PackedVector2Array, top: float, base: float, mat: Material) -> void:
	host.polygon(group,points,top,mat,"AcademicShell",base)
	var node: MeshInstance3D = group.get_child(group.get_child_count()-1)
	var surface := SurfaceTool.new()
	surface.create_from(node.mesh,0)
	surface.index()
	node.mesh = surface.commit()
	node.set_meta("walk_collision",true)

func build(builder, parent: Node3D, points: PackedVector2Array, profile: Dictionary) -> void:
	host = builder
	group = parent
	group.set_meta("photo_reference","references/eda/buildings/academic_facades.json")
	group.set_meta("interior_available",false)
	var wall: Material = host.material("EDA academic "+str(profile.color),Color(profile.color))
	var stone: Material = host.material("EDA academic pale bands",Color("b6b7a7"))
	var glass: Material = host.material("EDA academic opaque glazing",Color("42575a"))
	var metal: Material = host.material("EDA academic window metal",Color("a3aca8"))
	for mat in [wall,stone,glass,metal]: mat.albedo_texture = null
	glass.metallic = 0.35
	glass.roughness = 0.3
	var height: float = profile.height
	var recess: Dictionary = profile.get("recess",{})
	if recess.is_empty():
		shell(points,height,0,wall)
	else:
		frame_for(points,int(recess.edge))
		var recessed := PackedVector2Array()
		for i in points.size():
			recessed.append(points[i])
			if i==int(recess.edge):
				var a := origin+axis*length*float(recess.span[0])
				var b := origin+axis*length*float(recess.span[1])
				recessed.append(a)
				recessed.append(a-out*float(recess.depth))
				recessed.append(b-out*float(recess.depth))
				recessed.append(b)
		shell(points,float(recess.bottom),0,wall)
		shell(recessed,float(recess.top),float(recess.bottom),wall)
		shell(points,height,float(recess.top),wall)
	shell(points,height+0.18,height,stone)
	for face in profile.faces:
		frame_for(points,int(face.edge))
		var start: float = face.span[0]*length
		var finish: float = face.span[1]*length
		var spacing: float = (finish-start)/int(face.columns)
		var width: float = spacing*float(face.width_ratio)
		var wh: float = face.window_height
		for row in int(face.rows):
			var y: float = face.first_y+row*face.storey
			for col in int(face.columns):
				var x := start+(col+0.5)*spacing
				if profile.has("tower") and absf(x-float(profile.tower.fraction)*length)<float(profile.tower.width)*0.6: continue
				var inset := 0.0
				if not recess.is_empty() and int(face.edge)==int(recess.edge) and y>float(recess.bottom) and y<float(recess.top) and x>length*float(recess.span[0]) and x<length*float(recess.span[1]):
					inset = float(recess.depth)
				panel(x,y,width,wh,0.08,0.08-inset,glass)
				for dx in [-width/2.0,0.0,width/2.0]: panel(x+dx,y,0.06,wh+0.1,0.12,0.16-inset,metal)
				for dy in [-wh/2.0,wh*0.25,wh/2.0]: panel(x,y+dy,width+0.12,0.065,0.14,0.16-inset,metal)
				panel(x,y-wh/2.0-0.1,width+0.22,0.16,0.24,0.17-inset,stone)
			var band_y := y-wh/2.0-0.45
			if not recess.is_empty() and int(face.edge)==int(recess.edge) and band_y>float(recess.bottom) and band_y<float(recess.top):
				var cut_a: float = length*float(recess.span[0])
				var cut_b: float = length*float(recess.span[1])
				for part in [[start,minf(finish,cut_a),0.0],[maxf(start,cut_a),minf(finish,cut_b),-float(recess.depth)],[maxf(start,cut_b),finish,0.0]]:
					if float(part[1])>float(part[0]): panel((float(part[0])+float(part[1]))/2,band_y,float(part[1])-float(part[0]),0.18,0.16,0.12+float(part[2]),stone)
			else:
				panel((start+finish)/2.0,band_y,finish-start,0.18,0.16,0.12,stone)
		panel((start+finish)/2.0,height+0.09,finish-start,0.18,0.8,0.25,stone,true)
	if profile.has("tower"):
		var tower: Dictionary = profile.tower
		frame_for(points,int(tower.edge))
		var x: float = tower.fraction*length
		var top: float = tower.height
		var width: float = tower.width
		var body_top: float = tower.get("body_height",top)
		panel(x,body_top/2.0,width,body_top,2.0,0.0,wall,true)
		panel(x,body_top/2.0,width-0.6,body_top-1.0,0.1,1.06,glass)
		for dx in [-width/2.0,0.0,width/2.0]: panel(x+dx,body_top/2.0,0.18,body_top+0.6,0.25,1.16,stone)
		for i in range(1,15): panel(x,float(i)*(body_top-0.5)/15.0,width,0.09,0.18,1.2,metal)
		panel(x,body_top+0.1,width+0.4,0.2,2.3,0.0,stone,true)
		if tower.has("body_height"):
			for dx in [-width/2,width/2]:
				panel(x+dx,(body_top+top+0.3)/2,0.2,top+0.3-body_top,2.3,0.0,stone,true)
			panel(x,float(tower.head_beam_y),width,0.2,2.3,0.0,stone,true)
	if profile.has("rotunda"):
		var rotunda: Dictionary = profile.rotunda
		for edge in rotunda.edges:
			frame_for(points,int(edge))
			for y in rotunda.bands:
				panel(length/2,float(y),length+0.12,0.24,1.0,0.38,stone,true)
			# A dark upper recess, kept closed without claiming usable space.
			panel(length/2,23.65,length,0.9,0.08,0.07,glass)
			if int(edge)%2==0:
				panel(length/2,23.65,0.3,1.2,0.4,0.22,stone,true)
		for edge in rotunda.window_edges:
			frame_for(points,int(edge))
			var columns := maxi(1,ceili(length/1.5))
			for y in rotunda.window_centers:
				panel(length/2,float(y),length,2.4,0.08,0.08,glass)
				for i in columns+1:
					panel(i*length/columns,float(y),0.06,2.45,0.12,0.16,metal)
				for dy in [-1.2,0.4,1.2]:
					panel(length/2,float(y)+dy,length,0.06,0.12,0.16,metal)
		for edge in rotunda.column_edges:
			frame_for(points,int(edge))
			panel(length/2,4.4,0.7,8.8,0.7,0.48,stone,true)
	for bay in profile.get("court_bays",[]):
		frame_for(points,int(bay.edge))
		var start: float = length*float(bay.span[0])
		var finish: float = length*float(bay.span[1])
		var center := (start+finish)/2
		var width := (finish-start)*0.78
		for y in [2.2,6.6]:
			panel(center,y,width,2.3,0.08,0.08,glass)
			for i in 9:
				panel(center-width/2+i*width/8,y,0.07,2.4,0.12,0.17,metal)
			for dy in [-1.15,0.5,1.15]:
				panel(center,y+dy,width+0.1,0.07,0.12,0.17,metal)
			panel(center,y-1.5,width,0.55,0.16,0.14,stone)
		for x in [start,finish]:
			panel(x,height/2,0.4,height,0.8,0.4,wall,true)
		panel(center,4.4,finish-start,0.28,0.8,0.35,stone,true)
		panel(center,height+0.16,finish-start+0.4,0.22,1.2,0.45,stone,true)

	for canopy in profile.get("canopies",[]):
		frame_for(points,int(canopy.edge))
		var center: float = length*float(canopy.fraction)
		var width: float = canopy.width
		var projection: float = canopy.projection
		var y: float = canopy.y
		for x in [center-width/2,center+width/2]:
			panel(x,y,0.16,0.18,projection,projection/2,stone,true)
		for i in 4:
			panel(center,y,width,0.14,0.14,0.1+(projection-0.2)*i/3,stone,true)
