extends RefCounted

static func _collider(mesh: MeshInstance3D) -> void:
	var extras: Variant = mesh.get_meta("extras", {})
	if extras is Dictionary and extras.has("dlut_visible"):
		mesh.visible = bool(extras["dlut_visible"])
	mesh.create_trimesh_collision()
	for child in mesh.get_children():
		if child is StaticBody3D:
			for shape in child.get_children():
				if shape is CollisionShape3D and shape.shape is ConcavePolygonShape3D:
					shape.shape.backface_collision = true

static func build_feature(group: Node3D) -> void:
	for node in group.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var extras: Variant = mesh.get_meta("extras", {})
		if extras is Dictionary and extras.has("dlut_visible"):
			mesh.visible = bool(extras["dlut_visible"])
		if _flag(mesh, "walk_collision") or mesh.name in ["Building", "Roof", "HillBase", "SchematicTerrain", "GateFootprint", "Gate"]:
			_collider(mesh)

static func _flag(node: Node, key: StringName, fallback := false) -> bool:
	if node.has_meta(key):
		return bool(node.get_meta(key))
	var extras: Variant = node.get_meta("extras", {})
	if extras is Dictionary:
		return bool(extras.get(str(key), fallback))
	return fallback

static func build(root: Node3D, model: Node3D, manifest: Dictionary, campus_id: String) -> void:
	var base := model.get_node_or_null("CampusBase")
	if base != null:
		_collider(base)
	for child in model.get_children():
		if child is MeshInstance3D and _flag(child, "walk_collision"):
			_collider(child)
		elif child is Node3D and _flag(child, "static_collision_group"):
			for mesh in child.get_children():
				if mesh is MeshInstance3D and _flag(mesh, "walk_collision"):
					_collider(mesh)
	for feature in manifest.features:
		if campus_id not in ["lingshui", "eda"] and feature.kind not in ["building", "hill", "gate", "sports"]:
			continue
		var node_name: String = "Feature_"+feature.id
		if feature.has("part"):
			node_name += "_"+str(int(feature.part))
		var group := model.get_node_or_null(node_name) as Node3D
		if group != null and not group.has_meta("building_asset"):
			build_feature(group)
	var boundaries := [
		[Vector3(-635,80,55),Vector3(2,160,930)],
		[Vector3(635,80,55),Vector3(2,160,930)],
		[Vector3(0,80,-405),Vector3(1280,160,2)],
		[Vector3(0,80,515),Vector3(1280,160,2)],
	]
	if manifest.has("bounds"):
		var b: Array = manifest.bounds
		boundaries = [
			[Vector3(b[0],80,b[1]+b[3]/2.0),Vector3(2,160,b[3])],
			[Vector3(b[0]+b[2],80,b[1]+b[3]/2.0),Vector3(2,160,b[3])],
			[Vector3(b[0]+b[2]/2.0,80,b[1]),Vector3(b[2],160,2)],
			[Vector3(b[0]+b[2]/2.0,80,b[1]+b[3]),Vector3(b[2],160,2)],
		]
	elif campus_id != "eda":
		boundaries = [
			[Vector3(-89,20,0),Vector3(2,40,180)],
			[Vector3(89,20,0),Vector3(2,40,180)],
			[Vector3(0,20,-89),Vector3(180,40,2)],
			[Vector3(0,20,89),Vector3(180,40,2)],
		]
	# Terrain may lie below the local vertical origin. Keep boundary walls below
	# its lowest point instead of leaving an escape gap under a wall starting at 0.
	var boundary_bottom := 0.0
	var boundary_top := 160.0
	var terrain := root.get_node_or_null("Terrain/Ground") as MeshInstance3D
	if terrain != null:
		var terrain_bounds: AABB = terrain.get_parent().transform * terrain.transform * terrain.get_aabb()
		boundary_bottom = minf(boundary_bottom,terrain_bounds.position.y-10.0)
		boundary_top = maxf(boundary_top,terrain_bounds.end.y+10.0)
	for entry in boundaries:
		var body := StaticBody3D.new()
		body.name = "CampusBoundary"
		body.position = entry[0]
		body.position.y = (boundary_bottom+boundary_top)*0.5
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = entry[1]
		box.size.y = boundary_top-boundary_bottom
		shape.shape = box
		body.add_child(shape)
		root.add_child(body)
