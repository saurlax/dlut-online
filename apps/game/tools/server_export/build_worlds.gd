extends SceneTree

const Catalog = preload("res://scripts/shared/campus_catalog.gd")
const Collision = preload("res://scripts/shared/campus_collision.gd")

func _initialize() -> void:
	for id: String in Catalog.CAMPUSES:
		var source: Node3D = load(Catalog.CAMPUSES[id].scene).instantiate()
		var model: Node3D = source.get_node("CampusModel")
		var entry: Dictionary = Catalog.CAMPUSES[id]
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entry.manifest)) if entry.has("manifest") else {"features":[]}
		Collision.build(source, model, manifest, id)
		var world := Node3D.new()
		world.name = id
		world.set_meta("spawn", source.spawn_position)
		copy_bodies(source, world, Transform3D.IDENTITY)
		var packed := PackedScene.new()
		assert(packed.pack(world) == OK)
		assert(ResourceSaver.save(packed, "res://scenes/server/" + id + ".scn", ResourceSaver.FLAG_COMPRESS) == OK)
		print("Collision world ", id, ": ", world.get_child_count(), " bodies")
		world.free()
		source.free()
	quit()

func copy_bodies(node: Node, world: Node3D, parent_transform: Transform3D) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform = parent_transform * node.transform
	if node is StaticBody3D:
		var body := StaticBody3D.new()
		body.name = "Body%d" % world.get_child_count()
		body.transform = transform
		world.add_child(body)
		body.owner = world
		for child in node.get_children():
			if child is CollisionShape3D:
				var shape := CollisionShape3D.new()
				shape.transform = child.transform
				shape.shape = child.shape
				body.add_child(shape)
				shape.owner = world
		return
	for child in node.get_children():
		copy_bodies(child, world, transform)
