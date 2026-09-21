extends RefCounted

# ImageGen surface approximation for photo-registered exterior patches only.
# One repeat covers 0.4 m, with four columns and eight rows of tiles.
# Dimensions are inherited estimates, not measured ceramic sizes.
const ALBEDO_PATH := "res://assets/textures/buildings/small_ceramic_tiles_albedo.png"

func build(builder, color: String) -> StandardMaterial3D:
	var key := "Photo tile " + color
	if builder.materials.has(key):
		return builder.materials[key]
	var mat: StandardMaterial3D = builder.material(key,Color(color))
	mat.albedo_texture = load(ALBEDO_PATH)
	mat.uv1_triplanar = false
	mat.uv1_world_triplanar = false
	mat.uv1_scale = Vector3.ONE * 2.5
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/textures/buildings/small_ceramic_tiles_normal.png")
	mat.normal_scale = 1.0
	mat.roughness = 1.0
	mat.roughness_texture = load("res://assets/textures/buildings/small_ceramic_tiles_roughness.png")
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	return mat

# Use facade-local metres so rotated walls retain tile proportions, and pieces
# cut around windows share the same grid even after static mesh merging.
func map_piece(node: MeshInstance3D, middle: Vector2) -> void:
	preload("res://tools/build_surface_materials.gd").new().map_box(node,middle)
