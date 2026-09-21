extends SceneTree
const Profile=preload("res://tools/eda_sports_entry_profile.gd")
const Collision=preload("res://scripts/shared/campus_collision.gd")
const Movement=preload("res://scripts/shared/movement.gd")
var p:Dictionary
var failed:=false
func _initialize():run.call_deferred()
func require(ok:bool,message:String)->void:
	if not ok:failed=true;push_error(message)
func floor_y(s:float)->float:
	var top:=float(p.upper_surface_offset_m)
	var lip:=float(p.upper_lip_m)
	var ramp_end:=lip+int(p.risers)*float(p.going_m)
	var landing_end:=lip+(int(p.risers)-1)*float(p.going_m)+float(p.lower_landing_m)
	var low:=top-int(p.risers)*float(p.riser_m)
	var y:=top
	if s>lip:y=lerpf(top,low,clampf((s-lip)/(ramp_end-lip),0,1))
	if s>landing_end:y=lerpf(low,float(p.existing_base_offset_m),clampf((s-landing_end)/(float(p.end_station_m)-landing_end),0,1))
	return float(p.expected_base_y)+y
func at(s:float,c:float)->Vector3:
	var q:=Profile.point(p,s,c)
	return Vector3(q.x,floor_y(s),q.y)
func run()->void:
	p=Profile.load_profile()
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	for server in [false,true]:
		var viewport:=SubViewport.new();viewport.own_world_3d=true;root.add_child(viewport)
		var world:=Node3D.new();viewport.add_child(world)
		if server:world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			var model:Node3D=load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(model);world.add_child(load("res://assets/campuses/eda/models/terrain.tscn").instantiate())
			Collision.build(world,model,manifest,"eda")
		await physics_frame;await physics_frame
		var space:=world.get_world_3d().direct_space_state
		for c in [-2.7,0.0,2.7]:
			for s in [-.5,0.1,2.8,3.4,4.3,5.3,6.5,7.9,8.3]:
				var center:=at(s,c)
				var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3.UP*.8,center-Vector3.UP*.8))
				require(not hit.is_empty() and absf(hit.position.y-center.y)<.015,"Entry floor missing or old base blocks cutout at "+str(s))
			for reverse in [false,true]:
				var actor:=CharacterBody3D.new();Movement.setup(actor);world.add_child(actor)
				var stations:Array[float]=[-.5,1,2.8,3.5,4.5,5.5,7,8.3]
				if reverse:stations.reverse()
				actor.position=at(stations[0],c)+Vector3.UP*.12
				for i in 30:await physics_frame;Movement.step(actor,Vector2.ZERO,false,false,1.0/60,actor.position)
				for station in stations.slice(1):
					var target:=at(station,c);var reached:=false
					for i in 350:
						await physics_frame
						var delta:=Vector2(target.x-actor.position.x,target.z-actor.position.z)
						if delta.length()<.1:reached=true;break
						Movement.step(actor,delta.normalized()*.5,false,false,1.0/60,actor.position)
					require(reached and absf(actor.position.y-target.y)<.18,"Entry route blocked/fell at "+str(station)+" actual="+str(actor.position))
					if not reached:break
				actor.queue_free();await physics_frame
		var lip:=float(p.upper_lip_m)
		var toe:=lip+(int(p.risers)-1)*float(p.going_m)
		var middle:float=(lip+toe)*.5
		var rail_y:=float(p.expected_base_y)+(float(p.upper_surface_offset_m)+.22+float(p.existing_base_offset_m)+.12)*.5+.9
		for sign_side:float in [-1.0,1.0]:
			var start:Vector3=at(middle,sign_side*3.1);start.y=rail_y
			var end:Vector3=at(middle,sign_side*4.1);end.y=rail_y
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(start,end))
			require(not hit.is_empty(),"Sports entrance handrail missing")
		print("SPORTS ENTRY WALK/FLOORS PASS server=",server)
		viewport.queue_free();await process_frame
	quit(1 if failed else 0)
