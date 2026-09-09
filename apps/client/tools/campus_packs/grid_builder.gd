@tool
extends RefCounted

const Grid = preload("res://tools/campus_packs/grid_mesh.gd")
const Catalog = preload("res://scripts/campus_catalog.gd")
var materials := {}
var shared_files := {}
var chunks := {}
var cells := {}
var output := ""
var staging := ""
var campus_id := ""

func owners(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.scene_file_path = ""
		child.owner = scene
		owners(child, scene)

func shared_material(material: Material) -> Material:
	if material == null: return null
	var key := material.get_instance_id()
	if materials.has(key): return materials[key]
	var copy: Material = material.duplicate(true)
	var path := staging.path_join("material_%d.tres" % materials.size())
	assert(ResourceSaver.save(copy, path, ResourceSaver.FLAG_CHANGE_PATH) == OK)
	materials[key] = copy
	shared_files[path] = path
	return copy

func prepare_mesh(node: MeshInstance3D) -> void:
	node.mesh = node.mesh.duplicate()
	if node.material_override != null: node.material_override = shared_material(node.material_override)
	for i in node.mesh.get_surface_count():
		if node.mesh is ArrayMesh:
			node.mesh.surface_set_material(i, shared_material(node.mesh.surface_get_material(i)))
		elif node.mesh is PrimitiveMesh:
			node.mesh.material = shared_material(node.mesh.material)
		if node.get_surface_override_material(i) != null:
			node.set_surface_override_material(i, shared_material(node.get_surface_override_material(i)))

func world_transform(node: Node3D, model: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != model and parent is Node3D:
		result = parent.transform * result
		parent = parent.get_parent()
	return result

func collision_mesh(mesh: MeshInstance3D) -> bool:
	return mesh.name == "CampusBase" or mesh.get_meta("walk_collision", false) or mesh.name in ["Building", "Roof", "HillBase", "SchematicTerrain", "GateFootprint", "Gate"]

func register_cells(key: String, bounds: AABB) -> void:
	var low := Grid.cell(bounds.position)
	var high := Grid.cell(bounds.end - Vector3(0.0001,0,0.0001))
	for x in range(low.x, high.x+1):
		for z in range(low.y, high.y+1):
			var cell_id := "%d,%d" % [x,z]
			if not cells.has(cell_id): cells[cell_id] = []
			if not key in cells[cell_id]: cells[cell_id].append(key)

func save_scene(scene: Node, path: String) -> void:
	owners(scene, scene)
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS) == OK)

func pack_files(key: String, files: Dictionary) -> Dictionary:
	var temp := output.path_join("." + campus_id + "-" + key + ".pck")
	var pack := PCKPacker.new()
	assert(pack.pck_start(temp) == OK)
	for path: String in files: assert(pack.add_file(path, files[path]) == OK)
	assert(pack.flush() == OK)
	var sha := FileAccess.get_sha256(temp)
	var name := campus_id + "-" + key + "-" + sha + ".pck"
	assert(DirAccess.rename_absolute(temp, output.path_join(name)) == OK)
	var file := FileAccess.open(output.path_join(name), FileAccess.READ)
	return {"url":"campuses/" + name, "sha256":sha, "bytes":file.get_length()}

func add_chunk(key: String, node: Node3D, bounds: AABB) -> void:
	if node.get_child_count() == 0:
		node.free()
		return
	var path := staging.path_join(key + ".scn")
	save_scene(node, path)
	var entry := pack_files(key, {path:path})
	entry.scene = path
	entry.bounds = [bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z]
	chunks[key] = entry
	register_cells(key,bounds)
	node.free()

