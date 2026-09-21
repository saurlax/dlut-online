extends SceneTree
## Regression for artificial curbs caused by rendering offsets in road collision.
const Movement = preload("res://scripts/shared/movement.gd")
const CASES = [
	{"campus":"eda", "road":1076344091, "center":Vector2(153.564958,344.438611), "normal":Vector2(-0.9731607,-0.2303170), "halfwidth":3.0},
	{"campus":"lingshui", "road":33126278, "center":Vector2(30.7761,26.36615), "normal":Vector2(-0.9998341,0.01821482), "halfwidth":2.5},
	{"campus":"eda", "road":1076344083, "center":Vector2(-30.4457,-66.5805), "normal":Vector2(0.00123832,0.99999923), "halfwidth":3.0},
	{"campus":"panjin", "road":1318388512, "center":Vector2(13.0249,-23.15455), "normal":Vector2(0.98453302,0.17519911), "halfwidth":2.5},
]
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	for item in CASES:
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		root.add_child(viewport)
		var world: Node3D = load("res://scenes/server/"+item.campus+".scn").instantiate()
		viewport.add_child(world)
		var terrain = preload("res://tools/build_terrain.gd").new()
		terrain.load_campus(item.campus)
		var body := CharacterBody3D.new()
		Movement.setup(body)
		world.add_child(body)
		for reverse in [false,true]:
			var normal: Vector2 = item.normal * (-1.0 if reverse else 1.0)
			var start: Vector2 = item.center + normal*(item.halfwidth+2.0)
			var spawn := Vector3(start.x,terrain.elevation(start.x,start.y)+0.5,start.y)
			body.position = spawn
			body.velocity = Vector3.ZERO
			for frame in 45:
				await physics_frame
				Movement.step(body,Vector2.ZERO,false,false,1.0/60.0,spawn)
			assert(body.is_on_floor(),"Road entry start has no ground")
			var center: Vector2 = item.center
			var ground: float = terrain.elevation(center.x,center.y)
			var ray := PhysicsRayQueryParameters3D.create(Vector3(center.x,ground+2,center.y),Vector3(center.x,ground-2,center.y))
			ray.exclude = [body.get_rid()]
			var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
			assert(not hit.is_empty() and absf(hit.position.y-ground-0.02)<0.002,"Probe must cross the saved road, not bare terrain")
			var initial := body.position
			for frame in 120:
				await physics_frame
				Movement.step(body,-normal,false,false,1.0/60.0,spawn)
				assert(body.is_on_floor(),"Lost floor while walking across a road edge")
			var travelled := Vector2(body.position.x-initial.x,body.position.z-initial.z).length()
			assert(travelled>10.5,"Rendering clearance blocks normal road entry: "+item.campus)
			print("ROAD ENTRY PASS: ",item.campus," way=",item.road," reverse=",reverse," distance=",travelled)
		viewport.queue_free()
		await process_frame
	quit()
