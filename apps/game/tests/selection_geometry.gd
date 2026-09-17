extends SceneTree
## Empty source references must stay empty in saved models and collision worlds.
const Catalog = preload("res://scripts/shared/campus_catalog.gd")
const Collision = preload("res://scripts/shared/campus_collision.gd")

func _initialize() -> void:
	for campus: String in Catalog.CAMPUSES:
		var entry: Dictionary = Catalog.CAMPUSES[campus]
		var source: Node3D = load(entry.scene).instantiate()
		var model: Node3D = source.get_node("CampusModel")
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entry.manifest))
		var withheld := 0
		for feature: Dictionary in manifest.features:
			if not feature.has("withheld_geometry"):
				continue
			var suffix := "_" + str(int(feature.part)) if feature.has("part") else ""
			var node: Node3D = model.get_node("Feature_" + feature.id + suffix)
			assert(node.get_child_count() == 0, "Withheld source still renders: " + feature.id)
			withheld += 1
		Collision.build(source, model, manifest, campus)
		var actual: Array[String] = []
		collect(source, Transform3D.IDENTITY, actual)
		var saved: Node3D = load("res://scenes/server/" + campus + ".scn").instantiate()
		var expected: Array[String] = []
		collect(saved, Transform3D.IDENTITY, expected)
		actual.sort()
		expected.sort()
		assert(actual == expected, "Saved collision differs from current source: " + campus)
		print("SELECTION GEOMETRY PASS: ", campus, ", ", withheld, " empty references, ", actual.size(), " identical saved/client shapes")
		saved.free()
		source.free()
	quit()

func collect(node: Node, parent: Transform3D, output: Array[String]) -> void:
	var transform := parent
	if node is Node3D:
		transform = parent * node.transform
	if node is CollisionShape3D:
		var shape: Shape3D = node.shape
		var vertices: PackedVector3Array = shape.get_debug_mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(var_to_bytes([transform, shape.get_class(), vertices]))
		output.append(digest.finish().hex_encode())
	for child in node.get_children():
		collect(child, transform, output)
