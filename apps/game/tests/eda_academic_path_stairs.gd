extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")
const Movement = preload("res://scripts/shared/movement.gd")
const START := Vector2(149.5541,109.7949)
const END := Vector2(161.8153,132.0812)
const RAMPS := [Vector2(7.68,8.64),Vector2(14.68,15.64)]
var terrain = preload("res://tools/build_terrain.gd").new()
var axis := (END-START).normalized()
var side := Vector2(-axis.y,axis.x)
var low: float
var rise: float

func point(station: float, cross: float) -> Vector2:
	return START+axis*station+side*cross

func elevation(station: float, cross := 0.0) -> float:
	var p := point(station,cross)
	return terrain.elevation(p.x,p.y)+0.02

func expected(station: float, cross := 0.0) -> float:
	var value := low
	for ramp: Vector2 in RAMPS:
		value+=3.0*rise*clampf((station-ramp.x)/(ramp.y-ramp.x),0.0,1.0)
	var blend := minf(clampf((station-4.0)/0.8,0.0,1.0),clampf((18.0-station)/0.8,0.0,1.0))
	return lerpf(elevation(station,cross),value,blend)

func cast(space: PhysicsDirectSpaceState3D, p: Vector2, top: float, bottom: float) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,top,p.y),Vector3(p.x,bottom,p.y),1))

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	var profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/academic_c_stairs.json"))
	assert(profile.expected_points==[[149.5541,109.7949],[161.8153,132.0812]])
	assert(profile.station_range_m==[4.0,18.0] and profile.width_m==2.0)
	assert(profile.ramp_ranges_m==[[7.68,8.64],[14.68,15.64]])
	terrain.load_campus("eda")
	low=elevation(4)
	rise=(elevation(18)-low)/6.0
	assert(absf(float(profile.low_landing_y)-low)<.002 and absf(float(profile.riser_height_m)-rise)<.002)
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	for server in [false,true]:
		var viewport:=SubViewport.new()
		viewport.own_world_3d=true
		root.add_child(viewport)
		var world:=Node3D.new()
		viewport.add_child(world)
		if server: world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			var model: Node3D=load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(model)
			world.add_child(load("res://assets/campuses/eda/models/terrain.tscn").instantiate())
			check_visual(model)
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space:=world.get_world_3d().direct_space_state
		# Independent top heights detect any leftover slope above a lowered platform.
		for station in [4.1,5.0,6.0,7.5,7.84,8.16,8.48,9.0,10.0,12.0,14.5,14.84,15.16,15.48,16.0,17.0,17.9]:
			for cross in [-0.9,-0.5,0.0,0.5,0.9]:
				var p:=point(station,cross)
				var y:=expected(station,cross)
				var hit:=cast(space,p,y+1.0,y-1.0)
				assert(not hit.is_empty() and absf(hit.position.y-y)<0.035,"Stair/platform top differs: server=%s station=%s cross=%s expected=%s hit=%s" % [server,station,cross,y,hit])
		# Under-platform rays reject buried old road/terrain triangles as well as upper remnants.
		for station in [5.0,6.0,9.0,12.0,14.0,16.0,17.0]:
			for cross in [-.5,0.0,.5]:
				var p:=point(station,cross)
				var y:=expected(station,cross)
				var buried:=cast(space,p,y-.03,minf(y,elevation(station,cross))-.15)
				assert(buried.is_empty(),"Old sloped road or terrain collision remains under new platform")
		# Full-width entry/exit heights must match the same fitted road, including crossfall.
		for station in [4.0,4.05,4.4,4.8,17.2,17.6,17.95,18.0]:
			for cross in [-.98,-.5,0.0,.5,.98]:
				var p:=point(station,cross)
				var y:=expected(station,cross)
				var hit:=cast(space,p,y+.6,y-.6)
				assert(not hit.is_empty() and absf(hit.position.y-y)<.035,"Full-width endpoint join is discontinuous")
		for cross in [-0.5,0.0,0.5]:
			await walk(world,point(3,cross),point(19,cross))
			await walk(world,point(19,cross),point(3,cross))
		# Side passability depends on actual height; never assume a tall retaining edge is a ramp.
		for station in [6.0,7.0,12.0,14.0,17.0]:
			for sign_value in [-1.0,1.0]:
				var inside:=point(station,sign_value*.45)
				var outside:=point(station,sign_value*1.7)
				var inner_hit:=cast(space,inside,5,-5)
				var outer_hit:=cast(space,outside,5,-5)
				assert(not inner_hit.is_empty() and not outer_hit.is_empty())
				var difference: float=inner_hit.position.y-outer_hit.position.y
				if absf(difference)<.06:
					await walk(world,inside,outside)
					await walk(world,outside,inside)
				elif absf(difference)>.16:
					var midpoint: float=(inner_hit.position.y+outer_hit.position.y)*.5
					var query:=PhysicsRayQueryParameters3D.create(Vector3(inside.x,midpoint,inside.y),Vector3(outside.x,midpoint,outside.y),1)
					var wall:=space.intersect_ray(query)
					assert(not wall.is_empty(),"Retaining side has no physical boundary")
					await blocked_side(world,outside if difference>0 else inside,inside if difference>0 else outside)
					print("C PATH SIDE BOUNDARY station=",station," side=",sign_value," delta=",difference)
		print("C PATH STAIRS WALK PASS server=",server)
		viewport.free()
	quit()

