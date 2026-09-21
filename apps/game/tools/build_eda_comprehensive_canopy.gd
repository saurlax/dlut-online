extends RefCounted

func at(facade, x: float, y: float, offset: float) -> Vector3:
	var p: Vector2 = facade.origin + facade.axis * x + facade.out * offset
	return Vector3(p.x, y, p.y)

func build(facade, center: float, settings: Dictionary) -> void:
	var glazing: StandardMaterial3D = facade.host.material("EDA comprehensive canopy glazing", Color("8ba69e"))
	glazing.albedo_texture = null
	glazing.metallic = 0.35
	glazing.roughness = 0.23
	glazing.cull_mode = BaseMaterial3D.CULL_BACK
	var frame: StandardMaterial3D = facade.host.material("EDA comprehensive canopy frame", Color("aebeb8"))
	frame.albedo_texture = null
	frame.metallic = 0.5
	frame.roughness = 0.4
	frame.cull_mode = BaseMaterial3D.CULL_BACK
	var width := float(settings.width)
	var rear := float(settings.rear_offset)
	var front := float(settings.front_offset)
	var y := float(settings.height)
	var depth := front - rear
	# The shallow closed glazing has collision; fine bars and ties do not.
	facade.panel(center, y, width, 0.08, depth, (rear + front) * 0.5, glazing, true)
	for offset in [rear, (rear + front) * 0.5, front]:
		facade.panel(center, y + 0.01, width + 0.08, 0.10, 0.06, offset, frame)
	for i in 9:
		facade.panel(center - width * 0.5 + width * i / 8.0, y + 0.01, 0.06, 0.10, depth, (rear + front) * 0.5, frame)
	for fraction in settings.tie_fractions:
		var x := center + (float(fraction) - 0.5) * width
		var upper := at(facade, x, float(settings.tie_upper_y), rear + 0.09)
		var lower := at(facade, x, y + 0.05, front)
		var tube := CylinderMesh.new()
		tube.top_radius = 0.028
		tube.bottom_radius = 0.028
		tube.height = upper.distance_to(lower)
		tube.radial_segments = 12
		tube.rings = 1
		var node: MeshInstance3D = facade.host.mesh_node(facade.group, tube, frame, "ComprehensiveCanopyTie")
		node.position = (upper + lower) * 0.5
		node.basis = Basis(Quaternion(Vector3.UP, (upper - lower).normalized()))
		node.set_meta("walk_collision", false)
		facade.panel(x, float(settings.tie_upper_y), 0.14, 0.14, 0.10, rear + 0.04, frame)
		facade.panel(x, y + 0.05, 0.14, 0.12, 0.14, front, frame)
