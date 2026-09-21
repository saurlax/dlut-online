extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")
const Movement = preload("res://scripts/shared/movement.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(150).timeout.connect(func(): quit(2))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var feature: Dictionary
	for item in manifest.features:
		if item.id == "77914": feature = item
	var a := Vector2(feature.points[6][0],feature.points[6][1])
	var b := Vector2(feature.points[7][0],feature.points[7][1])
	var center := a.lerp(b,0.425)
	var axis := (b-a).normalized()
	var outward := Vector2(axis.y,-axis.x)
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	var reference: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	var base: float = reference.get_node("Feature_77914").position.y
	var ramp: MeshInstance3D = reference.get_node("Feature_77914/InformationStairCollision")
	assert(not ramp.visible and ramp.get_meta("walk_collision",false),"Stair collision must stay separate and invisible")
	var paving: MeshInstance3D = reference.get_node("InformationEntryPaving")
	var arrays := paving.mesh.surface_get_arrays(0)
	for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
		assert(normal.y>0.9,"Entry paving normals must face upward")
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var delta := Vector2(vertex.x,vertex.z)-center
		assert(absf(delta.dot(axis))<=9.001 and delta.dot(outward)>=11.039 and delta.dot(outward)<25,"Entry paving escaped its registered corridor")
		assert(absf(vertex.y-terrain.elevation(vertex.x,vertex.z)-0.018)<0.001,"Entry paving must follow the shared terrain")
	reference.free()
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
			world.add_child(load("res://assets/campuses/eda/models/terrain.tscn").instantiate())
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for x: float in [-5.0,0.0,5.0]:
			var p := center+axis*x+outward*1.1
			var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,base+6,p.y),Vector3(p.x,base+3,p.y)))
			assert(not floor_hit.is_empty() and absf(floor_hit.position.y-base-4.4)<0.01,"Landing floor missing")
			var roof_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,base+9,p.y),Vector3(p.x,base+7,p.y)))
			assert(not roof_hit.is_empty() and absf(roof_hit.position.y-base-7.535)<0.01,"Entry canopy collision missing")
			for distance in [12.2,14.0,16.0]:
				var sample: Vector2 = center+axis*x+outward*distance
				var height: float = terrain.elevation(sample.x,sample.y)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(sample.x,height+0.5,sample.y),Vector3(sample.x,height-0.1,sample.y)))
				assert(not hit.is_empty() and absf(hit.position.y-height-0.018)<0.015,"Entry approach paving collision is missing or floats")
			var start := center+axis*x+outward*18.0
			var body := CharacterBody3D.new()
			Movement.setup(body)
			body.position = Vector3(start.x,terrain.elevation(start.x,start.y)+0.03,start.y)
			world.add_child(body)
			var spawn := body.position
			for i in 15:
				await physics_frame
				Movement.step(body,Vector2.ZERO,false,false,1.0/60,spawn)
			for i in 240:
				await physics_frame
				Movement.step(body,-outward,false,false,1.0/60,spawn)
				if (Vector2(body.position.x,body.position.z)-center).dot(outward)<1.05: break
			var distance := (Vector2(body.position.x,body.position.z)-center).dot(outward)
			assert(distance<1.15 and absf(body.position.y-base-4.4)<0.05,"Player cannot walk up entry stairs without jumping")
			for i in 240:
				await physics_frame
				Movement.step(body,outward,false,false,1.0/60,spawn)
				if (Vector2(body.position.x,body.position.z)-center).dot(outward)>18.0: break
			distance = (Vector2(body.position.x,body.position.z)-center).dot(outward)
			assert(distance>17.9 and absf(body.position.y-terrain.elevation(body.position.x,body.position.z))<0.15,"Player cannot return to approach paving from stairs")
			body.free()
		print("INFORMATION ENTRY PASS server=",server," three walking lanes approach/up/down without jumping, paving/landing/canopy")
		viewport.free()
	quit()