func walk(world: Node3D, from: Vector2, to: Vector2) -> void:
	var space:=world.get_world_3d().direct_space_state
	var hit:=cast(space,from,5,-5)
	assert(not hit.is_empty(),"No ground at stair route start")
	var body:=CharacterBody3D.new()
	Movement.setup(body)
	world.add_child(body)
	body.position=hit.position+Vector3.UP*.25
	var spawn:=body.position
	for frame in 30:
		await physics_frame
		Movement.step(body,Vector2.ZERO,false,false,1.0/60.0,spawn)
	assert(body.is_on_floor(),"Player failed to settle at path start")
	var direction: Vector2=(to-from).normalized()
	var distance:=from.distance_to(to)
	var reached:=false
	var airborne:=0
	for frame in ceili(distance/Movement.WALK_SPEED*60)+90:
		await physics_frame
		Movement.step(body,direction,false,false,1.0/60.0,spawn)
		var at:=Vector2(body.position.x,body.position.z)
		var along: float=(at-from).dot(direction)
		assert(absf((at-from).cross(direction))<.15,"Path test slid sideways instead of traversing")
		airborne=0 if body.is_on_floor() else airborne+1
		assert(airborne<8,"Stairs caused an uncommanded fall")
		assert(body.position.y> -3,"Player fell through stair replacement")
		if along>=distance-.10:
			reached=true
			break
	assert(reached,"Stairs or platform side obstruct no-jump walking")
	body.free()

func check_visual(model: Node3D) -> void:
	var stone := model.get_node_or_null("AcademicCStairStone") as MeshInstance3D
	assert(stone!=null,"Saved model is missing visible path stairs")
	assert(not stone.get_meta("walk_collision",false),"Visible risers must not block the ramp walking surface")
	var levels := {}
	var faces := stone.mesh.get_faces()
	for i in range(0,faces.size(),3):
		var first: Vector3=stone.transform*faces[i]
		var second: Vector3=stone.transform*faces[i+1]
		var third: Vector3=stone.transform*faces[i+2]
		var s0: float=(Vector2(first.x,first.z)-START).dot(axis)
		var s1: float=(Vector2(second.x,second.z)-START).dot(axis)
		var s2: float=(Vector2(third.x,third.z)-START).dot(axis)
		if maxf(s0,maxf(s1,s2))-minf(s0,minf(s1,s2))>.002:continue
		var height: float=maxf(first.y,maxf(second.y,third.y))-minf(first.y,minf(second.y,third.y))
		if absf(height-rise)>.005:continue
		for station in [8.0,8.32,8.64,15.0,15.32,15.64]:
			if absf(s0-station)<.005:levels[station]=true
	assert(levels.size()==6,"Saved visual surface must retain all six riser faces")

func blocked_side(world: Node3D, from: Vector2, to: Vector2) -> void:
	var hit:=cast(world.get_world_3d().direct_space_state,from,5,-5)
	var body:=CharacterBody3D.new()
	Movement.setup(body)
	world.add_child(body)
	body.position=hit.position+Vector3.UP*.2
	var spawn:=body.position
	for frame in 25:
		await physics_frame
		Movement.step(body,Vector2.ZERO,false,false,1.0/60.0,spawn)
	var direction: Vector2=(to-from).normalized()
	for frame in 45:
		await physics_frame
		Movement.step(body,direction,false,false,1.0/60.0,spawn)
	var at:=Vector2(body.position.x,body.position.z)
	assert((at-from).dot(direction)<from.distance_to(to)-.25,"Player penetrated tall retaining side")
	body.free()