func build(id: String, destination: String) -> Dictionary:
	campus_id = id
	output = destination
	staging = "res://.godot/campus_grid/" + id
	DirAccess.make_dir_recursive_absolute(staging)
	var scene: Node3D = load(Catalog.CAMPUSES[id].scene).instantiate()
	var model: Node3D = scene.get_node("CampusModel")
	var model_bounds := AABB()
	var first := true
	var grid_nodes := {}
	var buildings := {}
	var entry: Dictionary = Catalog.CAMPUSES[id]
	if entry.has("manifest"):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entry.manifest))
		for f: Dictionary in data.features:
			if f.kind == "building":
				var name: String = "Feature_" + f.id
				if f.has("part"): name += "_" + str(int(f.part))
				buildings[name] = true
	# Keep the original collision and distant building shell; stream decoration.
	for child in model.get_children():
		if child is MeshInstance3D:
			prepare_mesh(child)
			var bounds: AABB = child.transform * child.mesh.get_aabb()
			model_bounds = bounds if first else model_bounds.merge(bounds)
			first = false
			if not collision_mesh(child): split_mesh(child, model, grid_nodes)
		else:
			var detail := Node3D.new()
			detail.name = child.name
			for meta: StringName in child.get_meta_list(): detail.set_meta(meta,child.get_meta(meta))
			var bounds := AABB()
			var first_detail := true
			for mesh in child.get_children():
				if not mesh is MeshInstance3D: continue
				prepare_mesh(mesh)
				var transform := world_transform(mesh,model)
				var box: AABB = transform * mesh.mesh.get_aabb()
				model_bounds = box if first else model_bounds.merge(box)
				first = false
				if collision_mesh(mesh): continue
				if buildings.has(str(child.name)):
					bounds = box if first_detail else bounds.merge(box)
					first_detail = false
					mesh.owner = null
					child.remove_child(mesh)
					detail.add_child(mesh)
					mesh.transform = transform
				else:
					split_mesh(mesh,model,grid_nodes)
			add_chunk(str(child.name),detail,bounds)
	for coordinate: Vector2i in grid_nodes:
		var key := "grid_%d_%d" % [coordinate.x,coordinate.y]
		add_chunk(key,grid_nodes[coordinate],AABB(Vector3(coordinate.x*100,0,coordinate.y*100),Vector3(100,0,100)))
	var grid := {"cell_size":100, "cells":cells, "chunks":chunks,
		"bounds":[model_bounds.position.x,model_bounds.position.z,model_bounds.size.x,model_bounds.size.z]}
	var grid_path := "res://grid_" + id + ".json"
	var local_grid := staging.path_join("grid.json")
	var file := FileAccess.open(local_grid,FileAccess.WRITE)
	file.store_string(JSON.stringify(grid))
	file.close()
	shared_files[grid_path] = local_grid
	var scene_path := staging.path_join("bootstrap.scn")
	save_scene(scene,scene_path)
	shared_files[scene_path] = scene_path
	var remap := staging.path_join("bootstrap.remap")
	file = FileAccess.open(remap,FileAccess.WRITE)
	file.store_string('[remap]\npath="%s"\n' % scene_path)
	file.close()
	shared_files[entry.scene + ".remap"] = remap
	for key in ["manifest","roads"]:
		if entry.has(key): shared_files[entry[key]] = entry[key]
	print("GRID %s: %d occupied cells, %d packs" % [id,cells.size(),chunks.size()])
	scene.free()
	return {"files":shared_files, "pack":pack_files("bootstrap",shared_files), "grid":grid}

func split_mesh(mesh: MeshInstance3D, model: Node3D, grid_nodes: Dictionary) -> void:
	var transform := world_transform(mesh,model)
	for surface in mesh.mesh.get_surface_count():
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var buckets := Grid.split_surface(arrays,transform)
		for coordinate: Vector2i in buckets:
			if not grid_nodes.has(coordinate):
				grid_nodes[coordinate] = Node3D.new()
				grid_nodes[coordinate].name = "Grid_%d_%d" % [coordinate.x,coordinate.y]
			var output_mesh := ArrayMesh.new()
			output_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,buckets[coordinate].arrays())
			output_mesh.surface_set_material(0,mesh.get_active_material(surface))
			var node := MeshInstance3D.new()
			node.name = mesh.name
			node.mesh = output_mesh
			node.cast_shadow = mesh.cast_shadow
			for meta: StringName in mesh.get_parent().get_meta_list(): node.set_meta(meta,mesh.get_parent().get_meta(meta))
			for meta: StringName in mesh.get_meta_list(): node.set_meta(meta,mesh.get_meta(meta))
			grid_nodes[coordinate].add_child(node)
	mesh.get_parent().remove_child(mesh)
	mesh.free()
