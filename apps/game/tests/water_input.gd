extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var server := preload("res://scripts/server/game_server.gd").new()
	var world := Node3D.new()
	world.set_meta("spawn", Vector3.ZERO)
	world.set_meta("water_regions", [{"bounds":Rect2(-10,-10,20,20), "polygon":PackedVector2Array([Vector2(-10,-10),Vector2(10,-10),Vector2(10,10),Vector2(-10,10)]), "holes":[], "level":0.0}])
	root.add_child(world)
	var player := preload("res://scripts/client/player.gd").new()
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.position = Vector3(0,-2,0)
	var c := {"seq":-1, "epoch":1, "frozen":false, "transfer":{}, "campus":"test", "body":player, "jump":0}
	var packet := {"seq":1, "map_epoch":1, "axis":[0,0], "run":false, "yaw":0, "jump":0, "rise":true}
	server.receive_input(c,packet)
	assert(c.rise)
	server.worlds.test = world
	server.players.test = c
	await physics_frame
	server._physics_process(1.0/60.0)
	assert(player.velocity.y > 0, "Server must apply held ascent")
	packet.seq = 2
	packet.rise = false
	server.receive_input(c,packet)
	player.velocity = Vector3.ZERO
	server._physics_process(1.0/60.0)
	assert(player.velocity.y < 0, "Release must stop ascent")
	packet.seq = 3
	packet.rise = true
	server.receive_input(c,packet)
	c.last_input = Time.get_ticks_msec()-501
	player.velocity = Vector3.ZERO
	server._physics_process(1.0/60.0)
	assert(player.velocity.y < 0, "Stale held input must not ascend")
	packet.seq = 4
	packet.erase("rise")
	server.receive_input(c,packet)
	assert(not c.rise, "Missing rise defaults to false")
	player.playing = true
	var touch := preload("res://scripts/client/touch_controls.gd").new()
	touch.player = player
	root.add_child(touch)
	var press := InputEventScreenTouch.new()
	press.index = 7
	press.pressed = true
	press.position = Vector2(touch.size.x-112,touch.size.y-120)
	touch._unhandled_input(press)
	assert(player.touch_rising and player.touch_jump)
	press.pressed = false
	press.position = Vector2.ZERO
	touch._input(press)
	assert(not player.touch_rising, "Release outside the button must clear ascent")
	player.touch_rising = true
	player.rising = true
	player.stop()
	assert(not player.rising and not player.touch_rising and touch.jump_finger == -1)
	var environment: Node3D = load("res://scenes/campus_environment.tscn").instantiate()
	world.add_child(environment)
	var network := root.get_node("GameNetwork")
	var now := Time.get_unix_time_from_system()
	network.campus_weather = {"lingshui":{"status":"live", "observed_at":now, "wind_direction":0, "wind_speed":10, "cloud_cover":20, "weather_code":0}}
	environment.initialized = false
	environment._update(0.0)
	assert(environment.wind.is_equal_approx(Vector2(0,10)), "Northerly wind must propagate south")
	assert(environment.water_material.get_shader_parameter("wind_velocity").is_equal_approx(environment.wind))
	network.campus_weather.lingshui.wind_direction = 270
	environment.initialized = false
	environment._update(0.0)
	assert(environment.wind.is_equal_approx(Vector2(10,0)), "Westerly wind must propagate east")
	network.campus_weather.lingshui.observed_at = now-10801
	environment.initialized = false
	environment._update(0.0)
	assert(environment.wind.is_equal_approx(Vector2(1,0)), "Expired weather must use neutral fallback")
	player._update_underwater()
	assert(player.camera.environment != null)
	player.position.y = 2
	player._update_underwater()
	assert(player.camera.environment == null, "Leaving water must restore live world environment")
	network.campus_weather.clear()
	touch.free()
	server.free()
	world.free()
	print("WATER INPUT PASS: server hold/release/timeout/default, touch release/pause, weather direction/expiry and underwater restoration")
	quit()
