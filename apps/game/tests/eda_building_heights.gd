extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")
const SAMPLES := [[Vector2(456,-50),63.6],[Vector2(430,-106),63.6],[Vector2(392,-82),8.2],[Vector2(423,-57),8.2],[Vector2(437,-159),20.05],[Vector2(490,-155),20.05]]

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
		# Seventh residence exterior remains closed at ground level.
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(429,1.7,-12),Vector3(429,1.7,-70)))
		assert(not wall.is_empty() and wall.position.z>-50,"Podium exterior must block walking")
		world.free()
		viewport.free()
	print("PASS: client/server seventh residence 63.6m tower, 8.2m podium, lower dormitories 4/5 and closed exterior")
	quit()
