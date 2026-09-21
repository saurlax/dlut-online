extends RefCounted

var host
var group: Node3D
var path
var dark: Material
var metal: Material

func block(x: float, y: float, width: float, height: float, depth: float, offset: float, material: Material) -> void:
	var p: Vector2 = path.origin+path.axis*x+path.outward*offset
	var node: MeshInstance3D = host.box(group,Vector3(p.x,y,p.y),Vector3(width,height,depth),material,"SeventhEndDetail")
	node.rotation.y = -atan2(path.axis.y,path.axis.x)
	node.set_meta("walk_collision",false)
	path.deform(node)
	preload("res://tools/eda_surface_details.gd").tint_glazing(node,material,p.x+p.y,y)

func louver(x: float, y: float, width: float, height: float, blade_side := 0.0) -> void:
	block(x,y,width,height,0.055,0.055,dark)
	var blade_width := width if is_zero_approx(blade_side) else width*0.5
	var blade_x := x+blade_side*width*0.25
	var bars := ceili(height/0.16)
	for i in range(bars+1):
		block(blade_x,y-height/2+height*i/bars,blade_width,0.022,0.055,0.11,metal)

func grille_header_backing(x: float, y: float, width: float, height: float) -> void:
	var backing: StandardMaterial3D = host.material("Seventh grille pale header backing",Color("c0c1b4"))
	backing.albedo_texture=null
	backing.cull_mode=BaseMaterial3D.CULL_BACK
	# Approximate visible insert proportions. Its front remains behind the blades.
	block(x,y+height*0.465,width*0.25,height*0.055,0.025,0.095,backing)

func build(builder, parent: Node3D, points: PackedVector2Array, spec: Dictionary, podium: float, height: float, glazing: Material, spandrel: Material, trim: Material) -> void:
	host=builder
	group=parent
	path=preload("res://tools/residence_facade_path.gd").new()
	path.configure(points,spec.vertices)
	dark=builder.material("Seventh end charcoal backing",Color("30393d"))
	metal=builder.material("Seventh end louver blades",Color("596365"))
	for material in [dark,metal]:
		material.albedo_texture=null
		material.metallic=0.45
		material.roughness=0.55
	var storey := (height-podium-1.5)/14.0
	preload("res://tools/build_eda_seventh_joints.gd").new().build(self,spec,podium,height,storey)
	var strip_width: float = path.length*float(spec.strip_width_fraction)
	var panel: Dictionary = spec.upper_grille
	var panel_x: float = path.length*float(panel.center_fraction)
	var panel_width: float = path.length*float(panel.width_fraction)
	var panel_y: float = podium+storey*12.0
	var panel_height: float = storey*3.65
	louver(panel_x,panel_y,panel_width,panel_height)
	grille_header_backing(panel_x,panel_y,panel_width,panel_height)
	for column in range(int(panel.columns)+1):
		var x: float = panel_x-panel_width/2+panel_width*column/int(panel.columns)
		block(x,panel_y,0.035,panel_height,0.055,0.14,metal)
	preload("res://tools/build_eda_seventh_letters.gd").new().build(self,panel_x,panel_y-panel_height*0.25,panel_width*0.84,panel_height*0.135,trim)
	preload("res://tools/build_eda_seventh_emblem.gd").new().build(self,panel_x,panel_y+panel_height*0.17,panel_width*0.72)
	for pair in 7:
		var y := podium+storey*(pair*2+1)
		for fraction in spec.outer_strips:
			louver(path.length*float(fraction),y,strip_width,storey*1.65,-1.0)
			# Small glazing inserts occupy the unbladed half of each outer strip.
			var inset_x: float = path.length*float(fraction)+strip_width*0.25
			for dy in [-storey*0.70,storey*0.40]:
				block(inset_x,y+dy,strip_width*0.27,storey*0.20,0.025,0.094,glazing)
		if pair<5:
			for fraction in spec.inner_strips:
				louver(path.length*float(fraction),y,strip_width,storey*1.65,-1.0)
			var x: float = path.length*float(spec.window_fraction)
			var window_height := storey*0.45
			var spandrel_height := storey*0.75
			for dy in [-storey*0.6,storey*0.6]:
				block(x,y+dy,strip_width,window_height,0.06,0.08,glazing)
				for side in [-1.0,0.0,1.0]:
					block(x+side*strip_width/2,y+dy,0.045,window_height,0.09,0.13,metal)
				for offset in [-window_height/2,-window_height*0.3,window_height/2]:
					block(x,y+dy+offset,strip_width,0.045,0.09,0.13,metal)
			block(x,y,strip_width,spandrel_height,0.07,0.11,spandrel)
