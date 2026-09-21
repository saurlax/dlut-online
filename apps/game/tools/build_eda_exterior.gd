extends SceneTree
## Photo-bounded road furniture; saved geometry only, no runtime construction.
const OUTPUT := "res://assets/campuses/eda/models/exterior_details.tscn"
var scene := Node3D.new()
var terrain := preload("res://tools/build_terrain.gd").new()
var batches: Dictionary = {}
var materials: Dictionary = {}
var road: Dictionary

func _initialize() -> void:
	build.call_deferred()

func material(key: String, color: Color, metallic := 0.0) -> StandardMaterial3D:
	if materials.has(key): return materials[key]
	var mat := StandardMaterial3D.new()
	mat.resource_name = key
	mat.albedo_color = color
	mat.roughness = 0.8 if metallic == 0.0 else 0.4
	mat.metallic = metallic
	materials[key] = mat
	return mat

func append_mesh(mesh: Mesh, transform: Transform3D, key: String) -> void:
	if not batches.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[key] = st
	batches[key].append_from(mesh, 0, transform)

func tube(a: Vector3, b: Vector3, radius: float, key: String, top_radius := -1.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0 else top_radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12
	mesh.rings = 1
	append_mesh(mesh, Transform3D(Basis(Quaternion(Vector3.UP, (b-a).normalized())), (a+b)*0.5), key)

func box(at: Vector3, size: Vector3, key: String, basis := Basis.IDENTITY) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	append_mesh(mesh, Transform3D(basis, at), key)

func point(index: int) -> Vector2:
	return Vector2(road.points[index][0], road.points[index][1])

func strip(a: Vector2, b: Vector2, width: float, key: String) -> void:
	var side := (b-a).normalized().orthogonal() * width * 0.5
	var vertices := [a-side, a+side, b+side, b-side]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0, 2, 1, 0, 3, 2]:
		var p: Vector2 = vertices[i]
		st.add_vertex(Vector3(p.x, -0.052, p.y))
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	# Intersect with the exact terrain grid, not a separately sampled polyline.
	terrain.fit_road(node)
	append_mesh(node.mesh, Transform3D.IDENTITY, key)
	node.free()

func lamp(at: Vector2, toward: Vector2, height: float) -> void:
	var base := Vector3(at.x, terrain.elevation(at.x, at.y), at.y)
	var dir := Vector3(toward.x, 0, toward.y)
	tube(base, base+Vector3.UP*0.12, 0.16, "Pole", 0.16)
	tube(base+Vector3.UP*0.12, base+Vector3.UP*(height-0.45), 0.065, "Pole", 0.036)
	var previous := base+Vector3.UP*(height-0.45)
	for i in range(1, 9):
		var angle := PI*0.5*float(i)/8.0
		var next := base+Vector3.UP*(height-0.45+sin(angle)*0.45)+dir*(1.0-cos(angle))*0.45
		tube(previous, next, 0.035, "Pole")
		previous = next
	tube(previous, previous+dir*0.4, 0.032, "Pole")
	var basis := Basis(Vector3.UP, atan2(-dir.z, dir.x))
	var head := previous+dir*0.55-Vector3.UP*0.04
	box(head, Vector3(0.65, 0.12, 0.25), "Housing", basis)
	box(head-Vector3.UP*0.063, Vector3(0.48, 0.012, 0.18), "Lens", basis)
	var light := SpotLight3D.new()
	light.name = "StreetLight%d" % scene.get_child_count()
	light.position = head-Vector3.UP*0.085
	light.basis = Basis(Quaternion(Vector3.FORWARD, (Vector3.DOWN+dir*0.2).normalized()))
	light.light_color = Color("fff0cf")
	light.light_energy = 0.0
	light.visible = false
	light.spot_range = 16.0
	light.spot_angle = 62.0
	light.spot_attenuation = 1.0
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 100.0
	light.distance_fade_shadow = 40.0
	light.distance_fade_length = 25.0
	scene.add_child(light)
	light.owner = scene
	for x in [-0.085, 0.085]:
		for z in [-0.085, 0.085]:
			tube(base+Vector3(x,0.12,z),base+Vector3(x,0.145,z),0.012,"Housing")
	# Explicit simple collision, never the small bolts or lamp head.
	var body := StaticBody3D.new()
	body.name = "LampPole%d" % scene.get_child_count()
	body.position = base+Vector3.UP*height*0.5
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.085
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	scene.add_child(body)
	body.owner = scene
	collision.owner = scene

func build() -> void:
	scene.name = "EdaExteriorDetails"
	root.add_child(scene)
	terrain.load_campus("eda")
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/mapping/exterior-details.json"))
	var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads
	material("WhitePaint", Color("dedfd4"))
	material("YellowPaint", Color("cfa24c"))
	material("Pole", Color("c4cfca"), 0.45)
	material("Housing", Color("687d7a"), 0.6)
	material("Lens", Color("e7e6cf"))
	var distance := 0.0
	var lamp_count := 0
	for section: Dictionary in profile.sections:
		var matches := roads.filter(func(r): return int(r.osm_way_id) == int(section.osm_way_id) and int(r.part) == int(section.part))
		assert(matches.size() == 1 and int(matches[0].osm_version) == int(section.osm_version))
		road = matches[0]
		distance += road_details(section, float(profile.lamp_height_m))
		lamp_count += section.lamps.size()
	# The paired OSM carriageway lines enclose one photographed paved approach.
	road = {"points": profile.approach_markings.points}
	distance += road_details(profile.approach_markings, float(profile.lamp_height_m))
	for key: String in batches:
		var st: SurfaceTool = batches[key]
		st.index()
		st.set_material(materials[key])
		var node := MeshInstance3D.new()
		node.name = key
		node.mesh = st.commit()
		node.set_meta("source_profile", "references/eda/mapping/exterior-details.json")
		node.set_meta("walk_collision", false)
		scene.add_child(node)
		node.owner = scene
	var packed := PackedScene.new()
	# Assign after generation: the controller requires the saved Lens mesh in _ready.
	scene.set_script(preload("res://scripts/client/street_lighting.gd"))
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, OUTPUT) == OK)
	print("EDA EXTERIOR SAVED: ", lamp_count, " lamps, ", snappedf(distance,0.1), " m of road markings")
	quit()

func road_details(section: Dictionary, lamp_height: float) -> float:
	var distance := 0.0
	for i in range(int(section.from_vertex), int(section.to_vertex)):
		var a := point(i)
		var b := point(i+1)
		var length := a.distance_to(b)
		var side := (b-a).normalized().orthogonal()
		# Edge lines follow photo-supported asphalt only, ending before junctions.
		for sign_side in [-1.0, 1.0]:
			var offset: float = section.get("edge_offset_m", 3.08)
			strip(a+side*sign_side*offset, b+side*sign_side*offset, 0.10, "WhitePaint")
		# Carry dash phase across OSM vertices; no restart at each segment.
		var at := 0.0
		while at < length-0.001:
			var phase := fposmod(distance+at, 6.0)
			var remaining := (3.0-phase) if phase < 3.0 else (6.0-phase)
			var end := minf(length, at+maxf(remaining,0.001))
			if phase < 3.0: strip(a.lerp(b,at/length),a.lerp(b,end/length),0.12,"YellowPaint")
			at = end
		distance += length
	for entry: Dictionary in section.lamps:
		var a := point(int(entry.segment))
		var b := point(int(entry.segment)+1)
		var side := (b-a).normalized().orthogonal()*float(entry.side)
		lamp(a.lerp(b,float(entry.fraction))+side*4.4,-side,lamp_height)
	return distance
