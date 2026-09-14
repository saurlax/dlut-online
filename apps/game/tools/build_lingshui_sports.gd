extends RefCounted

# Internal dimensions are photo estimates in references/lingshui/sports.json.
# Every surface is clipped to the official footprint; no standard track length is implied.
func build(builder, group: Node3D, outline: PackedVector2Array, profile: Dictionary) -> void:
	var center := Vector2(profile.center[0], profile.center[1])
	var angle := deg_to_rad(float(profile.rotation_degrees))
	var radius: float = profile.inner_radius
	var half: float = profile.straight_half
	var width: float = profile.lane_width
	var lanes: int = profile.lanes
	var chalk: Material = builder.material("Court markings", Color("e3e3d8"))
	var track: Material = builder.material("Track " + profile.track_color, Color(profile.track_color))
	var apron: Material = builder.material("Apron " + profile.apron_color, Color(profile.apron_color))
	var turf: Material = builder.material("Lingshui field grass", Color("65824d"))
	# Broad apron retains the irregular source boundary, unlike the fitted inner oval.
	builder.polygon(group, outline, 0.065, apron, "Apron")
	surface(builder, group, oval(radius + lanes * width, half), center, angle, outline, 0.08, track)
	surface(builder, group, oval(radius, half), center, angle, outline, 0.09, apron)
	var pitch_x: float = profile.pitch_width / 2.0
	var pitch_z: float = profile.pitch_length / 2.0
	surface(builder, group, rectangle(-pitch_x, -pitch_z, pitch_x, pitch_z), center, angle, outline, 0.10, turf)
	for lane in range(lanes + 1):
		var path := oval(radius + lane * width, half)
		stroke(builder, group, path, true, center, angle, outline, chalk)
	# Football markings are visible in the source overview; sizes are fitted, not surveyed.
	stroke(builder, group, rectangle(-pitch_x, -pitch_z, pitch_x, pitch_z), true, center, angle, outline, chalk)
	stroke(builder, group, PackedVector2Array([Vector2(-pitch_x, 0), Vector2(pitch_x, 0)]), false, center, angle, outline, chalk)
	var circle := PackedVector2Array()
	for i in 96:
		circle.append(Vector2(cos(TAU * i / 96.0), sin(TAU * i / 96.0)) * pitch_x * 0.28)
	stroke(builder, group, circle, true, center, angle, outline, chalk)
	for side in [-1.0, 1.0]:
		for dimensions in [Vector2(pitch_x * 0.61, pitch_z * 0.29), Vector2(pitch_x * 0.28, pitch_z * 0.10)]:
			stroke(builder, group, PackedVector2Array([
				Vector2(-dimensions.x, side * pitch_z), Vector2(-dimensions.x, side * (pitch_z - dimensions.y)),
				Vector2(dimensions.x, side * (pitch_z - dimensions.y)), Vector2(dimensions.x, side * pitch_z)
			]), false, center, angle, outline, chalk)
	if profile.west_stand:
		west_stand(builder, group)

func oval(radius: float, half: float) -> PackedVector2Array:
	var ring := PackedVector2Array()
	for end in 2:
		for i in 65:
			var angle := PI * (i / 64.0 + end)
			ring.append(Vector2(cos(angle) * radius, sin(angle) * radius + (half if end == 0 else -half)))
	return ring

func rectangle(x0: float, z0: float, x1: float, z1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0,z0), Vector2(x1,z0), Vector2(x1,z1), Vector2(x0,z1)])

func surface(builder, group: Node3D, ring: PackedVector2Array, center: Vector2, angle: float, outline: PackedVector2Array, height: float, mat: Material) -> void:
	var world := PackedVector2Array()
	for p in ring:
		world.append(center + p.rotated(angle))
	for piece in Geometry2D.intersect_polygons(world, outline):
		if piece.size() >= 3 and not Geometry2D.triangulate_polygon(piece).is_empty():
			builder.polygon(group, piece, height, mat, "FieldSurface")

func stroke(builder, group: Node3D, path: PackedVector2Array, closed: bool, center: Vector2, angle: float, outline: PackedVector2Array, mat: Material) -> void:
	for i in range(path.size() if closed else path.size() - 1):
		var a := path[i]
		var b := path[(i+1) % path.size()]
		var delta := (b-a).normalized()
		var normal := Vector2(-delta.y, delta.x) * 0.055
		surface(builder, group, PackedVector2Array([a-normal,b-normal,b+normal,a+normal]), center, angle, outline, 0.125, mat)

func west_stand(builder, group: Node3D) -> void:
	# 78473-0/2: yellow stepped west seating and a modest central covered booth.
	# Outside stairs and access tunnels have no plan evidence and are not modeled.
	var concrete: Material = builder.material("Stadium concrete", Color("c5c7be"))
	var seat: Material = builder.material("Stadium yellow seating", Color("bca653"))
	var metal: Material = builder.material("Stadium canopy", Color("6b8586"))
	for row in 12:
		var x := 232.5 - row * 0.95
		var height := 0.38 * (row + 1)
		var step: MeshInstance3D = builder.box(group, Vector3(x,height/2.0,201), Vector3(0.95,height,82), concrete, "StandStructure")
		step.set_meta("walk_collision", true)
		# Keep visible breaks between seating banks; no decorative seat colliders.
		for bank in 6:
			builder.box(group, Vector3(x,height+0.12,166.5+bank*13.7), Vector3(0.62,0.24,11.7), seat, "Seating")
	var booth: MeshInstance3D = builder.box(group, Vector3(223.1,5.3,201), Vector3(5.4,2.1,12), concrete, "ClosedStandBooth")
	booth.set_meta("walk_collision", true)
	builder.box(group, Vector3(225.85,5.5,201), Vector3(0.08,0.85,10.5), builder.material("Window glass",Color("354951")), "BoothWindows")
	var canopy: MeshInstance3D = builder.box(group, Vector3(225,7.8,201), Vector3(10,0.22,17), metal, "StandCanopy")
	canopy.set_meta("walk_collision", true)
	for z in [194.0, 208.0]:
		var support: MeshInstance3D = builder.box(group, Vector3(221.8,6.2,z), Vector3(0.18,3.0,0.18), metal, "CanopySupport")
		support.set_meta("walk_collision", true)
