extends SceneTree
## Run with a real renderer: --path apps/game --script tests/vegetation.gd
## The headless dummy renderer discards MultiMesh instance transforms.

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	assert(DisplayServer.get_name() != "headless", "Use a real renderer to verify serialized MultiMesh buffers")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/vegetation.json"))
	var scene: Node3D = load("res://assets/campuses/eda/models/vegetation.tscn").instantiate()
	var expected: Dictionary = {}
	for entry: Dictionary in data.instances:
		expected[_position_key(Vector3(entry.position[0], entry.position[1], entry.position[2]))] = entry
	assert(expected.size() == data.instances.size())
	var meshes: Dictionary = {}
	var materials: Dictionary = {}
	var count := 0
	for batch: MultiMeshInstance3D in scene.get_children():
		var multi := batch.multimesh
		var mesh := multi.mesh
		assert(mesh.resource_path.begins_with("res://assets/campuses/eda/models/tree_"))
		if meshes.has(mesh.resource_path):
			assert(mesh == meshes[mesh.resource_path], "Tree meshes must be shared across batches")
		meshes[mesh.resource_path] = mesh
		for surface in mesh.get_surface_count():
			var mat := mesh.surface_get_material(surface)
			if materials.has(surface):
				assert(materials[surface] == mat, "Tree variants must share materials")
			materials[surface] = mat
		assert(multi.buffer.size() == multi.instance_count * 12)
		for index in multi.instance_count:
			var transform := multi.get_instance_transform(index)
			var position := batch.position + transform.origin
			var key := _position_key(position)
			assert(expected.has(key), "Lost, moved or duplicated planting instance")
			var entry: Dictionary = expected[key]
			assert(mesh.resource_path.ends_with("tree_%d.tres" % int(entry.variant)))
			var basis := Basis(Vector3.UP, float(entry.rotation_y)).scaled(Vector3.ONE * float(entry.height) / 10.0)
			assert(transform.basis.is_equal_approx(basis))
			assert(batch.position.x == floorf(position.x / 64.0) * 64.0)
			assert(batch.position.z == floorf(position.z / 64.0) * 64.0)
			assert(multi.custom_aabb.grow(0.001).encloses(transform * mesh.get_aabb()), "Crown clipped by batch bounds")
			expected.erase(key)
			count += 1
	assert(expected.is_empty() and count == data.instances.size())
	assert(meshes.size() == 4 and materials.size() == 2)
	assert(scene.find_children("*", "CollisionObject3D", true, false).is_empty())
	print("PASS: %d preserved instances, %d batches, 4 shared meshes, 2 shared materials, complete bounds" % [count, scene.get_child_count()])
	scene.free()
	quit()

func _position_key(position: Vector3) -> String:
	return "%.3f,%.3f,%.3f" % [position.x, position.y, position.z]
