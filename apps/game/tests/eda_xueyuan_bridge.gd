extends SceneTree
const Movement = preload("res://scripts/shared/movement.gd")
const Collision = preload("res://scripts/shared/campus_collision.gd")
var failed := false
var helper
var ground
func _initialize() -> void: run.call_deferred()
func require(ok: bool, message: String) -> void:
	if not ok:
		failed=true
		push_error(message)
func at(s:float, y:float, z:float=0.0) -> Vector3:
	return helper.world(Vector3(s,y,z))

func check_closed_ribs(feature:Node3D)->void:
	var count:int=ceili(helper.length/float(helper.profile.rib_spacing))
	var rings:Dictionary={}
	for mesh:MeshInstance3D in feature.get_children():
		if mesh.material_override.resource_name!="EDA Xueyuan bridge frame":continue
		var vertices:PackedVector3Array=mesh.mesh.get_faces()
		for i in range(0,vertices.size(),3):
			var first:Vector3=mesh.transform*vertices[i]
			var relative:Vector2=Vector2(first.x,first.z)-helper.start
			var index:int=roundi(relative.dot(helper.axis)/helper.length*count)
			var station:float=helper.length*index/count
			var keys:Array[String]=[]
			for j in 3:
				var p:Vector3=mesh.transform*vertices[i+j]
				var delta:Vector2=Vector2(p.x,p.z)-helper.start
				if absf(absf(delta.dot(helper.axis)-station)-.09)>.00015:break
				keys.append("%d,%d,%d"%[roundi(p.x*10000),roundi(p.y*10000),roundi(p.z*10000)])
			if keys.size()!=3:continue
			if not rings.has(index):rings[index]={"edges":{},"adjacent":{}}
			var ring:Dictionary=rings[index]
			for j in 3:
				var a:=keys[j];var b:=keys[(j+1)%3]
				var edge:=a+"/"+b if a<b else b+"/"+a
				ring.edges[edge]=ring.edges.get(edge,0)+1
				if not ring.adjacent.has(a):ring.adjacent[a]=[]
				if not ring.adjacent.has(b):ring.adjacent[b]=[]
				ring.adjacent[a].append(b);ring.adjacent[b].append(a)
	require(rings.size()==count+1,"Missing elliptical ribs")
	for index in rings:
		var ring:Dictionary=rings[index]
		for uses in ring.edges.values():require(uses==2,"Elliptical rib has an open or overlapping seam")
		var pending:Array=[ring.adjacent.keys()[0]]
		var visited:Dictionary={}
		while not pending.is_empty():
			var key:String=pending.pop_back()
			if visited.has(key):continue
			visited[key]=true
			pending.append_array(ring.adjacent[key])
		require(visited.size()==ring.adjacent.size(),"Elliptical rib is still disconnected short members")
	print("BRIDGE CLOSED RIBS checked=",rings.size())
func check_underdeck(feature: Node3D) -> void:
	var meshes := 0
	for mesh: MeshInstance3D in feature.get_children():
		if mesh.material_override.resource_name != "EDA Xueyuan bridge underside ribs": continue
		meshes += 1
		require(not mesh.get_meta("walk_collision",false),"Shallow underside finish must not add collision")
		var edges: Dictionary = {}
		var adjacent: Dictionary = {}
		var vertices := mesh.mesh.get_faces()
		for i in range(0,vertices.size(),3):
			var keys: Array[String] = []
			for j in 3:
				var p: Vector3 = mesh.transform*vertices[i+j]
				keys.append("%d,%d,%d" % [roundi(p.x*10000),roundi(p.y*10000),roundi(p.z*10000)])
			for j in 3:
				var a := keys[j]; var b := keys[(j+1)%3]
				var edge := a+"/"+b if a<b else b+"/"+a
				edges[edge] = edges.get(edge,0)+1
				if not adjacent.has(a): adjacent[a]=[]
				if not adjacent.has(b): adjacent[b]=[]
				adjacent[a].append(b); adjacent[b].append(a)
		for uses in edges.values(): require(uses==2,"Underdeck rib has an open or overlapping seam")
		var visited: Dictionary = {}
		var components := 0
		for key in adjacent:
			if visited.has(key): continue
			components += 1
			var pending: Array = [key]
			while not pending.is_empty():
				var current: String = pending.pop_back()
				if visited.has(current): continue
				visited[current]=true
				pending.append_array(adjacent[current])
		require(components==int(helper.profile.underdeck_ribs.count),"Underdeck ribs must remain individually closed continuous members")
		print("BRIDGE UNDERDECK CLOSED components=",components," triangles=",vertices.size()/3)
	require(meshes==1,"Expected one merged underside material batch")

