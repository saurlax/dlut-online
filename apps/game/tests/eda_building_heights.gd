extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")
const SAMPLES := [[Vector2(456,-50),62.4],[Vector2(430,-106),62.4],[Vector2(392,-82),8.2],[Vector2(423,-57),8.2],[Vector2(440,-60),12.3],[Vector2(437,-159),20.05],[Vector2(490,-155),20.05]]

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	for server in [false,true]:
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		root.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		if server:
			world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(model)
			assert(model.get_node("Feature_2304982").get_child_count()<=4)
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for sample in SAMPLES:
			var pos: Vector2 = sample[0]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,80,pos.y),Vector3(pos.x,-1,pos.y)))
			assert(not hit.is_empty(),"Missing roof at "+str(pos))
			assert(absf(hit.position.y-float(sample[1]))<0.03,"Wrong roof height at "+str(pos)+": "+str(hit.position))
		# Check each tower rim independently: the roof is lower, the wall keeps the official top.
		var tower := PackedVector2Array([Vector2(412.779,-129.393),Vector2(432.094,-124.043),Vector2(481.363,-80.201),Vector2(467.099,-32.484),Vector2(448.323,-35.984),Vector2(456,-77),Vector2(404.97,-96.099)])
		for edge in tower.size():
			var a := tower[edge]
			var b := tower[(edge+1)%tower.size()]
			var middle := (a+b)/2
			var inward := Vector2(-(b-a).y,(b-a).x).normalized()
			if not Geometry2D.is_point_in_polygon(middle+inward,tower): inward = -inward
			var pos := middle+inward*0.15
			var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,66,pos.y),Vector3(pos.x,61,pos.y)))
			assert(not top.is_empty() and absf(top.position.y-63.6)<0.03,"Missing tower parapet top")
			var outside := middle-inward
			var inside := middle+inward
			var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(outside.x,63, outside.y),Vector3(inside.x,63,inside.y)))
			assert(not side.is_empty() and Vector2(side.position.x,side.position.z).distance_to(middle)<0.03,"Missing tower parapet side")
		# The outer stair towers on dormitories 4/5 rise above their main roofs.
		for sample in [[Vector2(467.384,-135.44),Vector2(419.887,-143.594),0.9],[Vector2(517.565,-135.991),Vector2(477.464,-135.617),0.14]]:
			var a: Vector2 = sample[0]
			var b: Vector2 = sample[1]
			var out := Vector2((b-a).y,-(b-a).x).normalized()
			var center := a.lerp(b,sample[2])-out*2.05
			var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(center.x,27,center.y),Vector3(center.x,19,center.y)))
			assert(not top.is_empty() and absf(top.position.y-23.0)<0.03,"Missing raised dormitory stair tower")
			var front := a.lerp(b,sample[2])
			var outside := front+out
			var inside := front-out
			var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(outside.x,21,outside.y),Vector3(inside.x,21,inside.y)))
			assert(not side.is_empty() and Vector2(side.position.x,side.position.z).distance_to(front+out*0.2)<0.03,"Stair tower must remain closed")
		# Sixth residence has a raised shaft on the west end, separate from its south facade.
		var sixth_a := Vector2(349.254,110.43)
		var sixth_b := Vector2(330.015,91.37)
		var sixth_out := Vector2((sixth_b-sixth_a).y,-(sixth_b-sixth_a).x).normalized()
		var sixth_front := (sixth_a+sixth_b)/2
		var sixth_center := sixth_front-sixth_out*2
		var sixth_top := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(sixth_center.x,28,sixth_center.y),Vector3(sixth_center.x,23,sixth_center.y)))
		assert(not sixth_top.is_empty() and absf(sixth_top.position.y-25.5)<0.03,"Missing sixth residence raised west tower")
		var sixth_from := sixth_front+sixth_out*2
		var sixth_to := sixth_front-sixth_out
		var sixth_side := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(sixth_from.x,24,sixth_from.y),Vector3(sixth_to.x,24,sixth_to.y)))
		assert(not sixth_side.is_empty() and Vector2(sixth_side.position.x,sixth_side.position.z).distance_to(sixth_front+sixth_out*0.2)<0.03,"Sixth tower must remain closed")
		# Both photographed raised-roof parapets block horizontally and have a top.
		for segment in [[Vector2(433.088,-74.167),Vector2(427.25,-42.98)],[Vector2(427.25,-42.98),Vector2(448.875,-38.933)]]:
			var a: Vector2 = segment[0]
			var b: Vector2 = segment[1]
			var axis := (b-a).normalized()
			var inward := Vector2(axis.y,-axis.x)
			var middle := (a+b)*0.5
			var top_pos := middle+inward*0.125
			var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(top_pos.x,14,top_pos.y),Vector3(top_pos.x,12,top_pos.y)))
			assert(not top.is_empty() and absf(top.position.y-12.85)<0.03,"Missing raised-roof parapet top")
			var outside := middle-inward
			var inside := middle+inward
			var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(outside.x,12.55,outside.y),Vector3(inside.x,12.55,inside.y)))
			assert(not side.is_empty() and Vector2(side.position.x,side.position.z).distance_to(middle)<0.03,"Missing raised-roof parapet side")
		# Seventh residence exterior remains closed at ground level.
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(429,1.7,-12),Vector3(429,1.7,-70)))
		assert(not wall.is_empty() and wall.position.z>-50,"Podium exterior must block walking")
		world.free()
		viewport.free()
	print("PASS: client/server seventh residence 63.6m tower rim and 62.4m recessed roof, 8.2m low podium, 12.3m raised podium with 12.85m parapets, lower dormitories 4/5 and closed exterior")
	quit()
