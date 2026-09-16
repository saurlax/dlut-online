extends RefCounted
## Shared offline surface palette. Source/license/scale: references/shared/buildings/textures.json.

const DIRECTORY := "res://assets/textures/buildings/"
const FINISHES := {
	"window_frame": {"repeat": Vector2.ONE, "mean": Color.WHITE, "roughness": 0.45, "metallic": 0.15},
	"plaster": {"albedo": "beige_wall_001_diff_1k.jpg", "normal": "beige_wall_001_nor_gl_1k.jpg", "rough": "beige_wall_001_rough_1k.jpg", "repeat": Vector2(3.0, 3.0), "mean": Color(0.60, 0.54, 0.46), "roughness": 0.9},
	"mineral": {"albedo": "mineral_render_albedo.png", "repeat": Vector2(0.5, 0.5), "mean": Color(0.73, 0.71, 0.67), "roughness": 0.86},
	"brick": {"albedo": "red_brick_diff_1k.jpg", "normal": "red_brick_nor_gl_1k.jpg", "rough": "red_brick_rough_1k.jpg", "repeat": Vector2(1.4, 1.4), "mean": Color(0.52, 0.34, 0.24), "roughness": 0.88},
	"ceramic": {"albedo": "small_ceramic_tiles_albedo.png", "repeat": Vector2(0.4, 0.4), "mean": Color(0.87, 0.86, 0.83), "roughness": 0.72},
	"square_ceramic": {"albedo": "small_ceramic_tiles_albedo.png", "repeat": Vector2(0.4, 0.8), "mean": Color(0.87, 0.86, 0.83), "roughness": 0.72},
	"terracotta": {"albedo": "terracotta_albedo.png", "repeat": Vector2(1.0, 1.0), "mean": Color(0.73, 0.46, 0.33), "roughness": 0.82},
}

func material(builder, finish: String, color: Color, triplanar := false) -> StandardMaterial3D:
	assert(FINISHES.has(finish), "Unknown photo surface " + finish)
	var key := "Surface " + finish + " " + color.to_html() + (" spatial" if triplanar else " planar")
	if builder.materials.has(key):
		return builder.materials[key]
	var settings: Dictionary = FINISHES[finish]
	var mat := StandardMaterial3D.new()
	mat.resource_name = key
	# Preserve the previously photo-matched average colour, rather than multiply
	# two already coloured surfaces. Scale remains an estimate, never surveying.
	var mean: Color = settings.mean
	mat.albedo_color = Color(color.r / mean.r, color.g / mean.g, color.b / mean.b)
	if settings.has("albedo"):
		mat.albedo_texture = load(DIRECTORY + settings.albedo)
	mat.roughness = settings.roughness
	mat.metallic = settings.get("metallic", 0.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var repeat: Vector2 = settings.repeat
	mat.uv1_scale = Vector3(1.0 / repeat.x, 1.0 / repeat.y, 1.0 / repeat.x)
	mat.uv1_triplanar = triplanar
	mat.uv1_world_triplanar = triplanar
	if settings.has("rough"):
		mat.roughness_texture = load(DIRECTORY + settings.rough)
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	# Overlay meshes have explicit UVs and tangents. Existing detail meshes use
	# only colour/roughness, since their tangent layouts are not all known.
	if settings.has("normal") and not triplanar:
		mat.normal_enabled = true
		mat.normal_texture = load(DIRECTORY + settings.normal)
		mat.normal_scale = 0.25
	builder.materials[key] = mat
	return mat

func map_box(node: MeshInstance3D, middle: Vector2) -> void:
	var arrays: Array = node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv := PackedVector2Array()
	for vertex in vertices:
		uv.append(Vector2(vertex.x + middle.x, -(vertex.y + middle.y)))
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	node.mesh = mesh
