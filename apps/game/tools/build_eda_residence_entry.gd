extends RefCounted

func build(facade, settings: Dictionary, reuse_facade_materials := false) -> void:
	var x := float(settings.fraction)*float(facade.facade_path.length)
	var width := float(settings.width)
	var height := float(settings.height)
	var bottom := float(settings.bottom)
	var transom := float(settings.transom_height)
	var border := float(settings.frame_width)
	var backing: StandardMaterial3D
	var glazing: StandardMaterial3D
	var frame: StandardMaterial3D
	if reuse_facade_materials:
		backing=facade.rail
		glazing=facade.glass
		frame=facade.frame
	else:
		backing = facade.host.material("Residence courtyard entrance backing",Color("303936"))
		glazing = facade.host.material("Residence courtyard entrance glazing",Color("536661"))
		frame = facade.host.material("Residence courtyard entrance frame",Color("bec1b5"))
		for mat in [backing,glazing,frame]:
			mat.albedo_texture=null
			mat.cull_mode=BaseMaterial3D.CULL_BACK
		glazing.metallic=0.35
		glazing.roughness=0.28
		frame.metallic=0.45
		frame.roughness=0.4
	# An exterior closed door assembly; the existing building shell remains intact.
	facade.panel(x,bottom+height*0.5,width,height,0.08,0.06,backing)
	var lower_height := height-transom-border*1.5
	for side in [-1.0,1.0]:
		facade.panel(x+side*width*0.25,bottom+border+lower_height*0.5,width*0.5-border*1.5,lower_height,0.035,0.12,glazing)
	facade.panel(x,bottom+height-transom*0.5-border*0.5,width-border*2,transom-border,0.035,0.12,glazing)
	for side in [-1.0,1.0]:
		facade.panel(x+side*(width-border)*0.5,bottom+height*0.5,border,height,0.07,0.17,frame)
	facade.panel(x,bottom+(height-transom)*0.5,border,height-transom,0.07,0.17,frame)
	for y in [bottom+border*0.5,bottom+height-transom,bottom+height-border*0.5]:
		facade.panel(x,y,width,border,0.07,0.17,frame)
