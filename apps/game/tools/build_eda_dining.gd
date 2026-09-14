extends RefCounted

const Facade = preload("res://tools/build_eda_academic.gd")

func roof_railing(facade, start: float, finish: float, metal: Material) -> void:
	var width := finish-start
	for y in [12.45,12.95]:
		facade.panel((start+finish)/2,y,width,0.035,0.035,-0.08,metal)
	var posts := maxi(1,ceili(width/1.5))
	for i in posts+1:
		facade.panel(start+width*i/posts,12.57,0.035,0.78,0.035,-0.08,metal)

func build(host, group: Node3D, points: PackedVector2Array) -> void:
	var facade := Facade.new()
	facade.host = host
	facade.group = group
	group.set_meta("photo_reference","references/photos/dining_profile.json")
	group.set_meta("interior_available",false)
	var wall: Material = host.material("EDA dining buff masonry",Color("b6aa7f"))
	var band: Material = host.material("EDA dining pale cornice",Color("c7bb93"))
	var glass: Material = host.material("EDA dining opaque glazing",Color("506a61"))
	var metal: Material = host.material("EDA dining window frames",Color("a4b0a0"))
	var plinth: Material = host.material("EDA dining stone plinth",Color("7b7b6b"))
	for mat in [wall,band,glass,metal,plinth]: mat.albedo_texture = null
	# Small square tiles only on the individually registered visible wall portions.
	var tile: Material = host.material("EDA dining photographed square tiles",Color("b6aa7f"))
	var tile_image := Image.create(256,256,false,Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var joint := x%32 == 0 or y%32 == 0
			var tone := 0.77 if joint else 0.96+float((x/32*3+y/32*5)%7)*0.006
			tile_image.set_pixel(x,y,Color(tone,tone,tone))
	tile_image.generate_mipmaps()
	tile.albedo_texture = ImageTexture.create_from_image(tile_image)
	tile.uv1_scale = Vector3.ONE*1.25
	glass.metallic = 0.3
	glass.roughness = 0.3
	facade.shell(points,12,0,wall)
	facade.shell(points,12.18,12,band)
	# Visible southwest glazing follows the original polygon segments.
	for edge in [0,1]:
		facade.frame_for(points,edge)
		for y in [2.0,6.0,10.0]:
			facade.panel(facade.length/2,y,facade.length,2.9,0.1,0.1,glass)
			var columns := ceili(facade.length/1.8)
			for i in columns+1:
				facade.panel(i*facade.length/columns,y,0.08,2.95,0.14,0.19,metal)
			for dy in [-1.4,0.0,1.4]:
				facade.panel(facade.length/2,y+dy,facade.length,0.08,0.14,0.19,metal)
		for y in [4.0,8.0,12.0]:
			facade.panel(facade.length/2,y,facade.length,0.6,0.7,0.3,band,true)
		facade.panel(facade.length/2,0.3,facade.length,0.6,0.25,0.1,plinth)
		roof_railing(facade,0.0,facade.length,metal)
	# Rectangular wing: only the portions visible in the official photograph.
	for face in [[11,3,0.05,0.65],[10,4,0.3,0.95]]:
		facade.frame_for(points,int(face[0]))
		var start: float = facade.length*float(face[2])
		var finish: float = facade.length*float(face[3])
		var spacing: float = (finish-start)/int(face[1])
		facade.panel((start+finish)/2,6.2,finish-start,11.6,0.025,0.02,tile)
		roof_railing(facade,start,finish,metal)
		for y in [2.0,6.0,10.0]:
			for col in int(face[1]):
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
	facade.frame_for(points,11)
	var divider: float = facade.length*0.82
	facade.panel(divider,7.25,0.4,14.5,1.5,0.65,wall,true)
	for y in [4.0,8.0,12.0]:
		facade.panel(divider-3.0,y,6.0,0.35,1.5,0.65,band,true)
	for y in [6.0,10.0]:
		facade.panel(divider-1.0,y,1.2,2.6,0.1,0.1,glass)
