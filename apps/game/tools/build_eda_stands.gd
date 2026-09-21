extends RefCounted
## Bounded west straight stand. Equipment dimensions are visual estimates.
var builder
var group: Node3D
var origin: Vector2
var along: Vector2
var inward: Vector2

func block(x: float, y: float, z: float, width: float, height: float, depth: float, material: Material, title: String, solid := true) -> void:
	var p := origin+along*x+inward*z
	var node: MeshInstance3D = builder.box(group,Vector3(p.x,y,p.y),Vector3(width,height,depth),material,title)
	node.rotation.y = -atan2(along.y,along.x)
	node.set_meta("walk_collision",solid)

func build(host, parent: Node3D, feature: Dictionary) -> void:
	builder = host
	group = parent
	assert(feature.osm_id=="way/1076344139" and feature.points.size()==19)
	var north := Vector2(feature.points[18][0],feature.points[18][1])
	var south := Vector2(feature.points[0][0],feature.points[0][1])
	along = (south-north).normalized()
	inward = Vector2(along.y,-along.x)
	var pitch: Array = feature.sports_lines[0].points
	var center := Vector2.ZERO
	for p in pitch: center += Vector2(p[0],p[1])*0.25
	origin = north+along*(center-north).dot(along)
	var first := (north-origin).dot(along)+18.0
	var last := (south-origin).dot(along)-18.0
	var stone: StandardMaterial3D = builder.material("EDA stand concrete",Color("a6a498"))
	var stair: StandardMaterial3D = builder.material("EDA stand aisle",Color("b5afa0"))
	for material: StandardMaterial3D in [stone,stair]:
		material.albedo_texture = load("res://assets/textures/buildings/mineral_render_albedo.png")
		material.uv1_scale = Vector3.ONE*0.35
	var roof: StandardMaterial3D = builder.material("EDA stand roof",Color("424745"))
	roof.albedo_texture = null
	roof.metallic = 0.45
	roof.roughness = 0.55
	var rail: StandardMaterial3D = builder.material("EDA stand rail",Color("9aaba8"))
	rail.albedo_texture = null
	rail.metallic = 0.6
	rail.roughness = 0.38
	var blue: StandardMaterial3D = builder.material("EDA stand blue finish",Color("436492"))
	blue.albedo_texture = load("res://assets/textures/buildings/mineral_render_albedo.png")
	blue.uv1_scale = Vector3.ONE*2.0
	blue.roughness = 0.88
	var edge: StandardMaterial3D = builder.material("EDA stand pale nosing",Color("b7beb9"))
	edge.albedo_texture = null
	edge.roughness = 0.88
	var breaks: Array[Vector2] = [Vector2(-50.8,-49.2),Vector2(-25.8,-24.2),Vector2(-7,7),Vector2(24.2,25.8),Vector2(49.2,50.8)]
	var runs: Array[Vector2] = []
	var cursor := first
	for gap in breaks:
		if gap.x>cursor: runs.append(Vector2(cursor,gap.x))
		cursor = gap.y
	runs.append(Vector2(cursor,last))
	# Eight seating terraces, with half-height treads only in the aisles.
	for row in 8:
		var height := 0.4*(row+1)
		var z := 6.8-float(row)*0.8
		for span in runs:
			block((span.x+span.y)*0.5,0.15+height*0.5,z,span.y-span.x,height,0.8,stone,"StandTier")
			# Only the four registered central seating bays; end stands remain separate.
			if span.x > -50.0 and span.y < 50.0:
				var x := (span.x+span.y)*0.5
				var width := span.y-span.x
				block(x,0.15+height+0.002,z,width,0.004,0.8,blue,"StandBlueTread",false)
				block(x,0.15+height-0.2,z+0.402,width,0.4,0.004,blue,"StandBlueRiser",false)
				block(x,0.15+height-0.025,z+0.406,width,0.05,0.004,edge,"StandPaleNosing",false)
	for aisle in [-50.0,-25.0,25.0,50.0]:
		for step in 16:
			var height := 0.2*(step+1)
			block(aisle,0.15+height*0.5,7.0-float(step)*0.4,1.6,height,0.4,stair,"StandStair")
	# The central covered platform stays open; no unseen rooms are generated.
	block(0,0.55,3.95,14,0.8,6.5,stone,"StandPlatform")
	for step in 4:
		var height := 0.2*(step+1)
		block(0,0.15+height*0.5,8.6-float(step)*0.4,5.0,height,0.4,stair,"PlatformStair")
	block(0,5.0,4.0,15.0,0.3,7.0,roof,"StandCanopy")
	var tubes := preload("res://tools/build_eda_goals.gd").new()
	for x in [-6.6,6.6]:
		for z in [1.0,6.6]:
			var p: Vector2 = origin+along*x+inward*z
			tubes.tube(builder,group,Vector3(p.x,0.95,p.y),Vector3(p.x,4.85,p.y),0.075,rail)
	# Continuous rear guardrails and returns along the exposed ends.
	for span in runs:
		var count := ceili((span.y-span.x)/2.0)
		for i in count+1:
			var x := lerpf(span.x,span.y,float(i)/count)
			block(x,3.9,0.7,0.045,1.1,0.045,rail,"StandRailPost")
		for height in [3.75,4.45]:
			block((span.x+span.y)*0.5,height,0.7,span.y-span.x,0.04,0.04,rail,"StandRail")
	for x: float in [first,last,-50.85,-49.15,-25.85,-24.15,24.15,25.85,49.15,50.85]:
		for row in [0,2,4,7]:
			var height: float = 0.15+0.4*(row+1)
			block(x,height+0.55,6.8-row*0.8,0.045,1.1,0.045,rail,"StandAislePost")
		var low := origin+along*x+inward*6.8
		var high := origin+along*x+inward*1.2
		for offset in [0.4,1.1]:
			tubes.tube(builder,group,Vector3(low.x,0.55+offset,low.y),Vector3(high.x,3.35+offset,high.y),0.022,rail)
