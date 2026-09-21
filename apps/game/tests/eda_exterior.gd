extends SceneTree
var failures: Array[String] = []
var terrain := preload("res://tools/build_terrain.gd").new()

func _initialize() -> void:
	verify.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func verify() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	terrain.load_campus("eda")
	var details: Node3D = load("res://assets/campuses/eda/models/exterior_details.tscn").instantiate()
	var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	var samples := 0
	for node in details.get_children()+model.get_children():
		if not node is MeshInstance3D: continue
		var marking: bool = str(node.name) in ["WhitePaint", "YellowPaint"]
		if not marking and not node.get_meta("road_surface",false): continue
		var faces: PackedVector3Array = node.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var front := (faces[i+2]-faces[i]).cross(faces[i+1]-faces[i])
			check(front.y > 0, "Downward road or paint face: "+str(node.name))
			if marking:
				var p := (faces[i]+faces[i+1]+faces[i+2])/3.0
				check(absf(p.y-terrain.elevation(p.x,p.z)-0.028)<0.0001,"Paint detached from terrain triangle")
				samples += 1
		if marking: check(node.get_child_count()==0,"Paint must not have collision")
	check(samples > 100, "Missing saved markings")
	var poles := details.find_children("*", "StaticBody3D", true, false)
	check(poles.size() == 5, "Expected five bounded photo poles")
	# The same ray and swept capsule must hit the post in client and server worlds.
	for server_mode in [false, true]:
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		root.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		world.add_child(load("res://scenes/server/eda.scn").instantiate() if server_mode else details.duplicate())
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for pole: StaticBody3D in poles:
			var center := pole.position-Vector3.UP*2.0
			var ray := PhysicsRayQueryParameters3D.create(center-Vector3.RIGHT,center+Vector3.RIGHT)
			var hit := space.intersect_ray(ray)
			check(not hit.is_empty(),"Lamp has no physical collision, server="+str(server_mode))
			if not hit.is_empty(): check(absf(hit.position.x-center.x+0.085)<0.02,"Wrong lamp collision radius")
			var body := CharacterBody3D.new()
			var shape := CollisionShape3D.new()
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.3
			capsule.height = 1.7
			shape.shape = capsule
			body.add_child(shape)
			world.add_child(body)
			body.position = center-Vector3.RIGHT
			var collision := body.move_and_collide(Vector3.RIGHT*2.0)
			check(collision != null and body.position.x < center.x-0.3,"Walking capsule passes through lamp")
			body.free()
		viewport.free()
	model.free()
	details.free()
	print("EDA EXTERIOR CHECK: ",samples," terrain-fit paint triangles, client/server ray and capsule checks; failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
