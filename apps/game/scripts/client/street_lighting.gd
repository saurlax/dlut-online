@tool
extends Node3D
## CampusEnvironment supplies the same solar elevation used by the sky.
var lights: Array[SpotLight3D] = []
var lens_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("campus_night_lighting")
	for child in get_children():
		if child is SpotLight3D:
			lights.append(child)
	var lens := get_node("Lens") as MeshInstance3D
	lens_material = lens.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	lens.set_surface_override_material(0, lens_material)
	set_night_level(0.0)

func set_night_level(level: float) -> void:
	var amount := clampf(level, 0.0, 1.0)
	for light in lights:
		light.visible = amount > 0.001
		light.light_energy = 4.0 * amount
	if lens_material != null:
		lens_material.emission_enabled = amount > 0.001
		lens_material.emission = Color("fff0cf")
		lens_material.emission_energy_multiplier = 1.8 * amount
