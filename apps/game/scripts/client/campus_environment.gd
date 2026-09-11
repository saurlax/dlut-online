@tool
extends Node3D

const Solar = preload("res://scripts/shared/solar_time.gd")
@onready var world: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
var cloud := 0.3
var storm := 0.0
var wind := Vector2(1.0, 0.0)
var offset := Vector2.ZERO
var update_in := 0.0
var initialized := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world.environment = world.environment.duplicate(true)
	_update(0.0)

func _process(delta: float) -> void:
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
	if network != null:
		now = network.environment_unix_time()
		sample = network.campus_weather.get(campus, {})
	var direction := Solar.sun_direction(now, campus)
	var target_cloud := 0.3
	var target_storm := 0.0
	var target_wind := Vector2(1.0, 0.0)
	if Solar.usable_weather(sample, now):
		target_cloud = clampf(float(sample.get("cloud_cover", 30.0))/100.0,0.0,1.0)
		var code := int(sample.get("weather_code",0))
		target_storm = 0.85 if code >= 95 else (0.5 if code >= 51 else (0.35 if code in [45,48] else 0.0))
		target_cloud = maxf(target_cloud, 0.9 if target_storm > 0.0 else 0.0)
		var angle := deg_to_rad(float(sample.get("wind_direction",270.0)))
		target_wind = Vector2(-sin(angle),cos(angle))*clampf(float(sample.get("wind_speed",1.0)),0.0,40.0)
	var blend := 1.0 if not initialized else 1.0-exp(-delta/20.0)
	initialized = true
	cloud = lerpf(cloud,target_cloud,blend)
	storm = lerpf(storm,target_storm,blend)
	wind = wind.lerp(target_wind,blend)
	offset += wind*delta
	sun.look_at_from_position(Vector3.ZERO,-direction,Vector3.UP)
	var daylight := smoothstep(-0.10,0.18,direction.y)
	sun.light_energy = smoothstep(-0.015,0.25,direction.y)*(1.0-cloud*0.72)*(1.0-storm*0.6)
	sun.light_color = Color(1.0,0.53,0.3).lerp(Color(1.0,0.96,0.88),smoothstep(0.0,0.3,direction.y))
	world.environment.ambient_light_color = Color(0.27,0.35,0.55).lerp(Color(0.78,0.84,0.94),daylight)
	world.environment.ambient_light_energy = lerpf(0.055,0.48,daylight)*(1.0-storm*0.3)
	world.environment.fog_light_color = Color(0.018,0.025,0.045).lerp(Color(0.59,0.67,0.73),daylight)
	world.environment.fog_density = lerpf(0.000025,0.00065,storm)
	var material: ShaderMaterial = world.environment.sky.sky_material
	material.set_shader_parameter("sun_direction",direction)
	material.set_shader_parameter("cloud_cover",cloud)
	material.set_shader_parameter("storm",storm)
	material.set_shader_parameter("cloud_offset",offset)
	var camera := get_viewport().get_camera_3d()
	if camera != null: material.set_shader_parameter("camera_position", camera.global_position)
