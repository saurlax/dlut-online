extends SceneTree
const Collision=preload("res://scripts/shared/campus_collision.gd")
var frame
var base: float
func _initialize(): run.call_deferred()
func point(x:float,y:float,z:float)->Vector3: return frame.point(x,y+base,z)
func walk(player:CharacterBody3D,target:Vector3)->bool:
	for i in 480:
		await physics_frame
		var delta:=target-player.position
		delta.y=0
		if delta.length()<0.09: return true
		var dir:=delta.normalized()
		player.velocity.x=dir.x*3
		player.velocity.z=dir.z*3
		player.velocity.y=-2 if player.is_on_floor() else player.velocity.y-24.0/60
		player.move_and_slide()
	push_error("B exterior stair route blocked: "+str(player.position)+" -> "+str(target))
	return false
func run():
	create_timer(90).timeout.connect(func(): quit(2))
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var points:=PackedVector2Array()
	for feature in manifest.features:
		if feature.id=="77928":
			for p in feature.points: points.append(Vector2(p[0],p[1]))
	var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/buildings/academic_facades.json"))["77928"].osm_registration.south_end
	frame=preload("res://tools/build_eda_b_south_end.gd").new()
	frame.configure(points,profile)
	var terrain:=preload("res://tools/build_terrain.gd").new();terrain.load_campus("eda")
	base=terrain.data.feature_base_y.Feature_77928
	for server in [false,true]:
		var viewport:=SubViewport.new();viewport.own_world_3d=true;root.add_child(viewport)
		var world:=Node3D.new();viewport.add_child(world)
		if server: world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			var model:Node3D=load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(model)
			assert(not model.get_node("Feature_77928/BSouthStairCollision").visible,"Walking ramp must stay hidden after mesh batching")
			world.add_child(load("res://assets/campuses/eda/models/terrain.tscn").instantiate())
			Collision.build(world,model,manifest,"eda")
			for child in world.get_node("Terrain").get_children():
				if child is MeshInstance3D: Collision._collider(child)
		await physics_frame
		await physics_frame
		var space:=world.get_world_3d().direct_space_state
		var length:float=frame.length
		for x in [length*0.53,length*0.72,length*0.95]:
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(point(x,8,-2),point(x,3,-2)))
			assert(not hit.is_empty() and absf(hit.position.y-base-4.4)<0.015,"B arcade floor missing")
			hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(point(x,6,-1),point(x,6,-5)))
			assert(not hit.is_empty() and hit.position.distance_to(point(x,6,-3.8))<0.02,"B arcade must retain a closed rear wall")
			for direction in [-1.0,1.0]:
				hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(point(x,9.69+direction,-1),point(x,9.69-direction,-1)))
				assert(not hit.is_empty() and absf(hit.position.y-base-9.69-direction*0.09)<0.015,"B arcade roof top/bottom gap x="+str(x)+" side="+str(direction)+" hit="+str(hit))
		for fraction in [0.57,0.9]:
			var x:float=length*fraction
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(point(x,6,1),point(x,6,-1)))
			assert(not hit.is_empty() and hit.position.distance_to(point(x,6,-0.13))<0.015,"B circular column collision radius")
			assert(hit.normal.dot(Vector3(frame.out.x,0,frame.out.y))>0.98,"B column normal faces inward")
		var player:=CharacterBody3D.new();player.floor_snap_length=0.45
		var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=0.3;capsule.height=1.8;shape.shape=capsule;player.add_child(shape);world.add_child(player)
		var start:=point(length+1.5,0,1.1);start.y=terrain.elevation(start.x,start.z)+1.0
		player.position=start
		for i in 25:
			await physics_frame
			player.velocity=Vector3(0,-2,0);player.move_and_slide()
		var landing:=point(length*0.53,5.3,1.1)
		assert(await walk(player,landing),"Stair landing route")
		assert(absf(player.position.y-base-5.3)<0.08 and player.is_on_floor(),"Stair ascent must reach landing without jumping")
		assert(await walk(player,point(length*0.53,5.3,-2)),"Enter exterior arcade")
		assert(absf(player.position.y-base-5.3)<0.08,"Arcade floor cannot drop through")
		assert(await walk(player,landing),"Stair landing route")
		assert(await walk(player,start),"Stair descent route")
		assert(player.is_on_floor() and absf(player.position.y-start.y+0.1)<0.12,"Stair descent must reach terrain")
		print("B SOUTH END PASS server=",server," floor, closed rear wall, roof top/underside, two outward columns and ascent/arcade/descent")
		viewport.free()
	quit()
