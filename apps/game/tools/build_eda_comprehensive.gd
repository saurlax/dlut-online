extends RefCounted

const Facade = preload("res://tools/build_eda_academic.gd")

func build(host, group: Node3D, points: PackedVector2Array, profile: Dictionary) -> void:
	assert(points.size() == int(profile.get("expected_vertices",points.size())),"Comprehensive footprint/profile mismatch")
	var facade := Facade.new()
	facade.host = host
	facade.group = group
	group.set_meta("photo_reference","references/eda/buildings/comprehensive_profile.json")
	group.set_meta("interior_available",false)
	if profile.has("osm_id"):
		group.set_meta("osm_id",profile.osm_id)
		group.set_meta("osm_version",profile.osm_version)
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
	var court_edge := int(profile.get("court_edge",5))
	var court_end_vertex := int(profile.get("court_end_vertex",-1))
	var glass_center_fraction := float(profile.get("court_glass_center_fraction",0.3))
	for face in profile.faces:
		facade.frame_for(points,int(face.edge),int(face.get("end_vertex",-1)))
		var start: float = face.span[0]*facade.length
		var finish: float = face.span[1]*facade.length
		var spacing: float = (finish-start)/int(face.columns)
		var width := minf(2.1,spacing*0.52)
		for row in 4:
			var y := 6.2+row*4.0
			var stations: Array = []
			if face.has("window_stations_by_row"):
				stations=face.window_stations_by_row[row]
			else:
				for col in int(face.columns): stations.append((start+(col+0.5)*spacing)/facade.length)
			for fraction in stations:
				var x := float(fraction)*facade.length
				var window_width := width
				for region in face.get("window_width_regions",[]):
					if float(fraction)>=float(region.span[0]) and float(fraction)<=float(region.span[1]): window_width=float(region.width)
				if int(face.edge)==court_edge and row<3 and absf(x-facade.length*glass_center_fraction)<8.7: continue
				facade.panel(x,y,window_width+0.16,2.36,0.08,0.08,frame)
				facade.panel(x,y,window_width,2.2,0.06,0.14,glass)
				facade.panel(x,y,0.07,2.2,0.08,0.2,frame)
				facade.panel(x,y+0.62,window_width,0.07,0.08,0.2,frame)
			facade.panel(facade.length/2,y-1.6,facade.length,0.18,0.16,0.1,band)
		facade.panel(facade.length/2,20.09,facade.length,0.18,0.35,0.1,band,true)
	# The courtyard wing ends in two columns of short high windows, not full bays.
	var end_windows: Dictionary = profile.court_end_windows
	facade.frame_for(points,int(end_windows.edge))
	for fraction in end_windows.fractions:
		var x := float(fraction)*facade.length
		var width: float = end_windows.width
		var window_height: float = end_windows.height
		for y in end_windows.centers_y:
			facade.panel(x,float(y),width+0.14,window_height+0.14,0.08,0.08,frame)
			facade.panel(x,float(y),width,window_height,0.06,0.14,glass)
			facade.panel(x,float(y),0.055,window_height,0.08,0.2,frame)
	# Photo 77921-1 confirms the large pale frames on this outer face only.
	facade.frame_for(points,int(profile.get("outer_edge",14)),int(profile.get("outer_end_vertex",-1)))
	for fraction in [0.28,0.43,0.58,0.73]:
		facade.panel(fraction*facade.length,9.8,0.6,13.0,0.7,0.4,band,true)
	for y in [4.0,8.0,12.0,16.0]:
		facade.panel(0.505*facade.length,y,0.45*facade.length,0.5,0.7,0.4,band,true)
	# Closed three-storey glass projection on the court-side wing. The photo
	# does not establish an interior or a walkable entrance behind the glass.
	facade.frame_for(points,court_edge,court_end_vertex)
	var center: float = facade.length*glass_center_fraction
	facade.panel(center,10.0,17,12,1.4,0.6,wall,true)
	facade.panel(center,10.0,16.7,11.7,0.08,1.35,glass)
	for i in 10:
		facade.panel(center-8.35+i*16.7/9,10,0.08,11.8,0.12,1.44,metal)
	for y in [4.15,6.1,8.05,10.0,11.95,13.9,15.85]:
		facade.panel(center,y,16.8,0.08,0.12,1.44,metal)
	facade.panel(center,16.1,17.3,0.25,1.7,0.6,band,true)

	if profile.has("entry_canopy"):
		preload("res://tools/build_eda_comprehensive_canopy.gd").new().build(facade,center,profile.entry_canopy)

	if profile.has("roof_enclosure"):
		preload("res://tools/build_eda_comprehensive_roof.gd").new().build(facade,points,profile)

	if profile.has("round_annex"):
		preload("res://tools/build_eda_comprehensive_annex.gd").new().build(host,group,points,profile)
