extends SceneTree
## Rebuild only water and terrain from original data, preserving other models.
const Catalog = preload("res://scripts/shared/campus_catalog.gd")

func _initialize() -> void: rebuild.call_deferred()

func rebuild() -> void:
	for campus: String in Catalog.CAMPUSES:
		var terrain := preload("res://tools/build_terrain.gd").new()
		terrain.load_campus(campus)
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Catalog.CAMPUSES[campus].manifest))
		var water := preload("res://tools/build_water.gd").new()
		var regions := water.regions(manifest, terrain, campus)
		if regions.is_empty(): continue
		var source: Node3D = load(Catalog.CAMPUSES[campus].scene).instantiate()
		var model: Node3D = source.get_node("CampusModel")
		var model_path := model.scene_file_path
		var material: Material = source.get_node("Terrain/Ground").material_override
		terrain.save_terrain(material, campus, regions)
		water.replace_surfaces(model, regions, terrain)
		model.scene_file_path = ""
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK)
		assert(ResourceSaver.save(packed, model_path) == OK)
		print("WATER BUILD PASS: ", campus, " regions=", regions.size())
		source.free()
	quit()
