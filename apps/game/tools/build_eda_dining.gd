extends RefCounted

const Facade = preload("res://tools/eda_dining_curved_facade.gd")

func roof_railing(facade, start: float, finish: float, metal: Material) -> void:
	var width := finish-start
	for y in [12.45,12.95]:
		facade.panel((start+finish)/2,y,width,0.035,0.035,-0.08,metal)
	var posts := maxi(1,ceili(width/1.5))
	for i in posts+1:
		facade.panel(start+width*i/posts,12.57,0.035,0.78,0.035,-0.08,metal)

func southwest_roof_railing(facade, points: PackedVector2Array, edge: int, edges: Array[int], metal: Material) -> void:
	# Intersect the inset edge lines so adjacent railing sections share corners.
	var start := 0.0
	var finish: float = facade.length
	var previous := (edge+points.size()-1)%points.size()
	var following := (edge+1)%points.size()
	var inset: Vector2 = facade.origin-facade.out*0.08
	for neighbor in [previous,following]:
		if not edges.has(neighbor): continue
		var other := Facade.new()
		other.frame_for(points,neighbor)
		var cross: float = facade.axis.cross(other.axis)
		if absf(cross)<0.00001: continue
		var station: float = (other.origin-other.out*0.08-inset).cross(other.axis)/cross
		if neighbor==previous: start=station
		else: finish=station
	# Small overlaps close the outer corners of the rectangular horizontal bars.
	var rail_start := start-0.025 if edges.has(previous) else start
	var rail_end := finish+0.025 if edges.has(following) else finish
	for y in [12.22,12.78,12.95]:
		facade.panel((rail_start+rail_end)/2,y,rail_end-rail_start,0.035,0.035,-0.08,metal)
	var posts := maxi(1,ceili((finish-start)/1.5))
	var pitch: float = (finish-start)/posts
	for i in posts+1:
		if i==0 and edges.has(previous): continue
		facade.panel(start+pitch*i,12.57,0.035,0.78,0.035,-0.08,metal)
	for i in posts:
		for j in range(1,7):
			facade.panel(start+pitch*(i+j/7.0),12.5,0.018,0.56,0.018,-0.08,metal)

