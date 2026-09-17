extends SceneTree
## Bounded outdoor photo details, separate from buildings and vegetation.
const Roads = preload("res://tools/build_roads.gd")
const Ribbons = preload("res://scripts/shared/road_geometry.gd")
const Terrain = preload("res://tools/build_terrain.gd")
var profile: Dictionary
var terrain := Terrain.new()
var scene := Node3D.new()
var right: Vector2
var forward: Vector2
var origin: Vector2
var stair_bottoms: Dictionary = {}

func _initialize() -> void:
	build.call_deferred()

func world(p: Vector2) -> Vector2:
	return origin + right * p.x + forward * p.y

func ground(p: Vector2) -> float:
	var at := world(p)
	return terrain.elevation(at.x, at.y) + 0.14

func height(p: Vector2) -> float:
	if p.y <= 11.0:
		return lerpf(profile.plaza_north_y, profile.plaza_south_y, clampf(p.y / 11.0, 0, 1))
	var middle_weight := clampf(1.0 - maxf(0.0, absf(p.x) - 2.5) / 12.5, 0, 1)
	var lift: float = (profile.plaza_south_y - ground(Vector2(0,11))) * clampf((float(profile.end_depth) - p.y) / (float(profile.end_depth) - 11.0), 0, 1) * middle_weight
	var y := ground(p) + maxf(0.0, lift)
	for stair in profile.stairs:
		if absf(p.x - float(stair.side)) > float(stair.width) * 0.5 + 0.001:
			continue
		var end: float = stair.start_depth + stair.length
		if p.y < end:
			return lerpf(profile.plaza_south_y, stair_bottoms[stair.id], (p.y - stair.start_depth) / stair.length)
		if p.y < end + 3.0:
			y = lerpf(stair_bottoms[stair.id], y, (p.y - end) / 3.0)
	return y

func rectangle(x: float, z: float, width: float, depth: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x,z), Vector2(x+width,z), Vector2(x+width,z+depth), Vector2(x,z+depth)])

func vertex(st: SurfaceTool, p: Vector2) -> void:
	var at := world(p)
	st.add_vertex(Vector3(at.x, height(p), at.y))

func subdivide(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2) -> void:
	var lengths := [a.distance_squared_to(b), b.distance_squared_to(c), c.distance_squared_to(a)]
	var longest: float = lengths.max()
	if longest > 0.64:
		if longest == lengths[0]:
			var mid := (a+b)*0.5
			subdivide(st,a,mid,c)
			subdivide(st,mid,b,c)
		elif longest == lengths[1]:
			var mid := (b+c)*0.5
			subdivide(st,a,b,mid)
			subdivide(st,a,mid,c)
		else:
			var mid := (c+a)*0.5
			subdivide(st,a,b,mid)
			subdivide(st,mid,b,c)
		return
	for p in [a,c,b]:
		vertex(st,p)

