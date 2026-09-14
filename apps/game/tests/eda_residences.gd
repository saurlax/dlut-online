extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")
const CASES := [["77931",9,0.69],["77933",7,0.28],["77935",4,-1.0],["77937",7,0.4],["77938",5,0.58],["77941",7,-1.0]]

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
				assert(group.get_child_count()<=(9 if c[0]=="77937" else 8 if c[0]=="77938" else 7),"Keep material batching per residence")
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
			var lower: bool = c[0] in ["77937","77938"]
			var roof := Vector3(p.x,20.05 if lower else 23.2,p.y)
			hit(space,roof+Vector3.UP*3,roof-Vector3.UP*3,roof,c[0]+" roof")
			p = a.lerp(b,0.43)+out*0.7
			var gallery := Vector3(p.x,16.19 if lower else 19.34,p.y)
			if c[0]=="77941":
				assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(gallery+Vector3.UP*0.8,gallery-Vector3.UP*0.8)).is_empty(),"Do not copy an unverified gallery to residence six")
			else:
				hit(space,gallery+Vector3.UP*0.8,gallery-Vector3.UP*0.8,gallery,c[0]+" gallery slab")
			if c[0]=="77937":
				var eave_tip := a.distance_to(b)*0.18-0.25
				var eave_join := a.distance_to(b)*(0.18+0.64*0.2)
				p = a+axis*((eave_tip+eave_join)/2)+out*1.0
				var eave_top := 19.95+0.4+0.11*sqrt(1+pow(0.8/(eave_join-eave_tip),2))
				var eave := Vector3(p.x,eave_top,p.y)
				hit(space,eave+Vector3.UP*2,eave-Vector3.UP*2,eave,"Fourth residence raised eave")
				# Trace against the new enclosure itself, not the retained wall behind it.
				for sample in [[0.43,17.5,0.91],[0.42,8.3,1.23],[0.42,11.4,1.23]]:
					p = a.lerp(b,float(sample[0]))
					var enclosure := Vector3(p.x,float(sample[1]),p.y)
					hit(space,enclosure+normal*3,enclosure-normal,enclosure+normal*float(sample[2]),"Fourth residence sealed glazing")
			if c[2]>0:
				p = a.lerp(b,c[2])+axis*a.distance_to(b)*0.025+out*0.7
				for y in ([6.8,9.95,13.1] if lower else [9.95,13.1,16.25]):
					var slab := Vector3(p.x,y,p.y)
					hit(space,slab+Vector3.UP*0.7,slab-Vector3.UP*0.7,slab,c[0]+" balcony slab")
		world.free()
		viewport.free()
	print("PASS: six batched photo facades; client/server closed shells, roofs, galleries and balcony slabs")
	quit()
