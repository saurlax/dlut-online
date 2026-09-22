extends SceneTree
const Collision = preload("res://scripts/shared/campus_collision.gd")
const Terrain = preload("res://tools/build_terrain.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var terrain := Terrain.new()
	terrain.load_campus("eda")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	for server in [false, true]:
		var world := Node3D.new()
		if server:
			world.free()
			world = load("res://scenes/server/eda.scn").instantiate()
		else:
			var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			check_finishes(model)
			world.add_child(model)
			var ground: Node3D = load("res://assets/campuses/eda/models/terrain.tscn").instantiate()
			ground.name = "Terrain"
			world.add_child(ground)
			Collision.build(world, model, manifest, "eda")
		root.add_child(world)
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		var count := 0
		# The Y remains open; the divided approach has two carriageways and a raised green median.
		for z in range(353,372,2):
			for x in [-121.0,-119.0,-117.0]:
				check_height(space,terrain,Vector2(x,z),.02,"Open junction");count+=1
		for z in range(382,496,3):
			for x in [-124.7,-113.3]:
				check_height(space,terrain,Vector2(x,z),.02,"South carriageway");count+=1
			check_height(space,terrain,Vector2(-119,z),.182,"Raised median");count+=1
			for x in [-132.7,-105.3]:
				check_height(space,terrain,Vector2(x,z),.182,"Outer red sidewalk");count+=1

		# Woodland paths must not cut a hole where their source axes meet the carriageway.
		for at:Vector2 in [Vector2(-81.5255,341.8303),Vector2(-99.1094,351.3148)]:
			check_height(space,terrain,at,.02,"Asphalt at woodland stop")
		# Three distinct treads plus the adjoining plaza, checked in both collision worlds.
		var a:=Vector2(31.3659249396,436.196288)
		var b:=Vector2(33.6211608649,445.402452)
		var outward:Vector2=(b-a).normalized().orthogonal()
		for level in range(3):
			check_height(space,terrain,a.lerp(b,.5)+outward*(level*.45+.225),-float(3-level)*.15,"Shuyun tread")
		check_height(space,terrain,a.lerp(b,.5)-outward*.5,-.45,"Shuyun landing")
		check_height(space,terrain,Vector2(-50.64841,408.8115),0.0,"Removed western stair ground")
		var terrace_center:=Vector2(30.906,394.002)
		var terrace_axis:=Vector2(26.84,-.224).normalized()
		var side_landing:=terrace_center+Vector2(6.39,22.86)*.77
		check_height(space,terrain,terrace_center-terrace_axis*3.0,.75,"Raised stage")
		check_height(space,terrain,Vector2(65,399),.75,"Library forecourt")
		for i in range(8):
			var height:float=.75-(i+1)*.15+.003
			check_height(space,terrain,terrace_center-terrace_axis*(6+i*.35+.175),height,"Curved terrace stairs")
			check_height(space,terrain,side_landing-terrace_axis*(i*.35+.175),height,"Side terrace stairs")
		var body := CharacterBody3D.new()
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.height = 1.7
		capsule.radius = 0.3
		shape.shape = capsule
		shape.position.y = 0.85
		body.add_child(shape)
		world.add_child(body)
		body.position = Vector3(-129,terrain.elevation(-129,361)+0.04,361)
		for frame in 240:
			body.velocity = Vector3(4,-1,0)
			body.move_and_slide()
			await physics_frame
		assert(body.position.x > -114, "Walking capsule blocked across the formerly separated junction")
		assert(absf(body.position.y-terrain.elevation(body.position.x,body.position.z))<0.08, "Walker fell through junction")
		print("EDA LAKESIDE PASS server=",server," infill rays=",count," continuous capsule walk")
		world.free()
	quit()

func check_height(space:PhysicsDirectSpaceState3D,terrain:RefCounted,at:Vector2,lift:float,label:String)->void:
	var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,80,at.y),Vector3(at.x,-20,at.y)))
	assert(not hit.is_empty(),label+" collision gap")
	assert(absf(hit.position.y-terrain.elevation(at.x,at.y)-lift)<.006,label+" height mismatch at "+str(at))

func check_finishes(model:Node3D)->void:
	var gravel:MeshInstance3D
	for child in model.get_children():
		if child is MeshInstance3D and child.material_override!=null and child.material_override.resource_name=="EDA woodland grass gaps":gravel=child
	assert(gravel!=null,"Woodland paths lack their planted ground")
	var faces:PackedVector3Array=gravel.mesh.get_faces()
	for at:Vector2 in [Vector2(-69.7,362.0),Vector2(-71.4,394.5),Vector2(-58.1,397.0),Vector2(-20.7,346.7)]:
		var covered:=false
		for i in range(0,faces.size(),3):
			var triangle:=PackedVector2Array([Vector2(faces[i].x,faces[i].z),Vector2(faces[i+1].x,faces[i+1].z),Vector2(faces[i+2].x,faces[i+2].z)])
			if Geometry2D.is_point_in_polygon(at,triangle):covered=true;break
		assert(covered,"Woodland grass is missing at: "+str(at))
	var slabs:MeshInstance3D
	for child in model.get_children():
		if child is MeshInstance3D and child.get_meta("woodland_stepping_stones",false):slabs=child
	assert(slabs!=null and int(slabs.get_meta("slab_count"))>100,"Discrete woodland slabs are missing")
	var square:=model.get_node("Feature_2304850")
	assert(int(square.get_meta("shuyun_steps",0))==3,"Shuyun needs exactly three perimeter risers")
	var patterned:=false
	for child in square.get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial:
			if child.material_override.get_shader_parameter("surface_kind")==9:patterned=true
	assert(patterned,"Shuyun square lacks its saved rose grid finish")
