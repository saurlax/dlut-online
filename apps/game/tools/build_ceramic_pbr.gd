extends SceneTree
## Offline data maps for the existing 4 x 8 ceramic swatch, not photo-derived depth.
## Dimensions and finish are visual estimates; see references/shared/buildings/textures.json.
const SIZE := 1024
const REPEAT_METRES := 0.4
const DIRECTORY := "res://assets/textures/buildings/"

func tile_face(uv: Vector2) -> float:
	var cell := Vector2(fposmod(uv.x * 4.0, 1.0), fposmod(uv.y * 8.0, 1.0))
	var edge := Vector2(minf(cell.x, 1.0 - cell.x) * 0.1, minf(cell.y, 1.0 - cell.y) * 0.05)
	return smoothstep(0.0011, 0.0020, minf(edge.x, edge.y))

func _initialize() -> void:
	var normal := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var roughness := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	var step := 1.0 / SIZE
	for y in SIZE:
		for x in SIZE:
			var uv := Vector2(x + 0.5, y + 0.5) / SIZE
			# A shallow, rounded 0.35 mm transition; colour grain is not used as height.
			var dx := (tile_face(uv + Vector2(step, 0)) - tile_face(uv - Vector2(step, 0))) * 0.00035 / (2.0 * step * REPEAT_METRES)
			var dy := (tile_face(uv + Vector2(0, step)) - tile_face(uv - Vector2(0, step))) * 0.00035 / (2.0 * step * REPEAT_METRES)
			var n := Vector3(-dx, dy, 1.0).normalized()
			normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
			var value := lerpf(0.90, 0.48, tile_face(uv))
			roughness.set_pixel(x, y, Color(value, value, value))
	assert(normal.save_png(DIRECTORY + "small_ceramic_tiles_normal.png") == OK)
	assert(roughness.save_png(DIRECTORY + "small_ceramic_tiles_roughness.png") == OK)
	print("CERAMIC PBR: generated seamless OpenGL normal and roughness data maps")
	quit()
