extends SceneTree
const Collision = preload("res://scripts/shared/campus_collision.gd")
const Movement = preload("res://scripts/shared/movement.gd")
func _initialize(): run.call_deferred()
func run():
	create_timer(120).timeout.connect(func(): quit(2))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var points := PackedVector2Array()
	for feature in manifest.features:
		if feature.id=="77935":
			for p in feature.points: points.append(Vector2(p[0],p[1]))
	var path = preload("res://tools/residence_facade_path.gd").new()
	path.configure(points,[1,2,3])
	var terrain = preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	for server in [false,true]:
		var viewport := SubViewport.new()
		viewport.own_world_3d=true
		root.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		if server: world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(model)
			world.add_child(load("res://assets/campuses/eda/models/terrain.tscn").instantiate())
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		for bay in [0,3,6]:
			var at: Vector2 = path.origin+path.axis*path.length*(0.14+0.72*(bay+0.5)/7)
			var a: Vector3 = path.mapped(Vector3(at.x,0,at.y))
			var p: Vector3 = path.mapped(Vector3(at.x+path.outward.x*1.3,0,at.y+path.outward.y*1.3))
			var out := Vector2(p.x-a.x,p.z-a.z).normalized()
			var body := CharacterBody3D.new()
			Movement.setup(body)
			body.position=Vector3(p.x,terrain.elevation(p.x,p.z)+0.04,p.z)
			world.add_child(body)
			var spawn := body.position
			for i in 15:
				await physics_frame
				Movement.step(body,Vector2.ZERO,false,false,1.0/60,spawn)
			for direction in [-1.0,1.0]:
				for i in 120:
					await physics_frame
					Movement.step(body,out*direction,false,false,1.0/60,spawn)
					var offset := Vector2(body.position.x-a.x,body.position.z-a.z).dot(out)
					if (direction<0 and offset< -1.9) or (direction>0 and offset>1.25): break
				var offset := Vector2(body.position.x-a.x,body.position.z-a.z).dot(out)
				assert(offset< -1.8 if direction<0 else offset>1.2,"Arcade threshold cannot be crossed without jumping")
				assert(absf(body.position.y-terrain.elevation(body.position.x,body.position.z))<0.12,"Arcade floor floats above approach terrain")
			body.free()
		print("THIRD ARCADE WALK PASS server=",server," three bays, entry and exit without jumping")
		viewport.free()
	quit()
