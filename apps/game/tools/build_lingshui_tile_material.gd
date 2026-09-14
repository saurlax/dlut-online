extends RefCounted

# Small rectangular facing tiles observed on photo-registered exterior patches.
# One repeat covers 0.4 m, with four columns and eight rows of tiles.
func build(builder, color: String) -> StandardMaterial3D:
	var key := "Photo tile " + color
	if builder.materials.has(key):
		return builder.materials[key]
	var mat: StandardMaterial3D = builder.material(key,Color(color))
	var texture_image := Image.create(256,256,false,Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			var column := x / 64
			var row := y / 32
			var tone := 0.985 + float((column * 7 + row * 11) % 4) * 0.005
			if x % 64 < 2 or y % 32 < 2:
				tone = 0.84
			texture_image.set_pixel(x,y,Color(tone,tone,tone,1.0))
	texture_image.generate_mipmaps()
	mat.albedo_texture = ImageTexture.create_from_image(texture_image)
	mat.uv1_scale = Vector3.ONE * 2.5
	mat.roughness = 0.72
	return mat
