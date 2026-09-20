extends SceneTree

const Movement = preload("res://scripts/shared/movement.gd")
const Water = preload("res://scripts/shared/water.gd")
const Catalog = preload("res://scripts/shared/campus_catalog.gd")
const Collision = preload("res://scripts/shared/campus_collision.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(600).timeout.connect(func(): quit(2))
	for campus: String in ["lingshui", "eda", "panjin"]:
		for server: bool in [false, true]:
			var world: Node3D
			if server:
				world = load("res://scenes/server/%s.scn" % campus).instantiate()
			else:
				world = load(Catalog.CAMPUSES[campus].scene).instantiate()
				# Exercise the exact client collision construction without account/UI setup.
				world.set_script(null)
				var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Catalog.CAMPUSES[campus].manifest))
				Collision.build(world, world.get_node("CampusModel"), manifest, campus)
				world.set_meta("water_regions", world.get_node("Terrain").get_meta("water_regions", []))
			root.add_child(world)
			var body := CharacterBody3D.new()
			Movement.setup(body)
			world.add_child(body)
			await physics_frame
			for region: Dictionary in world.get_meta("water_regions", []):
				var point := deepest_point(region)
				assert(Water.shore_distance(region, point) > 6.0)
				var level := float(region.level)
				body.position = Vector3(point.x, level + 2, point.y)
				body.velocity = Vector3.ZERO
				for frame in 240:
					await physics_frame
					Movement.step(body,Vector2.ZERO,false,false,1.0/60.0,Vector3.ZERO)
				assert(body.position.y < level-1.8, "Water must not retain a walkable surface: " + region.source)
				assert(body.position.y >= level-Water.DEPTH-0.1, "Basin collision must retain the body")
				var before := body.position.y
				for frame in 30:
					await physics_frame
					Movement.step(body,Vector2.ZERO,false,false,1.0/60.0,Vector3.ZERO,true)
				assert(body.position.y > before + 0.4, "Holding jump must ascend")
				var peak := body.position.y
				for frame in 150:
					await physics_frame
					Movement.step(body,Vector2.ZERO,false,false,1.0/60.0,Vector3.ZERO,true)
					peak = maxf(peak,body.position.y)
				assert(peak > level + 0.1, "Surface exit must lift feet above the bank")
				# Follow the nearest shore through the generated collision ramp.
				var shore := point
				var distance := INF
				var ring: PackedVector2Array = region.polygon
				for i in ring.size():
					var q := Geometry2D.get_closest_point_to_segment(point,ring[i],ring[(i+1)%ring.size()])
					if q.distance_to(point) < distance:
						distance = q.distance_to(point)
						shore = q
				body.position = Vector3(point.x,level-2,point.y)
				body.velocity = Vector3.ZERO
				var axis := (shore-point).normalized()
				for frame in int((distance+5.0)/3.0*60.0):
					await physics_frame
					Movement.step(body,axis,false,false,1.0/60.0,Vector3.ZERO,true)
				assert(Water.region_at([region],body.position).is_empty(), "Shore ramp must permit exit: " + region.source)
				print("WATER PHYSICS PASS ",campus," server=",server," ",region.source)
			world.free()
	print("WATER PHYSICS ALL PASS")
	quit()

func deepest_point(region: Dictionary) -> Vector2:
	var best := Vector2.ZERO
	var distance := -1.0
	var bounds: Rect2 = region.bounds
	for x in range(int(bounds.position.x),int(bounds.end.x),3):
		for z in range(int(bounds.position.y),int(bounds.end.y),3):
			var p := Vector2(x,z)
			if Water.region_at([region],Vector3(x,0,z)).is_empty(): continue
			var d := Water.shore_distance(region,p)
			if d > distance:
				distance = d
				best = p
	return best
