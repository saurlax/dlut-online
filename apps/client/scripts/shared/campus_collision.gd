extends RefCounted

static func _collider(mesh: MeshInstance3D) -> void:
	mesh.create_trimesh_collision()
	for child in mesh.get_children():
		if child is StaticBody3D:
			for shape in child.get_children():
				if shape is CollisionShape3D and shape.shape is ConcavePolygonShape3D:
					shape.shape.backface_collision = true

static func build(root: Node3D, model: Node3D, manifest: Dictionary, campus_id: String) -> void:
	_collider(model.get_node("CampusBase"))
	for child in model.get_children():
		if child is MeshInstance3D and child.get_meta("walk_collision",false):
			_collider(child)
	for feature in manifest.features:
		if feature.kind not in ["building","hill","gate"]:
			continue
		var node_name: String = "Feature_"+feature.id
		if feature.has("part"):
			node_name += "_"+str(int(feature.part))
		var group := model.get_node(node_name)
		for child in group.get_children():
			if child is MeshInstance3D and (child.get_meta("walk_collision",false) or child.name in ["Building", "Roof", "HillBase", "SchematicTerrain", "GateFootprint", "Gate"]):
				_collider(child)
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
	for entry in boundaries:
		var body := StaticBody3D.new()
		body.name = "CampusBoundary"
		body.position = entry[0]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = entry[1]
		shape.shape = box
		body.add_child(shape)
		root.add_child(body)
