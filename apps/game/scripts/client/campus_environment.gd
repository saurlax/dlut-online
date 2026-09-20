@tool
extends Node3D

const Graphics = preload("res://scripts/client/graphics_settings.gd")

const LocalSession = preload("res://scripts/client/local_session.gd")
var local_revision := -1

const Solar = preload("res://scripts/shared/solar_time.gd")
const Weather = preload("res://scripts/client/weather_effects.gd")
@onready var world: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var precipitation: Node3D = $Precipitation
var effects := Vector3(0.0, 0.0, 0.000025)
var cloud := 0.3
var storm := 0.0
var wind := Vector2(1.0, 0.0)
var offset := Vector2.ZERO
var update_in := 0.0
var initialized := false
var water_phase := 0.0
var water_material: ShaderMaterial = preload("res://assets/water/campus_water.tres")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world.environment = world.environment.duplicate(true)
	world.environment.ssr_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"
	if not Engine.is_editor_hint():
		add_to_group(Graphics.GROUP)
		apply_graphics_settings()
	_update(0.0)

func _process(delta: float) -> void:
	water_phase += delta * (0.9 + sqrt(wind.length()) * 0.6)
	water_material.set_shader_parameter("wave_phase", water_phase)
	update_in -= delta
	if update_in > 0.0: return
	var elapsed := 0.25 - update_in
	update_in = 0.25
	_update(elapsed)

func _update(delta: float) -> void:
	var campus: String = get_parent().get("campus_id") if get_parent().get("campus_id") != null else "lingshui"
	var network := get_node_or_null("/root/GameNetwork") if not Engine.is_editor_hint() else null
	var now := Time.get_unix_time_from_system()
	var sample: Dictionary = {}
	if not Engine.is_editor_hint() and LocalSession.enabled:
		now = LocalSession.unix_time()
		sample = LocalSession.weather()
		if local_revision != LocalSession.revision:
			initialized = false
			local_revision = LocalSession.revision
	elif network != null:
		now = network.environment_unix_time()
		sample = network.campus_weather.get(campus, {})
	var direction := Solar.sun_direction(now, campus)
	var target_cloud := 0.3
	var target_storm := 0.0
	var target_wind := Vector2(1.0, 0.0)
	var target_effects := Weather.profile(0)
	if Solar.usable_weather(sample, now):
		target_cloud = clampf(float(sample.get("cloud_cover", 30.0))/100.0,0.0,1.0)
		var code := int(sample.get("weather_code",0))
		target_effects = Weather.profile(code)
		target_storm = 0.85 if code in [95, 96, 99] else (0.5 if target_effects.x + target_effects.y > 0.0 else (0.2 if code in [45,48] else 0.0))
		target_cloud = maxf(target_cloud, 0.9 if target_storm > 0.0 else 0.0)
		var angle := deg_to_rad(float(sample.get("wind_direction",270.0)))
		target_wind = Vector2(-sin(angle),cos(angle))*clampf(float(sample.get("wind_speed",1.0)),0.0,40.0)
	var blend := 1.0 if not initialized else 1.0-exp(-delta/20.0)
	initialized = true
	cloud = lerpf(cloud,target_cloud,blend)
	storm = lerpf(storm,target_storm,blend)
	wind = wind.lerp(target_wind,blend)
	water_material.set_shader_parameter("wind_velocity", wind)
	effects = effects.lerp(target_effects, blend)
	precipitation.set_weather(effects.x, effects.y, wind)
	offset += wind*delta
	sun.look_at_from_position(Vector3.ZERO,-direction,Vector3.UP)
	var daylight := smoothstep(-0.10,0.18,direction.y)
	sun.light_energy = smoothstep(-0.015,0.25,direction.y)*(1.0-cloud*0.72)*(1.0-storm*0.6)
	sun.light_color = Color(1.0,0.53,0.3).lerp(Color(1.0,0.96,0.88),smoothstep(0.0,0.3,direction.y))
	world.environment.ambient_light_color = Color(0.27,0.35,0.55).lerp(Color(0.78,0.84,0.94),daylight)
	world.environment.ambient_light_energy = lerpf(0.055,0.48,daylight)*(1.0-storm*0.3)
	world.environment.fog_light_color = Color(0.018,0.025,0.045).lerp(Color(0.59,0.67,0.73),daylight)
	world.environment.fog_density = effects.z
	world.environment.fog_sky_affect = lerpf(0.08, 0.85, clampf(effects.z / 0.009, 0.0, 1.0))
	var material: ShaderMaterial = world.environment.sky.sky_material
	material.set_shader_parameter("sun_direction",direction)
	material.set_shader_parameter("cloud_cover",cloud)
	material.set_shader_parameter("storm",storm)
	material.set_shader_parameter("cloud_offset",offset)
	var camera := get_viewport().get_camera_3d()
	if camera != null: material.set_shader_parameter("camera_position", camera.global_position)

func apply_graphics_settings() -> void:
	Graphics.apply_viewport(get_viewport())
	Graphics.apply_environment(world.environment, sun)
