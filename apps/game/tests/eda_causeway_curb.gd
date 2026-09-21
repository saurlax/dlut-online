extends SceneTree
const Movement=preload("res://scripts/shared/movement.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var terrain:=preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	var roads: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var saved_samples: Array[Vector3]=[]
	for server in [false,true]:
		var viewport:=SubViewport.new()
		viewport.own_world_3d=true
		root.add_child(viewport)
		var world:=Node3D.new()
		viewport.add_child(world)
		var samples: Array[Vector3]=[]
		if server:
			world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			world.add_child(load("res://assets/campuses/eda/models/terrain.tscn").instantiate())
			var model: Node3D=load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(model)
			var curb: MeshInstance3D=model.get_node("CausewayBrickCurb")
			var faces:=curb.mesh.get_faces()
			var vertical:=0
			for i in range(0,faces.size(),3):
				var a: Vector3=curb.transform*faces[i]
				var b: Vector3=curb.transform*faces[i+1]
				var c: Vector3=curb.transform*faces[i+2]
				var front: Vector3=(c-a).cross(b-a)
				assert(front.length_squared()>0.00000000001,"Degenerate curb triangle")
				if front.normalized().y>0.5:
					for p in [a,b,c]: assert(absf(p.y-terrain.elevation(p.x,p.z)-0.10)<0.002,"Curb height differs from estimate")
					if front.length()>0.002: samples.append((a+b+c)/3.0)
				else:
					assert(absf(front.normalized().y)<0.0001,"Unexpected downward curb face")
					vertical+=1
			assert(vertical>50 and samples.size()>40,"Raised brick sides missing")
			preload("res://scripts/shared/campus_collision.gd").build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space:=world.get_world_3d().direct_space_state
		# Keep identical terrain-relative top probes for both collision worlds.
		if server: samples=saved_samples
		else: saved_samples=samples.duplicate()
		for p in samples:
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.12,p-Vector3.UP*0.025))
			assert(not hit.is_empty() and absf(hit.position.y-p.y)<0.003,"Raised curb collider missing")
		var road_samples:=0
		for road: Dictionary in roads:
			for i in road.points.size()-1:
				var a:=Vector2(road.points[i][0],road.points[i][1])
				var b:=Vector2(road.points[i+1][0],road.points[i+1][1])
				for j in maxi(2,ceili(a.distance_to(b)/0.4)):
					var p:=a.lerp(b,float(j)/maxi(1,ceili(a.distance_to(b)/0.4)-1))
					if not Rect2(-159,174,99,12).has_point(p): continue
					var y: float=terrain.elevation(p.x,p.y)
					var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,y+0.15,p.y),Vector3(p.x,y+0.035,p.y)))
					assert(hit.is_empty(),"Curb blocks road %s at %s hit %s"%[road.osm_way_id,p,hit])
					road_samples+=1
		assert(road_samples>200)
		# Actual shared player capsule: walk the path, turn through a junction,
		# and cross the eight-centimetre edge in both directions without jumping.
		var routes: Array=[
			[Vector2(-108,182.685),Vector2(-90,182.812)],
			[Vector2(-141.3,173.55),Vector2(-137.5694,178.3346),Vector2(-132,179.516)],
			[Vector2(-99,180.75),Vector2(-99,184.75)],
			[Vector2(-99,184.75),Vector2(-99,180.75)],
		]
		for route: Array in routes:
			var player:=CharacterBody3D.new()
			Movement.setup(player)
			var start: Vector2=route[0]
			player.position=Vector3(start.x,terrain.elevation(start.x,start.y)+0.04,start.y)
			world.add_child(player)
			var spawn:=player.position
			for frame in 15:
				await physics_frame
				Movement.step(player,Vector2.ZERO,false,false,1.0/60,spawn)
			for target: Vector2 in route.slice(1):
				for frame in 300:
					var delta:=target-Vector2(player.position.x,player.position.z)
					if delta.length()<0.15: break
					await physics_frame
					Movement.step(player,delta.normalized(),false,false,1.0/60,spawn)
				assert(Vector2(player.position.x,player.position.z).distance_to(target)<0.2,"Player cannot cross causeway route without jumping: "+str(route))
			player.free()
		print("CAUSEWAY CURB PASS server=",server," top probes=",samples.size()," road/junction probes=",road_samples)
		viewport.queue_free()
		await process_frame
	quit()
