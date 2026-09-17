extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")
var registration = preload("res://tools/build_eda_gym.gd").new()
var base := 0.0

func mapped(x: float, y: float, z: float) -> Vector3:
	return registration.mapped(Vector3(x,y,z))+Vector3.UP*base

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/buildings/gym_profile.json"))
	registration.registration = profiles["77923"].osm_registration
	for feature in manifest.features:
		if feature.id != "77923": continue
		assert(feature.osm_id==registration.registration.osm_id)
		assert(int(feature.osm_version)==int(registration.registration.osm_version))
		for point in feature.points: registration.osm_points.append(Vector2(point[0],point[1]))
	assert(registration.osm_points.size()==4)
	var reference: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	base = reference.get_node("Feature_77923").position.y
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
			assert(model.get_node("Feature_77923").get_child_count()<=8)
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		# Roof endpoints are higher than the trough; verify the exported collision
		# instead of only inspecting generator parameters.
		for sample in [[-378.0,16.89024],[-316.5,13.5],[-255.0,16.89024]]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(mapped(sample[0],30,-51),mapped(sample[0],0,-51)))
			assert(not hit.is_empty())
			assert(absf(hit.position.y-base-float(sample[1]))<0.015,"Gym roof is flat or missing: "+str(hit))
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(mapped(-230,5,-50),mapped(-280,5,-50)))
		assert(not wall.is_empty(),"Gym entrance must remain closed")
		# The former tall east projection must be gone above its low base.
		var projection := space.intersect_ray(PhysicsRayQueryParameters3D.create(mapped(-250,10,-60),mapped(-250,10,-35)))
		assert(projection.is_empty(),"Old full-height east projection remains")
		for sample in [[-78.0,24.5],[-67.0,25.5],[-56.0,24.5],[-45.0,24.5],[-34.0,25.5],[-23.0,24.5]]:
			var post := space.intersect_ray(PhysicsRayQueryParameters3D.create(mapped(-316.5,30,sample[0]),mapped(-316.5,14,sample[0])))
			assert(not post.is_empty() and absf(post.position.y-base-sample[1])<0.03,"Missing gym roof post or wrong top")
		var post_side := space.intersect_ray(PhysicsRayQueryParameters3D.create(mapped(-317.5,18,-67),mapped(-315.5,18,-67)))
		assert(not post_side.is_empty(),"Roof post must have structural collision")
		print("GYM PHYSICS PASS: server=",server," curved roof, six posts, post side, wall and removed tall projection")
		world.free()
		viewport.free()
	print("PASS: client/server curved gym roof, low projection and closed exterior")
	quit()