func surface(rings: Array[PackedVector2Array], cutouts: Array[PackedVector2Array], material: Material, title: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for quad in Roads.new().tessellate(rings,cutouts):
		for indices in [[0,1,2],[0,2,3]]:
			var a := quad[indices[0]]
			var b := quad[indices[1]]
			var c := quad[indices[2]]
			if absf((b-a).cross(c-a)) > 0.00001:
				subdivide(st,a,b,c)
	st.index()
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = st.commit()
	node.material_override = material
	scene.add_child(node)
	node.create_trimesh_collision()
	for body in node.get_children():
		for shape in body.get_children():
			shape.shape.backface_collision = true

func skirts(rings: Array[PackedVector2Array]) -> void:
	# Close raised paving edges down to terrain, including the first stair riser.
	# Internal skirt faces remain buried beneath the union's continuous surface.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in rings:
		for i in ring.size():
			var a := ring[i]
			var b := ring[(i+1)%ring.size()]
			var count := maxi(1,ceili(a.distance_to(b)/0.5))
			for j in count:
				var p := a.lerp(b,float(j)/count)
				var q := a.lerp(b,float(j+1)/count)
				var wp := world(p)
				var wq := world(q)
				var vertices := [Vector3(wp.x,height(p),wp.y),Vector3(wq.x,height(q),wq.y),Vector3(wq.x,ground(q)-0.24,wq.y),Vector3(wp.x,ground(p)-0.24,wp.y)]
				for k in [0,1,2,0,2,3]:
					st.add_vertex(vertices[k])
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "PavingSides"
	node.mesh = st.commit()
	node.material_override = preload("res://assets/roads/stone_paving.tres")
	scene.add_child(node)
	node.create_trimesh_collision()

func box(at: Vector3, size: Vector3, material: Material, title: String) -> void:
	var shape := BoxMesh.new()
	shape.size = size
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = shape
	node.material_override = material
	node.position = at
	node.rotation.y = -deg_to_rad(float(profile.rotation_degrees))
	scene.add_child(node)

func stairs(stair: Dictionary) -> void:
	var top: float = profile.plaza_south_y
	var bottom: float = stair_bottoms[stair.id]
	var rise: float = (top-bottom)/int(stair.steps)
	assert(rise > 0.05 and rise < 0.22, "Photo stair estimate conflicts with current terrain")
	var tread: float = stair.length / int(stair.steps)
	var stone := preload("res://assets/roads/stone_paving.tres")
	var edging := StandardMaterial3D.new()
	edging.albedo_color = Color("c8c7bf")
	edging.roughness = 0.9
	for i in int(stair.steps):
		var elevation := top - (i+1)*rise
		var center := world(Vector2(stair.side, stair.start_depth + (i+0.5)*tread))
		var base := bottom - 0.7
		box(Vector3(center.x,(elevation+base)*0.5,center.y),Vector3(stair.width,elevation-base,tread),stone,stair.id+"_Tread"+str(i))
		var front := world(Vector2(stair.side, stair.start_depth+(i+1)*tread-0.025))
		box(Vector3(front.x,elevation+0.006,front.y),Vector3(stair.width,0.012,0.05),edging,stair.id+"_Nosing"+str(i))
	# Smooth, bounded collision ramp avoids requiring jumps on each riser.
	# The visible treads remain separate; maximum foot discrepancy is one riser.
	var hull := PackedVector3Array()
	for side in [-0.5,0.5]:
		for depth in [0.0,1.0]:
			var p := world(Vector2(stair.side+stair.width*side,stair.start_depth+stair.length*depth))
			hull.append(Vector3(p.x,lerpf(top,bottom,depth),p.y))
			hull.append(Vector3(p.x,bottom-0.7,p.y))
	var body := StaticBody3D.new()
	body.name = stair.id+"_Collision"
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = hull
	collision.shape = shape
	body.add_child(collision)
	scene.add_child(body)
	body.set_meta("max_visual_riser_m",rise)

func own(node: Node) -> void:
	for child in node.get_children():
		child.owner = scene
		own(child)

func curved_paths(paths: Array) -> Array:
	var result: Array = []
	for path in paths:
		var points: Array = path.points
		var smooth: Array = [points[0]]
		for i in range(1,points.size()-1):
			var a := Vector2(points[i-1][0],points[i-1][1])
			var b := Vector2(points[i][0],points[i][1])
			var c := Vector2(points[i+1][0],points[i+1][1])
			var entry := b.lerp(a,0.4)
			var exit := b.lerp(c,0.4)
			for sample in 9:
				var t := float(sample)/8.0
				var p := entry.lerp(b,t).lerp(b.lerp(exit,t),t)
				smooth.append([p.x,p.y])
		smooth.append(points[-1])
		result.append({"width":path.width,"points":smooth})
	return result

func build() -> void:
	profile = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/lingshui/mapping/road-details.json"))
	terrain.load_campus("lingshui")
	origin = Vector2(profile.origin_xz[0],profile.origin_xz[1])
	var angle := deg_to_rad(float(profile.rotation_degrees))
	right = Vector2(cos(angle),sin(angle))
	forward = Vector2(-sin(angle),cos(angle))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/campus.json"))
	if profile.has("osm_registration"):
		var anchor: Dictionary = profile.osm_registration
		assert(float(anchor.local_endpoint[0]) == 0.0 and is_equal_approx(float(anchor.local_endpoint[1]),float(profile.end_depth)), "Photo garden endpoint changed; recheck road anchor")
		var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/osm_roads.json")).roads
		var matches: Array = roads.filter(func(road): return int(road.osm_way_id) == int(anchor.osm_way_id) and int(road.part) == int(anchor.part))
		assert(matches.size() == 1, "Photo garden road anchor missing or ambiguous")
		var road: Dictionary = matches[0]
		assert(int(road.osm_version) == int(anchor.osm_version), "Photo garden road changed; recheck registration")
		var index := int(anchor.segment)
		assert(index >= 0 and index+1 < road.points.size() and float(anchor.fraction) >= 0.0 and float(anchor.fraction) <= 1.0)
		var a := Vector2(road.points[index][0],road.points[index][1])
		var b := Vector2(road.points[index+1][0],road.points[index+1][1])
		origin = a.lerp(b,float(anchor.fraction))-right*float(anchor.local_endpoint[0])-forward*float(anchor.local_endpoint[1])
	else:
		push_error("Photo road details require independent OSM registration")
		quit(1)
		return
	scene.name = "PhotoRoadDetails"
	root.add_child(scene)
	scene.set_meta("source", "references/lingshui/mapping/road-details.json")
	var paving: Array[PackedVector2Array] = [rectangle(-20.5,0,41,11), rectangle(-2.5,11,5,float(profile.end_depth)-11)]
	for stair in profile.stairs:
		var end: float = stair.start_depth + stair.length
		var bottom := -INF
		for side in [-0.5,0.0,0.5]:
			bottom = maxf(bottom,ground(Vector2(stair.side+stair.width*side,end)))
		stair_bottoms[stair.id] = bottom + 0.025
		paving.append(rectangle(stair.side-stair.width*0.5,end,stair.width,float(profile.end_depth)-end))
	var paths := curved_paths(profile.red_paths)
	var brick := Ribbons.polygons(paths)
	paving.append_array(Ribbons.polygons(paths,0.10))
	surface(paving,brick,preload("res://assets/roads/stone_paving.tres"),"StoneWalks")
	surface(brick,[],preload("res://assets/roads/red_brick_path.tres"),"BrickWalks")
	skirts(paving)
	for stair in profile.stairs:
		stairs(stair)
	own(scene)
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed,"res://assets/campuses/lingshui/models/road_details.tscn") == OK)
	print("PHOTO ROAD DETAILS PASS: bounded Lingxi outdoor paving and two stair flights ",stair_bottoms)
	quit()
