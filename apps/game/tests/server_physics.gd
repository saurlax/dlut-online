extends SceneTree
const Movement = preload("res://scripts/shared/movement.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var worlds := {}
	for id in ["lingshui","eda","panjin"]:
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(viewport)
		var world: Node3D = load("res://scenes/server/" + id + ".scn").instantiate()
		viewport.add_child(world)
		worlds[id] = world
		assert(world.find_children("*", "MeshInstance3D", true, false).is_empty())
		assert(world.find_children("*", "Camera3D", true, false).is_empty())
		var body := CharacterBody3D.new()
		Movement.setup(body)
		world.add_child(body)
		body.position = world.get_meta("spawn")
		for frame in 90:
			await physics_frame
			Movement.step(body,Vector2.ZERO,false,false,1.0/60.0,world.get_meta("spawn"))
		assert(body.is_on_floor(),id + " spawn must be grounded")
		if id == "lingshui":
			var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/campus.json"))
			# These two structures still retain photo geometry in the legacy frame.
			# Convert their recorded samples, including the saved terrain placement.
			var model: Node3D = load("res://assets/campuses/lingshui/models/lingshui_campus.tscn").instantiate()
			var registration: Dictionary = manifest.legacy_reference_transform
			var offset := Vector2(registration.offset_xz[0],registration.offset_xz[1])
			var base: float = model.get_node("Feature_77445_0").position.y
			var space := world.get_world_3d().direct_space_state
			for sample in [Vector3(390,25.9866,165),Vector3(410,17.5,239)]:
				var p := Vector2(sample.x*float(registration.scale_x),sample.z)+offset
				var top := Vector3(p.x,base+sample.y,p.y)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top+Vector3.UP,top-Vector3.UP))
				assert(not hit.is_empty() and absf(hit.position.y-top.y)<0.08,"Authoritative curved roof height must match migrated photo geometry")
			base = model.get_node("Feature_78473_0").position.y
			var start := Vector3(240*float(registration.scale_x)+offset.x,base+2,175+offset.y)
			var end := Vector3(220*float(registration.scale_x)+offset.x,base+2,175+offset.y)
			var stand := space.intersect_ray(PhysicsRayQueryParameters3D.create(start,end))
			assert(not stand.is_empty(),"Authoritative world must include the migrated west stand")
			assert(absf(stand.position.x-(228.225*float(registration.scale_x)+offset.x))<0.03,"Ray must reach the seating structure, not surrounding ground")
			model.free()
		if id == "eda":
			var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
			var info: Dictionary
			for feature: Dictionary in manifest.features:
				if feature.id=="77914": info = feature
			assert(info.osm_id=="way/1422474847" and info.points.size()==12)
			# Use the registered southwest wall, outside the central recessed bay.
			var a := Vector2(info.points[10][0],info.points[10][1])
			var b := Vector2(info.points[11][0],info.points[11][1])
			var middle := (a+b)/2
			var outward := Vector2((b-a).y,-(b-a).x).normalized()
			var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			var base: float = model.get_node("Feature_77914").position.y
			model.free()
			var approach := middle+outward*8
			body.position = Vector3(approach.x,base+0.2,approach.y)
			body.velocity = Vector3.ZERO
			for frame in 90:
				await physics_frame
				Movement.step(body,Vector2.ZERO,false,false,1.0/60.0,world.get_meta("spawn"))
			assert(body.is_on_floor(),"Information building approach must be grounded")
			for frame in 120:
				await physics_frame
				Movement.step(body,-outward,true,false,1.0/60.0,world.get_meta("spawn"))
			var remaining := (Vector2(body.position.x,body.position.z)-middle).dot(outward)
			assert(remaining>0.3 and remaining<1.5,"Authoritative collision must stop the capsule at the registered information wall: "+str(remaining))
			assert(body.is_on_floor(),"Player must remain grounded at the information wall")
		body.queue_free()
	assert(worlds.eda.get_world_3d().space != worlds.lingshui.get_world_3d().space)
	assert(worlds.eda.get_world_3d().space != worlds.panjin.get_world_3d().space)
	print("PASS: three collision-only worlds, grounded spawns, separate physics spaces, authoritative wall collision")
	quit()
