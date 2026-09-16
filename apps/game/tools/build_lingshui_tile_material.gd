extends RefCounted

# ImageGen surface approximation for photo-registered exterior patches only.
# One repeat covers 0.4 m, with four columns and eight rows of tiles.
# Dimensions are inherited estimates, not measured ceramic sizes.
const ALBEDO_PATH := "res://assets/campuses/lingshui/textures/small_ceramic_tiles_albedo.png"

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
	mat.roughness = 0.72
	return mat

# Use facade-local metres so rotated walls retain tile proportions, and pieces
# cut around windows share the same grid even after static mesh merging.
func map_piece(node: MeshInstance3D, middle: Vector2) -> void:
	var arrays: Array = node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv := PackedVector2Array()
	for vertex in vertices:
		uv.append(Vector2(vertex.x + middle.x, -(vertex.y + middle.y)))
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	node.mesh = mesh
