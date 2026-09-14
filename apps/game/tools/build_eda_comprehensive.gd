extends RefCounted

const Facade = preload("res://tools/build_eda_academic.gd")

func build(host, group: Node3D, points: PackedVector2Array, profile: Dictionary) -> void:
	var facade := Facade.new()
	facade.host = host
	facade.group = group
	group.set_meta("photo_reference","references/photos/comprehensive_profile.json")
	group.set_meta("interior_available",false)
	var wall: Material = host.material("EDA comprehensive grey masonry",Color("777c79"))
	var band: Material = host.material("EDA comprehensive pale bands",Color("c3c6b7"))
	var glass: Material = host.material("EDA comprehensive opaque glass",Color("607e79"))
	var frame: Material = host.material("EDA comprehensive dark frames",Color("333e3d"))
	var metal: Material = host.material("EDA comprehensive metal",Color("aebeb8"))
	for mat in [wall,band,glass,frame,metal]: mat.albedo_texture = null
	glass.metallic = 0.3
	glass.roughness = 0.28
	facade.shell(points,float(profile.height),0,wall)
	facade.shell(points,float(profile.height)+0.18,float(profile.height),band)
	for face in profile.faces:
		facade.frame_for(points,int(face.edge))
		var start: float = face.span[0]*facade.length
		var finish: float = face.span[1]*facade.length
		var spacing: float = (finish-start)/int(face.columns)
		var width := minf(2.1,spacing*0.52)
		for row in 4:
			var y := 6.2+row*4.0
			for col in int(face.columns):
				var x := start+(col+0.5)*spacing
				if int(face.edge)==5 and row<3 and absf(x-facade.length*0.3)<8.7: continue
				facade.panel(x,y,width+0.16,2.36,0.08,0.08,frame)
				facade.panel(x,y,width,2.2,0.06,0.14,glass)
				facade.panel(x,y,0.07,2.2,0.08,0.2,frame)
				facade.panel(x,y+0.62,width,0.07,0.08,0.2,frame)
			facade.panel(facade.length/2,y-1.6,facade.length,0.18,0.16,0.1,band)
		facade.panel(facade.length/2,20.09,facade.length,0.18,0.35,0.1,band,true)
	# Photo 77921-1 confirms the large pale frames on this outer face only.
	facade.frame_for(points,14)
	for fraction in [0.28,0.43,0.58,0.73]:
		facade.panel(fraction*facade.length,9.8,0.6,13.0,0.7,0.4,band,true)
	for y in [4.0,8.0,12.0,16.0]:
		facade.panel(0.505*facade.length,y,0.45*facade.length,0.5,0.7,0.4,band,true)
	# Closed three-storey glass projection on the court-side wing. The photo
	# does not establish an interior or a walkable entrance behind the glass.
	facade.frame_for(points,5)
	var center: float = facade.length*0.3
	facade.panel(center,10.0,17,12,1.4,0.6,wall,true)
	facade.panel(center,10.0,16.7,11.7,0.08,1.35,glass)
	for i in 10:
		facade.panel(center-8.35+i*16.7/9,10,0.08,11.8,0.12,1.44,metal)
	for y in [4.15,6.1,8.05,10.0,11.95,13.9,15.85]:
		facade.panel(center,y,16.8,0.08,0.12,1.44,metal)
	facade.panel(center,16.1,17.3,0.25,1.7,0.6,band,true)
