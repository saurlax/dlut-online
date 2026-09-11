extends RefCounted
## Offline vegetation generation. Campus geometry and collision stay separate.

const DATA_PATH := "res://assets/campuses/eda/data/vegetation.json"
const MODEL_DIRECTORY := "res://assets/campuses/eda/models/"
const CELL_SIZE := 64.0
const VARIANT_COUNT := 4
const REFERENCE_HEIGHT := 10.0

func build(builder: SceneTree) -> void:
	for key in ["Bark", "Leaves"]:
		var mat: StandardMaterial3D = builder.material(key, Color("635b4c") if key == "Bark" else Color.WHITE)
		mat.vertex_color_use_as_albedo = key == "Leaves"
		var path := MODEL_DIRECTORY + "tree_%s.tres" % key.to_lower()
		assert(ResourceSaver.save(mat, path) == OK)
		builder.materials[key] = load(path)
	var meshes: Array[ArrayMesh] = []
	for variant in VARIANT_COUNT:
		var mesh := _tree_mesh(builder, variant)
		var path := MODEL_DIRECTORY + "tree_%d.tres" % variant
		assert(ResourceSaver.save(mesh, path) == OK)
		# Load the saved resource so the scene uses an external shared mesh.
		meshes.append(load(path))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	assert(data.schema_version == 1)
	var buckets: Dictionary = {}
	for entry: Dictionary in data.instances:
		var position := Vector3(entry.position[0], entry.position[1], entry.position[2])
		var variant := int(entry.variant)
		assert(variant >= 0 and variant < VARIANT_COUNT and float(entry.height) > 0.0)
		var cell := Vector2i(floori(position.x / CELL_SIZE), floori(position.z / CELL_SIZE))
		var key := Vector3i(cell.x, cell.y, variant)
		if not buckets.has(key):
			buckets[key] = []
		var origin := Vector3(cell.x * CELL_SIZE, 0, cell.y * CELL_SIZE)
		var basis := Basis(Vector3.UP, float(entry.rotation_y)).scaled(Vector3.ONE * float(entry.height) / REFERENCE_HEIGHT)
		buckets[key].append(Transform3D(basis, position - origin))
	# Write the standard TSCN buffer explicitly: the headless dummy renderer does
	# not retain MultiMesh buffers for ResourceSaver to read back.
	var resources: Array[String] = ["[gd_scene load_steps=%d format=3]" % (1 + VARIANT_COUNT + buckets.size())]
	for variant in VARIANT_COUNT:
		resources.append('[ext_resource type="ArrayMesh" path="%stree_%d.tres" id="tree_%d"]' % [MODEL_DIRECTORY, variant, variant])
	var nodes: Array[String] = ['[node name="Vegetation" type="Node3D"]']
	for key: Vector3i in buckets:
		var transforms: Array = buckets[key]
		var mesh: ArrayMesh = meshes[key.z]
		var bounds := AABB()
		var buffer := PackedFloat32Array()
		for index in transforms.size():
			var transform: Transform3D = transforms[index]
			var tree_bounds: AABB = transform * mesh.get_aabb()
			bounds = tree_bounds if index == 0 else bounds.merge(tree_bounds)
			var basis := transform.basis
			var origin := transform.origin
			buffer.append_array(PackedFloat32Array([
				basis.x.x, basis.y.x, basis.z.x, origin.x,
				basis.x.y, basis.y.y, basis.z.y, origin.y,
				basis.x.z, basis.y.z, basis.z.z, origin.z,
			]))
		var name := ("Cell_%d_%d_Tree_%d" % [key.x, key.y, key.z]).replace("-", "n")
		resources.append('[sub_resource type="MultiMesh" id="%s"]\ntransform_format = 1\ncustom_aabb = %s\ninstance_count = %d\nmesh = ExtResource("tree_%d")\nbuffer = %s' % [name, var_to_str(bounds), transforms.size(), key.z, var_to_str(buffer)])
		var position := Vector3(key.x * CELL_SIZE, 0, key.y * CELL_SIZE)
		nodes.append('[node name="%s" type="MultiMeshInstance3D" parent="."]\nposition = %s\nmultimesh = SubResource("%s")' % [name, var_to_str(position), name])
	var file := FileAccess.open(MODEL_DIRECTORY + "vegetation.tscn", FileAccess.WRITE)
	assert(file != null)
	file.store_string("\n\n".join(resources) + "\n\n" + "\n\n".join(nodes) + "\n")
	print("VEGETATION: %d trees, %d spatial batches, %d shared meshes" % [data.instances.size(), buckets.size(), meshes.size()])

func _tree_mesh(builder: SceneTree, variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260909 + variant
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.10
	trunk.bottom_radius = REFERENCE_HEIGHT * 0.027
	trunk.height = REFERENCE_HEIGHT * 0.68
	trunk.radial_segments = 8
	trunk.rings = 0
	bark.append_from(trunk, 0, Transform3D(Basis.IDENTITY, Vector3(0, REFERENCE_HEIGHT * 0.34, 0)))
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for branch_index in 7:
		var angle := rng.randf() * TAU
		var start := Vector3(0, REFERENCE_HEIGHT * 0.38 + branch_index * 0.28, 0)
		var tip := start + Vector3(cos(angle) * REFERENCE_HEIGHT * 0.23, REFERENCE_HEIGHT * 0.26, sin(angle) * REFERENCE_HEIGHT * 0.23)
		var branch := CylinderMesh.new()
		branch.bottom_radius = 0.08
		branch.top_radius = 0.025
		branch.height = start.distance_to(tip)
		branch.radial_segments = 5
		branch.rings = 0
		bark.append_from(branch, 0, Transform3D(Basis(Quaternion(Vector3.UP, (tip - start).normalized())), (start + tip) * 0.5))
		for leaf_index in 100:
			var offset := Vector3(rng.randfn(), rng.randfn() * 0.65, rng.randfn()) * REFERENCE_HEIGHT * 0.105
			var center := tip + offset
			var normal := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.25, 1), rng.randf_range(-1, 1)).normalized()
			var side := normal.cross(Vector3.FORWARD).normalized() * rng.randf_range(0.12, 0.24)
			var along := normal.cross(side).normalized() * rng.randf_range(0.18, 0.35)
			leaves.set_color(Color("69724b").lerp(Color("343e29"), rng.randf()))
			builder.triangle(leaves, center - side, center + along, center + side)
			builder.triangle(leaves, center - side, center + side, center - along)
	leaves.generate_normals()
	bark.index()
	leaves.index()
	var leaf_material: StandardMaterial3D = builder.material("Leaves", Color.WHITE)
	leaf_material.vertex_color_use_as_albedo = true
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, bark.commit_to_arrays(), [], {}, builder.material("Bark", Color("635b4c")))
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, leaves.commit_to_arrays(), [], {}, leaf_material)
	# Native mesh LOD preserves shared geometry; disconnected leaf cards may simplify less.
	importer.generate_lods(60.0, 25.0, [])
	return importer.get_mesh()
