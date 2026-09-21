extends SceneTree
const Collision=preload("res://scripts/shared/campus_collision.gd")
func _initialize(): run.call_deferred()
func run():
	create_timer(60).timeout.connect(func():quit(2))
	var reference:Node3D=load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	var at:Vector3=reference.get_node("XiangSculpture").position
	assert(Vector2(at.x,at.z).distance_to(Vector2(-116.7797,317.3288))<0.01,"Sculpture must use the shared WGS84 frame")
	reference.free()
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	for server in [false,true]:
		var viewport:=SubViewport.new();viewport.own_world_3d=true;root.add_child(viewport)
		var world:=Node3D.new();viewport.add_child(world)
		if server: world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			var model:Node3D=load("res://assets/campuses/eda/models/development_campus.tscn").instantiate();world.add_child(model)
			Collision.build(world,model,manifest,"eda")
		await physics_frame;await physics_frame
		var space:=world.get_world_3d().direct_space_state
		for side in [-1.0,1.0]:
			var from:=at+Vector3(0,1.57,side*2)
			var to:=at+Vector3(0,1.57,-side*2)
			assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to)).is_empty(),"Sculpture loop must remain open")
			from.x+=0.65;to.x+=0.65
			assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to)).is_empty(),"Right-side curl opening must not be closed into a ring")
			from.x-=1.3;to.x-=1.3
			var rim:=space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to))
			assert(not rim.is_empty(),"Missing curled metal")
			assert(rim.normal.dot(Vector3(0,0,side))>0.8,"Loop front/back winding is reversed")
		var top:=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3(1.2,2,0),at+Vector3(1.2,-1,0)))
		assert(not top.is_empty() and absf(top.position.y-at.y-0.24)<0.01,"Plinth top missing")
		var capsule:=CapsuleShape3D.new();capsule.radius=0.3;capsule.height=1.8
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule
		query.transform=Transform3D(Basis.IDENTITY,at+Vector3(0,0.9,2))
		query.motion=Vector3(0,0,-4)
		var travel:float=space.cast_motion(query)[0]
		assert(travel>0.1 and travel<0.3,"Player capsule passes through sculpture plinth")
		print("SCULPTURE PASS server=",server," shared position, open center and right curl opening, outward metal faces, plinth and capsule blocking")
		viewport.free()
	quit()
