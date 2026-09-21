extends RefCounted

func build(facade, points: PackedVector2Array, profile: Dictionary, glass: Material, metal: Material, pale: Material) -> void:
	facade.frame_for(points,int(profile.edge))
	var center: float = facade.length*float(profile.fraction)
	var pitch: float = profile.bay_pitch
	var width: float = profile.bay_width
	for bank in 3:
		var x := center+(bank-1)*pitch
		for level in 2:
			var bottom := 0.15 if level==0 else 4.6
			var top := 3.55 if level==0 else 7.8
			var height := top-bottom
			var y := (top+bottom)/2.0
			var columns := 6 if bank==1 and level==0 else 4
			var opened := bool(profile.get("open_entry",false)) and bank==1 and level==0
			if opened:
				open_center(facade,x,width,glass,metal)
			else:
				facade.panel(x,y,width,height,0.08,0.08,glass)
				for i in columns+1:
					facade.panel(x-width/2+width*i/columns,y,0.055,height+0.06,0.12,0.16,metal)
				var bars := [bottom,2.7,top] if bank==1 and level==0 else [bottom,bottom+height/3,bottom+height*2/3,top]
				for h in bars: facade.panel(x,float(h),width+0.06,0.055,0.12,0.16,metal)
			for edge in [-1.0,1.0]: facade.panel(x+edge*(width/2+0.12),y,0.12,height+0.14,0.12,0.07,pale)
		# Keep the closed-door handles only when the central leaves remain closed.
		if bank==1 and not bool(profile.get("open_entry",false)):
			for joint in [-width/6,width/6]:
				for side in [-1.0,1.0]: facade.panel(x+joint+side*0.10,1.35,0.025,0.65,0.035,0.245,metal)
	var roof: StandardMaterial3D = facade.host.material("Academic entry canopy glazing",Color("8b9b90"))
	roof.albedo_texture=null
	roof.metallic=0.25
	roof.roughness=0.3
	var canopy_width: float = profile.canopy_width
	var projection: float = profile.canopy_projection
	var canopy_y: float = profile.canopy_y
	facade.panel(center,canopy_y,canopy_width,0.08,projection,projection/2,roof,true)
	for i in 19:
		facade.panel(center-canopy_width/2+canopy_width*i/18,canopy_y,0.055,0.14,projection+0.08,projection/2,pale)
	for offset in [0.0,projection/2,projection]:
		facade.panel(center,canopy_y,canopy_width+0.12,0.14,0.055,float(offset),pale)
	for i in 4:
		var x := center+(i-1.5)*pitch
		var wall: Vector2 = facade.origin+facade.axis*x+facade.out*0.2
		var tip: Vector2 = facade.origin+facade.axis*x+facade.out*(projection-0.15)
		var a := Vector3(wall.x,6.0,wall.y)
		var b := Vector3(tip.x,canopy_y+0.1,tip.y)
		var direction := (b-a).normalized()
		var right := Vector3(facade.axis.x,0,facade.axis.y)
		var rod: MeshInstance3D = facade.host.box(facade.group,(a+b)/2,Vector3(0.045,a.distance_to(b),0.045),pale,"AcademicCanopyRod")
		rod.basis=Basis(right,direction,right.cross(direction))
		rod.set_meta("walk_collision",false)
	# Persistent housing below the canopy lip; no transient message is baked in.
	var display: Dictionary = profile.get("display_housing",{})
	if not display.is_empty():
		var housing: Material = facade.host.material("Academic entry display housing",Color("202524"))
		var screen: Material = facade.host.material("Academic entry inactive display",Color("101516"))
		for material in [housing,screen]:
			material.albedo_texture = null
			material.cull_mode = BaseMaterial3D.CULL_BACK
		screen.roughness = 0.45
		var panel_width: float = display.width
		var panel_height: float = display.height
		var panel_y: float = canopy_y-0.04-panel_height/2.0
		facade.panel(center,panel_y,panel_width,panel_height,0.1,projection,housing)
		facade.panel(center,panel_y,panel_width-0.08,panel_height-0.08,0.014,projection+0.058,screen)

func open_center(facade, x: float, width: float, glass: Material, metal: Material) -> void:
	var leaf_width := width/6.0
	var bottom := .15
	var door_top := 2.7
	var top := 3.55
	var door_height := door_top-bottom
	# Fixed sidelights occupy two original columns on each side; the transom stays whole.
	for side in [-1.0,1.0]:
		var side_center: float = x+side*width/3.0
		facade.panel(side_center,(bottom+door_top)*.5,width/3.0,door_height,.08,.08,glass)
		facade.panel(side_center,bottom,width/3.0,.055,.12,.16,metal)
	facade.panel(x,(door_top+top)*.5,width,top-door_top,.08,.08,glass)
	for i in 7:
		var at := x-width*.5+width*i/6.0
		if i==3:
			facade.panel(at,(door_top+top)*.5,.055,top-door_top+.06,.12,.16,metal)
		else:
			# Put the two jamb frames outside the clear 1.6 m opening.
			if i==2: at-=.0275
			if i==4: at+=.0275
			facade.panel(at,(bottom+top)*.5,.055,top-bottom+.06,.12,.16,metal)
	for y in [door_top,top]:
		facade.panel(x,y,width+.06,.055,.12,.16,metal)
	var leaf_glass: StandardMaterial3D = facade.host.material("Academic open door glass",glass.albedo_color)
	var leaf_frame: StandardMaterial3D = facade.host.material("Academic open door frame",metal.albedo_color)
	for mat in [leaf_glass,leaf_frame]:
		mat.albedo_texture=null
		mat.cull_mode=BaseMaterial3D.CULL_BACK
	leaf_glass.metallic=.35
	leaf_glass.roughness=.25
	leaf_frame.metallic=.5
	leaf_frame.roughness=.35
	for side in [-1.0,1.0]:
		var hinge: float = x+side*(leaf_width+.03)
		# Both leaves stand perpendicular to the facade, opening toward its outward normal.
		leaf_part(facade,hinge,.16+leaf_width*.5,(bottom+door_top)*.5,Vector3(leaf_width,door_height,.04),leaf_glass,"AcademicOpenDoorLeaf",true)
		for end in [0.0,leaf_width]:
			leaf_part(facade,hinge,.16+float(end),(bottom+door_top)*.5,Vector3(.045,door_height,.05),leaf_frame,"AcademicOpenDoorVerticalFrame",false)
		for y in [bottom,door_top]:
			leaf_part(facade,hinge,.16+leaf_width*.5,float(y),Vector3(leaf_width,.045,.05),leaf_frame,"AcademicOpenDoorHorizontalFrame",false)

func leaf_part(facade, x: float, outward: float, y: float, size: Vector3, mat: Material, title: String, solid: bool) -> void:
	var p: Vector2 = facade.origin+facade.axis*x+facade.out*outward
	var node: MeshInstance3D = facade.host.box(facade.group,Vector3(p.x,y,p.y),size,mat,title)
	node.rotation.y=-atan2(facade.out.y,facade.out.x)
	node.set_meta("walk_collision",solid)