func check_normals(feature: Node3D) -> void:
	var checked := 0
	var incorrect := 0
	for mesh: MeshInstance3D in feature.get_children():
		if not mesh.material_override.resource_name.begins_with("EDA Xueyuan bridge"): continue
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
		if mesh.material_override is StandardMaterial3D:
			require(mesh.material_override.cull_mode==BaseMaterial3D.CULL_BACK,"Bridge material must use outward single faces")
		else:
			require(mesh.material_override is ShaderMaterial and "cull_back" in mesh.material_override.shader.code,"Bridge shader must use outward single faces")
	require(checked>1000 and incorrect==0,"Bridge saved normals disagree with face winding: "+str(incorrect))
	print("BRIDGE NORMALS checked=",checked," incorrect=",incorrect)

func check_west_fixtures(space: PhysicsDirectSpaceState3D, server: bool) -> void:
	# Both panel faces must stop a player; the center stair approach stays open.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/site_fixtures.json"))
	var boards: Dictionary = data.bridge_west_noticeboards
	for across: float in boards.across_m:
		var center: Vector3 = at(float(boards.station_m),0,across)
		var floor_y: float = ground.elevation(center.x,center.z)
		for offset in [-float(boards.width_m)*0.25,float(boards.width_m)*0.25]:
			var middle := at(float(boards.station_m),floor_y+1.4,across+offset)
			var normal := Vector3(helper.axis.x,0,helper.axis.y)
			for side in [-1.0,1.0]:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(middle-normal*side*0.6,middle+normal*side*0.6))
				require(not hit.is_empty() and hit.position.distance_to(middle)<0.08,"Noticeboard panel collision missing or offset")
				var capsule := CapsuleShape3D.new()
				capsule.radius=0.3
				capsule.height=1.7
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape=capsule
				query.transform=Transform3D(Basis.IDENTITY,middle-normal*side*0.8)
				query.motion=normal*side*1.6
				var sweep := space.cast_motion(query)
				require(sweep[0]<0.5,"Player capsule passes through noticeboard")
	for across in [-1.7,0.0,1.7]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at(-2,helper.west_y+1.4,across),at(1,helper.west_y+1.4,across)))
		require(hit.is_empty(),"West fixtures obstruct stair approach")
	print("BRIDGE WEST FIXTURES PASS server=",server)

