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
	group.set_meta("photo_reference","references/photos/academic_facades.json")
	group.set_meta("interior_available",false)
	var wall: Material = host.material("EDA academic "+str(profile.color),Color(profile.color))
	var stone: Material = host.material("EDA academic pale bands",Color("b6b7a7"))
	var glass: Material = host.material("EDA academic opaque glazing",Color("42575a"))
	var metal: Material = host.material("EDA academic window metal",Color("a3aca8"))
	for mat in [wall,stone,glass,metal]: mat.albedo_texture = null
	glass.metallic = 0.35
	glass.roughness = 0.3
	var height: float = profile.height
	shell(points,height,0,wall)
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
				panel(x,y,width,wh,0.08,0.08,glass)
				for dx in [-width/2.0,0.0,width/2.0]: panel(x+dx,y,0.06,wh+0.1,0.12,0.16,metal)
				for dy in [-wh/2.0,wh*0.25,wh/2.0]: panel(x,y+dy,width+0.12,0.065,0.14,0.16,metal)
				panel(x,y-wh/2.0-0.1,width+0.22,0.16,0.24,0.17,stone)
			panel((start+finish)/2.0,y-wh/2.0-0.45,finish-start,0.18,0.16,0.12,stone)
		panel((start+finish)/2.0,height+0.09,finish-start,0.18,0.8,0.25,stone,true)
	if profile.has("tower"):
		var tower: Dictionary = profile.tower
		frame_for(points,int(tower.edge))
		var x: float = tower.fraction*length
		var top: float = tower.height
		var width: float = tower.width
		panel(x,top/2.0,width,top,2.0,0.0,wall,true)
		panel(x,top/2.0,width-0.6,top-1.0,0.1,1.06,glass)
		for dx in [-width/2.0,0.0,width/2.0]: panel(x+dx,top/2.0,0.18,top+0.6,0.25,1.16,stone)
		for i in range(1,15): panel(x,float(i)*(top-0.5)/15.0,width,0.09,0.18,1.2,metal)
		panel(x,top+0.1,width+0.4,0.2,2.3,0.0,stone,true)
