extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")
const Movement = preload("res://scripts/shared/movement.gd")

func _initialize(): run.call_deferred()

func run():
	create_timer(120).timeout.connect(func(): quit(2))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var points := PackedVector2Array()
	for feature in manifest.features:
		if feature.id=="77927":
			for p in feature.points: points.append(Vector2(p[0],p[1]))
	var reference: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	var base: float = reference.get_node("Feature_77927").position.y
	reference.free()
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
		var space := world.get_world_3d().direct_space_state
		for edge in range(6,15):
			var axis := (points[edge+1]-points[edge]).normalized()
			var out := Vector2(axis.y,-axis.x)
			var center := points[edge].lerp(points[edge+1],0.25)
			if Geometry2D.is_point_in_polygon(center+out,points): out=-out
			var inside := center-out*0.8
			for sample in [[base+2.0,base-1.0,base+0.03],[base+7.5,base+9.0,base+8.68]]:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(inside.x,sample[0],inside.y),Vector3(inside.x,sample[1],inside.y)))
				assert(not hit.is_empty() and absf(hit.position.y-sample[2])<0.015,"C arcade floor or downward soffit missing")
			var back := center-out*2.0
			var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(center.x,base+1.5,center.y),Vector3(back.x,base+1.5,back.y)))
			var expected := center-out*1.6
			assert(not wall.is_empty() and wall.position.distance_to(Vector3(expected.x,base+1.5,expected.y))<0.015,"C arcade must retain recessed closed rear wall")
			if edge not in [7,11,14]: continue
			var spawn_at := center+out*1.3
			var body := CharacterBody3D.new()
			Movement.setup(body)
			body.position=Vector3(spawn_at.x,terrain.elevation(spawn_at.x,spawn_at.y)+0.04,spawn_at.y)
			world.add_child(body)
			var spawn := body.position
			for i in 15:
				await physics_frame
				Movement.step(body,Vector2.ZERO,false,false,1.0/60,spawn)
			for direction in [-1.0,1.0]:
				for i in 120:
					await physics_frame
					Movement.step(body,out*direction,false,false,1.0/60,spawn)
					var offset := Vector2(body.position.x-center.x,body.position.z-center.y).dot(out)
					if (direction<0 and offset< -0.8) or (direction>0 and offset>1.25): break
				var offset := Vector2(body.position.x-center.x,body.position.z-center.y).dot(out)
				assert(offset< -0.7 if direction<0 else offset>1.2,"C arcade cannot be crossed without jumping")
				assert(absf(body.position.y-terrain.elevation(body.position.x,body.position.z))<0.12,"C arcade floor floats above terrain")
			body.free()
		print("C ARCADE PASS server=",server," nine floor/soffit/rear-wall samples, three walking routes in both directions")
		viewport.free()
	quit()
