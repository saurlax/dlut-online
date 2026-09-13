@tool
extends Node3D

@onready var rain: GPUParticles3D = $Rain
@onready var snow: GPUParticles3D = $Snow
@onready var shelter: GPUParticlesCollisionHeightField3D = $Shelter
var rain_level := 0.0
var snow_level := 0.0
var positioned := false

func _ready() -> void:
	# Each campus owns its materials; runtime weather never edits shared resources.
	for particles: GPUParticles3D in [rain, snow]:
		particles.process_material = particles.process_material.duplicate()
		particles.draw_pass_1 = particles.draw_pass_1.duplicate()
		particles.draw_pass_1.material = particles.draw_pass_1.material.duplicate()

func set_weather(rain_amount: float, snow_amount: float, wind: Vector2) -> void:
	rain_level = rain_amount
	snow_level = snow_amount
	_configure(rain, rain_amount, wind, 14.0, 0.35)
	_configure(snow, snow_amount, wind, 1.8, 0.18)

func _configure(particles: GPUParticles3D, level: float, wind: Vector2, fall_speed: float, wind_factor: float) -> void:
	var velocity := Vector3(wind.x * wind_factor, -fall_speed, wind.y * wind_factor)
	var material: ParticleProcessMaterial = particles.process_material
	material.direction = velocity.normalized()
	material.initial_velocity_min = velocity.length() * 0.85
	material.initial_velocity_max = velocity.length() * 1.15
	particles.amount_ratio = maxf(level, 0.001)
	var draw_material: ShaderMaterial = particles.draw_pass_1.material
	draw_material.set_shader_parameter("fall_direction", velocity)
	draw_material.set_shader_parameter("intensity", level)

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var active := camera != null and (rain_level > 0.005 or snow_level > 0.005)
	visible = active
	if not active:
		rain.emitting = false
		snow.emitting = false
		positioned = false
		return
	var centre: Vector3 = camera.global_position
	if not positioned or global_position.distance_to(centre) > 24.0:
		global_position = centre
		shelter.global_position = centre.snapped(Vector3(4.0, 4.0, 4.0))
		rain.restart()
		snow.restart()
		positioned = true
	global_position = centre
	# Quantization avoids redrawing campus geometry for the heightfield every frame.
	var shelter_position := centre.snapped(Vector3(4.0, 4.0, 4.0))
	if shelter.global_position != shelter_position:
		shelter.global_position = shelter_position
	rain.emitting = rain_level > 0.005
	snow.emitting = snow_level > 0.005
