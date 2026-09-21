extends RefCounted

func panel(builder, group: Node3D, position: Vector2, y: float, size: Vector3, angle: float, material: Material, name: String) -> void:
	var node: MeshInstance3D = builder.box(group,Vector3(position.x,y,position.y),size,material,name)
	node.rotation.y = angle
	node.set_meta("walk_collision",false)
	node.set_meta("seventh_south_detail",name)
	preload("res://tools/eda_surface_details.gd").tint_glazing(node,material,position.x+position.y,y)

func exterior_material(source: Material) -> Material:
	var result: Material = source.duplicate()
	result.resource_name = source.resource_name+" south facade"
	result.cull_mode = BaseMaterial3D.CULL_BACK
	return result

func build(builder, group: Node3D, tower: PackedVector2Array, faces: Array, podium: float, height: float, tower_storeys: int, glazing: Material, spandrel: Material, trim: Material) -> void:
	var backing: Material = builder.material("Seventh courtyard louver backing",Color("30393d"))
	var blades: Material = builder.material("Seventh courtyard louver blades",Color("596365"))
	for material in [backing,blades]:
		material.albedo_texture = null
		material.metallic = 0.45
		material.roughness = 0.55
	glazing = exterior_material(glazing)
	spandrel = exterior_material(spandrel)
	trim = exterior_material(trim)
	backing = exterior_material(backing)
	blades = exterior_material(blades)
	var storey := (height-podium-1.5)/tower_storeys
	for spec: Dictionary in faces:
		var edge := int(spec.edge)
		var a := tower[edge]
		var b := tower[(edge+1)%tower.size()]
		var axis := (b-a).normalized()
		var outward := Vector2(axis.y,-axis.x)
		if Geometry2D.is_point_in_polygon((a+b)*0.5+outward,tower): outward = -outward
		var angle := -atan2(axis.y,axis.x)
		var glass_width := float(spec.side_glass_width)
		var louver_width := float(spec.central_louver_width)
		var glass_height := storey*0.65
		var pair_height := storey*1.65
		for end_distance in spec.centers_from_end:
			var center := b-axis*float(end_distance)
			var fraction := 1.0-float(end_distance)/a.distance_to(b)
			var half_span := (glass_width+louver_width*0.5)/a.distance_to(b)
			assert(fraction-half_span>=float(spec.span[0]) and fraction+half_span<=float(spec.span[1]),"South facade module left its registered span")
			for pair in spec.floor_pairs:
				assert(int(pair)>=0 and int(pair)*2+1<tower_storeys)
				var pair_y := podium+storey*(int(pair)*2+1)
				for side in [-1.0,1.0]:
					var glass_center: Vector2 = center+axis*side*(louver_width+glass_width)*0.5
					panel(builder,group,glass_center+outward*0.065,pair_y,Vector3(glass_width,storey*0.35,0.08),angle,spandrel,"SeventhSouthSpandrel")
					for floor_offset in [-0.5,0.5]:
						var y: float = pair_y+storey*floor_offset
						panel(builder,group,glass_center+outward*0.08,y,Vector3(glass_width,glass_height,0.1),angle,glazing,"SeventhSouthGlass")
						for dx in [-glass_width/2.0,glass_width/2.0]:
							panel(builder,group,glass_center+axis*dx+outward*0.15,y,Vector3(0.045,glass_height+0.06,0.08),angle,trim,"SeventhSouthFrame")
						for dy in [-glass_height/2.0,glass_height*0.22,glass_height/2.0]:
							panel(builder,group,glass_center+outward*0.15,y+dy,Vector3(glass_width+0.04,0.045,0.08),angle,trim,"SeventhSouthFrame")
				panel(builder,group,center+outward*0.235,pair_y,Vector3(louver_width,pair_height,0.04),angle,backing,"SeventhSouthLouver")
				var blade_count := ceili(pair_height/0.16)
				for blade in range(blade_count+1):
					panel(builder,group,center+outward*0.28,pair_y-pair_height/2.0+pair_height*blade/blade_count,Vector3(louver_width,0.022,0.045),angle,blades,"SeventhSouthBlade")