func run() -> void:
	ground=preload("res://tools/build_terrain.gd").new()
	ground.load_campus("eda")
	var p:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/structures/xueyuan_bridge.json"))
	helper=preload("res://tools/build_eda_xueyuan_bridge.gd").new()
	helper.profile=p
	helper.start=Vector2(p.west[0],p.west[1])
	var end:=Vector2(p.east[0],p.east[1])
	helper.length=helper.start.distance_to(end)
	helper.axis=(end-helper.start).normalized()
	helper.across=Vector2(-helper.axis.y,helper.axis.x)
	helper.west_run=float(p.west_steps)*float(p.west_tread)
	helper.east_run=float(p.east_steps)*float(p.east_tread)
	helper.west_y=ground.elevation(helper.start.x,helper.start.y)+.03
	helper.east_y=ground.elevation(end.x,end.y)+.03
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	for server in [false,true]:
		var viewport:=SubViewport.new()
		viewport.own_world_3d=true
		root.add_child(viewport)
		var world:=Node3D.new()
		viewport.add_child(world)
		if server:
			world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			var model:Node3D=load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(model)
			world.add_child(load("res://assets/campuses/eda/models/terrain.tscn").instantiate())
			check_normals(model.get_node("XueyuanBridge"))
			check_closed_ribs(model.get_node("XueyuanBridge"))
			check_underdeck(model.get_node("XueyuanBridge"))
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space:=world.get_world_3d().direct_space_state
		check_west_fixtures(space,server)
		for s in [10.0,25.0,40.0,55.0,70.0,85.0]:
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(at(s,helper.walk_y(s)+.6),at(s,helper.walk_y(s)-1)))
			require(not hit.is_empty() and absf(hit.position.y-helper.walk_y(s))<.015,"Missing bridge deck")
			for side in [-1.0,1.0]:
				var guard:=space.intersect_ray(PhysicsRayQueryParameters3D.create(at(s,helper.walk_y(s)+1.15,side*2),at(s,helper.walk_y(s)+1.15,side*3)))
				require(not guard.is_empty(),"Missing bridge fall guard")
		var actor:=CharacterBody3D.new()
		Movement.setup(actor)
		world.add_child(actor)
		var route:Array[Vector3]=[]
		for s:float in [-.8,0,3,6,16,26,36,46,56,66,76,86,94,99,104,109.0,110.1]:
			var pos:=at(s,helper.walk_y(s))
			if s<0 or s>helper.length:pos.y=ground.elevation(pos.x,pos.z)+.03
			route.append(pos)
		for reverse in [false,true]:
			var stations:=route.duplicate()
			if reverse:stations.reverse()
			actor.position=stations[0]+Vector3.UP*.12
			actor.velocity=Vector3.ZERO
			for frame in 30:
				await physics_frame
				Movement.step(actor,Vector2.ZERO,false,false,1.0/60,actor.position)
			for target in stations.slice(1):
				var reached:=false
				for frame in 800:
					await physics_frame
					var delta:=Vector2(target.x-actor.position.x,target.z-actor.position.z)
					if delta.length()<.10:
						reached=true
						break
					Movement.step(actor,delta.normalized()*.65,false,false,1.0/60,actor.position)
				require(reached,"Bridge route blocked: "+str(target)+" actual="+str(actor.position)+" server="+str(server))
				if not reached:break
				require(absf(actor.position.y-target.y)<.22,"Bridge route fell off intended floor")
		actor.queue_free()
		print("BRIDGE WALK PASS server=",server)
		# The carriageways under the bridge retain terrain-level surfaces and headroom.
		var roads:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json"))
		for road in roads.roads:
			if int(road.osm_way_id) not in [188806483,188806490]:continue
			for i in range(road.points.size()-1):
				var a:=Vector2(road.points[i][0],road.points[i][1])
				var b:=Vector2(road.points[i+1][0],road.points[i+1][1])
				var crossing:Variant=Geometry2D.segment_intersects_segment(a,b,helper.start,end)
				if crossing==null:continue
				var center:Vector2=crossing
				var floor_y:float=ground.elevation(center.x,center.y)+.02
				var floor_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(center.x,floor_y+.3,center.y),Vector3(center.x,floor_y-.3,center.y)))
				require(not floor_hit.is_empty() and absf(floor_hit.position.y-floor_y)<.015,"Bridge road missing")
				var clearance:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(center.x,floor_y+.1,center.y),Vector3(center.x,floor_y+5.2,center.y)))
				require(clearance.is_empty(),"Bridge road headroom under 5.2m")
				if not server:
					var underside: Node3D = world.get_child(0).get_node("XueyuanBridge")
					var minimum_y := INF
					for mesh: MeshInstance3D in underside.get_children():
						if mesh.material_override.resource_name != "EDA Xueyuan bridge underside ribs": continue
						for vertex in mesh.mesh.get_faces(): minimum_y=minf(minimum_y,(mesh.transform*vertex).y)
					require(is_finite(minimum_y) and minimum_y-floor_y>=5.2,"Visible underside ribs reduce road headroom below 5.2m")
					print("BRIDGE VISIBLE UNDERSIDE minimum clearance=",minimum_y-floor_y)
				print("BRIDGE ROAD PASS ",road.osm_way_id," floor=",floor_y)
		viewport.queue_free()
		await process_frame
	if not failed:print("XUEYUAN BRIDGE PASS")
	quit(1 if failed else 0)
