extends SceneTree
## Rebuild existing shared meshes without changing surveyed planting or MultiMesh buffers.
func _initialize() -> void:
	var generator := preload("res://tools/vegetation_meshes.gd").new()
	generator.bark = load(generator.DIRECTORY + "bark.tres")
	generator.leaves = load(generator.DIRECTORY + "leaves.tres")
	var count := 0
	for kind in generator.KINDS:
		for variant in generator.VARIANTS:
			for lod in 2:
				var path: String = generator.DIRECTORY + "%s_%d_%d.res" % [kind, variant, lod]
				if not FileAccess.file_exists(path):
					continue
				assert(ResourceSaver.save(generator.build(kind, variant, lod), path, ResourceSaver.FLAG_COMPRESS) == OK)
				count += 1
	print("VEGETATION MESHES REBUILT: ", count)
	quit()
