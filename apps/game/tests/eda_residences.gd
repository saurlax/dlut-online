extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")
const CASES := [["77931",9,0.69],["77933",7,0.28],["77935",4,-1.0]]

func _initialize() -> void: run.call_deferred()

func hit(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, expected: Vector3, label: String) -> void:
	var result := space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to))
	assert(not result.is_empty(),label+" missing collision")
	assert(result.position.distance_to(expected)<0.06,label+" wrong surface: "+str(result.position))

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
			for c in CASES:
				var group := model.get_node("Feature_"+c[0])
				assert(group.get_child_count()<=7,"Keep material batching per residence")
				assert(group.get_meta("photo_edges")==[c[1]])
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for c in CASES:
			var feature: Dictionary
			for f in manifest.features:
				if f.id == c[0]: feature = f
			var points := PackedVector2Array()
			for p in feature.points: points.append(Vector2(p[0],p[1]))
			var a := points[c[1]]
			var b := points[(c[1]+1)%points.size()]
			var axis := (b-a).normalized()
			var out := Vector2(axis.y,-axis.x)
			if Geometry2D.is_point_in_polygon((a+b)*0.5+out,points): out = -out
			var normal := Vector3(out.x,0,out.y)
			var p := a.lerp(b,0.07)
			var wall := Vector3(p.x,5,p.y)
			hit(space,wall+normal*2,wall-normal*2,wall,c[0]+" closed shell")
			p = a.lerp(b,0.4)-out*2
			var roof := Vector3(p.x,23.2,p.y)
			hit(space,roof+Vector3.UP*3,roof-Vector3.UP*3,roof,c[0]+" roof")
			p = a.lerp(b,0.43)+out*0.7
			var gallery := Vector3(p.x,19.34,p.y)
			hit(space,gallery+Vector3.UP*0.8,gallery-Vector3.UP*0.8,gallery,c[0]+" gallery slab")
			if c[2]>0:
				p = a.lerp(b,c[2])+axis*a.distance_to(b)*0.025+out*0.7
				for y in [9.95,13.1,16.25]:
					var slab := Vector3(p.x,y,p.y)
					hit(space,slab+Vector3.UP*0.7,slab-Vector3.UP*0.7,slab,c[0]+" balcony slab")
		world.free()
		viewport.free()
	print("PASS: three batched photo facades; client/server closed shells, roofs, galleries and balcony slabs")
	quit()
