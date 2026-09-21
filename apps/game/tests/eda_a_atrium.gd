extends SceneTree

const Movement = preload("res://scripts/shared/movement.gd")
const Collision = preload("res://scripts/shared/campus_collision.gd")
var failed := false
var center: Vector2
var axis: Vector2
var across: Vector2
var base: float

func require(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func at(x: float, y: float, z: float) -> Vector3:
	var p := center + axis*x + across*z
	return Vector3(p.x,base+y,p.y)

func _initialize() -> void: run.call_deferred()

func check_normals(feature: Node3D) -> void:
	var checked := 0
	var incorrect := 0
	for mesh: MeshInstance3D in feature.get_children():
		if not (mesh.material_override.resource_name.begins_with("EDA A atrium") or mesh.material_override.resource_name.begins_with("EDA A access") or mesh.material_override.resource_name.begins_with("Academic open door")): continue
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array(range(vertices.size()))
			for i in range(0,indices.size(),3):
				var a := mesh.transform*vertices[indices[i]]
				var b := mesh.transform*vertices[indices[i+1]]
				var c := mesh.transform*vertices[indices[i+2]]
				var normal := (c-a).cross(b-a)
				if normal.length()<.0000001: continue
				checked += 1
				for j in 3:
					if normal.normalized().dot((mesh.basis*normals[indices[i+j]]).normalized())<.9:
						incorrect += 1
		require(mesh.material_override.cull_mode==BaseMaterial3D.CULL_BACK,"Atrium material must use outward single faces")
	require(checked>1000 and incorrect==0,"Atrium saved normals disagree with face winding: "+str(incorrect))
	print("ATRIUM NORMALS checked=",checked," incorrect=",incorrect)

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/buildings/academic_facades.json"))
	var spec: Dictionary = profiles["77925"].osm_registration.atria
	var entry: Dictionary = profiles["77925"].osm_registration.entry
	var door := Vector2.ZERO
	var out := Vector2.ZERO
	for feature: Dictionary in manifest.features:
		if feature.id!="77925": continue
		var a := Vector2(feature.points[int(entry.edge)][0],feature.points[int(entry.edge)][1])
		var b := Vector2(feature.points[int(entry.edge)+1][0],feature.points[int(entry.edge)+1][1])
		door=a.lerp(b,float(entry.fraction))
		var direction := (b-a).normalized()
		out=Vector2(direction.y,-direction.x)
	var terrain: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/terrain.json"))
	base = terrain.feature_base_y.Feature_77925
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
			check_normals(model.get_node("Feature_77925"))
			world.add_child(load("res://assets/campuses/eda/models/terrain.tscn").instantiate())
			Collision.build(world,model,manifest,"eda")
			for label in ["stair walk","guard"]:
				var count := 0
				for mesh: MeshInstance3D in model.get_node("Feature_77925").get_children():
					if mesh.material_override.resource_name == "EDA A atrium unique "+label+" collision":
						count += 1
						require(not mesh.visible and mesh.get_meta("walk_collision",false),"Atrium collision must stay hidden: "+label)
				require(count==1,"Expected one merged atrium collision batch: "+label)
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		if entry.get("open_entry",false):
			var door_axis := Vector2(-out.y,out.x)
			for side in [-1.0,1.0]:
				var leaf: Vector2 = door+door_axis*side*.83+out*.55
				var a := Vector3(leaf.x-door_axis.x*.12,base+1.4,leaf.y-door_axis.y*.12)
				var b := Vector3(leaf.x+door_axis.x*.12,base+1.4,leaf.y+door_axis.y*.12)
				require(not space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b)).is_empty(),"Open door leaf collision missing")
			var hall_point := door-out*3.0
			var headroom := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(hall_point.x,base+1.0,hall_point.y),Vector3(hall_point.x,base+5.0,hall_point.y)))
			require(not headroom.is_empty() and absf(headroom.position.y-base-3.65)<.03,"Entrance hall must retain full ground-storey headroom")
			var entering := CharacterBody3D.new()
			Movement.setup(entering)
			world.add_child(entering)
			var path: Array[Vector2] = [door+out*2.0,door+out*.3,door-out*2.0,door-out*2.0+door_axis*5.5,door-out*2.0-door_axis*5.5,door-out*4.0,Vector2(84.43,-33.4),Vector2(79.2,-33.4),Vector2(79.2,-39),Vector2(76.416,-36.149)]
			for reverse in [false,true]:
				var route := path.duplicate()
				if reverse: route.reverse()
				entering.position=Vector3(route[0].x,base+1.0,route[0].y)
				entering.velocity=Vector3.ZERO
				for frame in 60:
					await physics_frame
					Movement.step(entering,Vector2.ZERO,false,false,1.0/60.0,entering.position)
				for target in route.slice(1):
					var reached := false
					for frame in 720:
						await physics_frame
						var delta: Vector2 = target-Vector2(entering.position.x,entering.position.z)
						if delta.length()<.12:
							reached=true
							break
						Movement.step(entering,delta.normalized()*.45,false,false,1.0/60.0,entering.position)
					require(reached,"A entrance blocked at "+str(target)+", actual="+str(entering.position)+", server="+str(server))
					if not reached: break
				if not reverse: require(absf(entering.position.y-base-.03)<.04,"Entrance did not reach atrium ground")
			entering.queue_free()
			print("A OPEN ENTRANCE CHECK server=",server)
		for index in 2:
			center = Vector2(spec.centers[index][0],spec.centers[index][1])
			axis = Vector2(spec.axis[0],spec.axis[1]).normalized()*(-1.0 if index==0 else 1.0)
			across = Vector2(-axis.y,axis.x)
			var clear := space.intersect_ray(PhysicsRayQueryParameters3D.create(at(0,19,0),at(0,.5,0)))
			require(clear.is_empty(),"Atrium void filled by old shell")
			var roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(at(1.2,26,0),at(1.2,20,0)))
			require(not roof.is_empty() and absf(roof.position.y-base-float(spec.roof_y)-float(spec.roof_rise))<.04,"Skylight glass must stop falls from above")
			for side in [-1.0,1.0]:
				var cap := space.intersect_ray(PhysicsRayQueryParameters3D.create(at(side*12.2,21.6,0),at(side*11.8,21.6,0)))
				require(not cap.is_empty(),"Skylight end cap missing")
			var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(at(0,1,0),at(0,-1,0)))
			require(not ground.is_empty() and absf(ground.position.y-base-.03)<.015,"Atrium ground missing or terrain overlap")
			for level in range(1,5):
				var y := float(level)*4.0
				for side in [-1.0,1.0]:
					var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at(-8,y+1,side*5.1),at(-8,y-1,side*5.1)))
					require(not floor_hit.is_empty() and absf(floor_hit.position.y-base-y)<.015,"Gallery floor missing")
					var guard_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at(-8,y+.65,side*5.1),at(-8,y+.65,side*3.4)))
					require(not guard_hit.is_empty(),"Gallery fall protection missing")
			var body := CharacterBody3D.new()
			Movement.setup(body)
			world.add_child(body)
			var route: Array[Vector3] = [Vector3(-5.2,.03,-2.9),Vector3(3.09,4,-2.9),Vector3(3.09,4,-5.1),Vector3(3.09,4,-2.9),Vector3(7.87,6,-2.9),Vector3(13.1,8,-2.9),Vector3(13.1,8,0)]
			for reverse in [false,true]:
				var stations := route.duplicate()
				if reverse: stations.reverse()
				body.position = at(stations[0].x,stations[0].y+.1,stations[0].z)
				body.velocity = Vector3.ZERO
				for frame in 30:
					await physics_frame
					Movement.step(body,Vector2.ZERO,false,false,1.0/60.0,body.position)
				for station in stations.slice(1):
					var target := at(station.x,station.y,station.z)
					var reached := false
					for frame in 480:
						await physics_frame
						var delta := Vector2(target.x-body.position.x,target.z-body.position.z)
						if delta.length()<.12:
							reached = true
							break
						Movement.step(body,delta.normalized()*.45,false,false,1.0/60.0,body.position)
					require(reached,"Atrium route blocked at "+str(station)+", actual="+str(body.position)+", server="+str(server))
					if not reached: break
					require(absf(body.position.y-target.y)<.12,"Atrium route bypassed intended floor at "+str(station)+", actual="+str(body.position)+", expected_y="+str(target.y))
			body.queue_free()
			print("ATRIUM ROUTE CHECK server=",server," instance=",index)
		viewport.queue_free()
		await process_frame
	if not failed: print("A ATRIUM PASS: voids, floors, guards and bidirectional client/server stairs")
	quit(1 if failed else 0)