func build(host, group: Node3D, points: PackedVector2Array, registration: Dictionary = {}) -> void:
	var facade := Facade.new()
	facade.host = host
	facade.group = group
	facade.configure_curve(points,registration.get("curved_outline",{}))
	group.set_meta("photo_reference","references/eda/buildings/dining_profile.json")
	group.set_meta("interior_available",false)
	var wall: Material = host.material("EDA dining buff masonry",Color("b6aa7f"))
	var band: Material = host.material("EDA dining pale cornice",Color("c7bb93"))
	var glass: Material = host.material("EDA dining opaque glazing",Color("506a61"))
	var metal: Material = host.material("EDA dining window frames",Color("a4b0a0"))
	var railing: Material = host.material("EDA dining southwest roof railing",Color("a4b0a0"))
	railing.albedo_texture = null
	railing.cull_mode = BaseMaterial3D.CULL_BACK
	var curved_glass: Material = host.material("EDA dining curved blue glazing",Color("3c5d6c"))
	var curved_metal: Material = host.material("EDA dining curved dark frames",Color("343f40"))
	curved_glass.albedo_texture=null
	curved_glass.metallic=0.45
	curved_glass.roughness=0.24
	curved_metal.albedo_texture=null
	var sash: Material = host.material("EDA dining lower sash frames",Color("343f40"))
	sash.albedo_texture = null
	sash.cull_mode = BaseMaterial3D.CULL_BACK
	var plinth: Material = host.material("EDA dining stone plinth",Color("7b7b6b"))
	for mat in [wall,band,glass,metal,plinth]: mat.albedo_texture = null
	# Small square tiles only on the individually registered visible wall portions.
	var tile: Material = preload("res://tools/build_surface_materials.gd").new().material(host,"square_ceramic",Color("b6aa7f"))
	glass.metallic = 0.3
	glass.roughness = 0.3
	var outline: PackedVector2Array=facade.refined_outline(points)
	facade.shell(outline,12,0,wall)
	facade.shell(outline,12.18,12,band)
	# Only the photo-visible southwest arc is registered for glazing.
	var glazing_edges: Array[int] = []
	for edge in registration.get("glazing_edges",[0,1]): glazing_edges.append(int(edge))
	for edge in glazing_edges:
		facade.frame_for(points,edge)
		for y in [2.0,6.0,10.0]:
			facade.panel(facade.length/2,y,facade.length,2.9,0.1,0.1,curved_glass)
			var columns := ceili(facade.length/1.8)
			for i in columns+1:
				facade.panel(i*facade.length/columns,y,0.08,2.95,0.14,0.19,curved_metal)
			# Only the two upper floors have confirmed split lower lights.
			if y>=6.0:
				for i in columns:
					facade.panel((i+0.5)*facade.length/columns,y-0.925,0.045,0.95,0.14,0.19,sash)
			# Three glazing rows across the registered southwest arc.
			for dy in [-1.4,-0.45,0.45,1.4]:
				facade.panel(facade.length/2,y+dy,facade.length,0.08,0.14,0.19,curved_metal)
		for y in [4.0,8.0,12.0]:
			facade.panel(facade.length/2,y,facade.length,0.6,0.7,0.3,band,true)
		facade.panel(facade.length/2,0.3,facade.length,0.6,0.25,0.1,plinth)
		southwest_roof_railing(facade,points,edge,glazing_edges,railing)
	# Rectangular wing: only the portions visible in the official photograph.
	for face in registration.get("faces",[[11,-1,3,0.05,0.65],[10,-1,4,0.3,0.95]]):
		facade.frame_for(points,int(face[0]),int(face[1]))
		var start: float = facade.length*float(face[3])
		var finish: float = facade.length*float(face[4])
		var spacing: float = (finish-start)/int(face[2])
		facade.panel((start+finish)/2,6.2,finish-start,11.6,0.025,0.02,tile)
		roof_railing(facade,start,finish,metal)
		for y in [2.0,6.0,10.0]:
			for col in int(face[2]):
				var x := start+(col+0.5)*spacing
				facade.panel(x,y,2.1,2.6,0.1,0.1,glass)
				for dx in [-1.05,0.0,1.05]:
					facade.panel(x+dx,y,0.06,2.7,0.13,0.18,metal)
				for dy in [-1.3,-0.65,0.65,1.3]:
					facade.panel(x,y+dy,2.2,0.06,0.13,0.18,metal)
		for y in [4.0,8.0,12.0]:
			facade.panel((start+finish)/2,y,finish-start,0.35,0.4,0.18,band,true)
		facade.panel((start+finish)/2,0.3,finish-start,0.6,0.2,0.1,plinth)
	# The photo shows a raised divider beside the south wing's recessed bays.
	var divider_face: Array = registration.get("divider_face",[11,-1])
	facade.frame_for(points,int(divider_face[0]),int(divider_face[1]))
	var divider: float = facade.length*0.82
	facade.panel(divider,7.25,0.4,14.5,1.5,0.65,wall,true)
	for y in [4.0,8.0,12.0]:
		facade.panel(divider-3.0,y,6.0,0.35,1.5,0.65,band,true)
	for y in [6.0,10.0]:
		facade.panel(divider-1.0,y,1.2,2.6,0.1,0.1,glass)

	# Only the two nearest green ducts visible on the photographed east wall.
	var duct_face: Array = registration.get("duct_face",[10,-1])
	facade.frame_for(points,int(duct_face[0]),int(duct_face[1]))
	var duct: Material = host.material("EDA dining green ventilation ducts",Color("385542"))
	duct.albedo_texture = null
	duct.roughness = 0.7
	for fraction in [0.24,0.28]:
		var x: float = facade.length*fraction
		facade.panel(x,7.0,0.65,10.0,0.65,0.65,duct)
		for y in range(3,13):
			facade.panel(x,float(y),0.72,0.065,0.72,0.65,duct)
		# Quarter bend turns back toward the wall; hidden connections stop here.
		for segment in 8:
			var a := float(segment)*PI/16.0
			var b := float(segment+1)*PI/16.0
			var start := Vector3(0,12.0+0.65*sin(a),0.65*cos(a))
			var finish := Vector3(0,12.0+0.65*sin(b),0.65*cos(b))
			var center := (start+finish)*0.5
			var pos: Vector2 = facade.origin+facade.axis*x+facade.out*center.z
			var node: MeshInstance3D = host.box(group,Vector3(pos.x,center.y,pos.y),Vector3(0.65,start.distance_to(finish)+0.015,0.65),duct,"DiningDuctBend")
			var tangent := Vector3(facade.out.x*(finish.z-start.z),finish.y-start.y,facade.out.y*(finish.z-start.z)).normalized()
			var across := Vector3(facade.axis.x,0,facade.axis.y)
			node.basis = Basis(across,tangent,across.cross(tangent))
