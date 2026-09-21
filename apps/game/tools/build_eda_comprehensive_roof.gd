extends RefCounted

func build(facade, points: PackedVector2Array, profile: Dictionary) -> void:
	var settings: Dictionary = profile.roof_enclosure
	facade.frame_for(points,int(profile.court_edge),int(profile.court_end_vertex))
	var start := float(settings.front_span[0]) * float(facade.length)
	var finish := float(settings.front_span[1]) * float(facade.length)
	var depth := float(settings.depth)
	var base := float(settings.base)
	var height := float(settings.height)
	var wall: Material = facade.host.material("EDA comprehensive grey masonry",Color("777c79"))
	var cap: Material = facade.host.material("EDA comprehensive pale bands",Color("c3c6b7"))
	var glass: Material = facade.host.material("EDA comprehensive opaque glass",Color("607e79"))
	var frame: Material = facade.host.material("EDA comprehensive dark frames",Color("333e3d"))
	# Negative offset keeps the closed exterior entirely over the existing roof.
	facade.panel((start+finish)*0.5,base+height*0.5,finish-start,height,depth,-depth*0.5,wall,true)
	facade.group.get_child(facade.group.get_child_count()-1).name = "ComprehensiveRoofEnclosure"
	var cap_height := float(settings.cap_height)
	facade.panel((start+finish)*0.5,base+height+cap_height*0.5,finish-start,cap_height,depth,-depth*0.5,cap,true)
	facade.group.get_child(facade.group.get_child_count()-1).name = "ComprehensiveRoofCap"
	var window_width := float(settings.window_width)
	var window_height := float(settings.window_height)
	var y := base+float(settings.window_center_above_base)
	for fraction in settings.front_window_fractions:
		var x := lerpf(start,finish,float(fraction))
		facade.panel(x,y,window_width+0.12,window_height+0.12,0.06,0.035,frame)
		facade.panel(x,y,window_width,window_height,0.04,0.075,glass)
		facade.group.get_child(facade.group.get_child_count()-1).name = "ComprehensiveRoofWindow"
		facade.panel(x,y,0.045,window_height,0.04,0.11,frame)
		facade.panel(x,y+window_height*0.23,window_width,0.045,0.04,0.11,frame)
