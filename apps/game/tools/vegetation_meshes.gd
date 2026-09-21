extends RefCounted
## Botanical silhouettes, not surveyed specimens. All dimensions are metres.
## Leaf outlines are actual folded geometry, so no rectangular alpha cards exist.

const DIRECTORY := "res://assets/vegetation/"
const KINDS := ["broadleaf", "ginkgo", "maple", "willow", "pine", "cedar", "cypress", "cherry", "shrub", "hedge", "grass", "violet", "calibrachoa", "juniper", "magnolia"]
const VARIANTS := 3
var rng := RandomNumberGenerator.new()
var wood: SurfaceTool
var foliage: SurfaceTool
var bark: StandardMaterial3D
var leaves: ShaderMaterial
var detail := 0
var species := ""
var dense_crown := false
var detailed_willow := false
var flowering_cherry := false
var fine_hedge := false

func materials() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	bark = StandardMaterial3D.new()
	bark.resource_name = "Shared bark, generic furrow detail"
	bark.albedo_texture = load(DIRECTORY + "bark_brown_02_diff_1k.jpg")
	bark.normal_enabled = true
	bark.normal_texture = load(DIRECTORY + "bark_brown_02_nor_gl_1k.jpg")
	bark.normal_scale = 0.45
	bark.roughness = 0.94
	bark.vertex_color_use_as_albedo = true
	bark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	assert(ResourceSaver.save(bark, DIRECTORY + "bark.tres") == OK)
	bark = load(DIRECTORY + "bark.tres")
	leaves = ShaderMaterial.new()
	leaves.shader = load(DIRECTORY + "leaves.gdshader")
	assert(ResourceSaver.save(leaves, DIRECTORY + "leaves.tres") == OK)
	leaves = load(DIRECTORY + "leaves.tres")

func build(kind: String, variant: int, lod: int) -> ArrayMesh:
	if flowering_cherry and kind == "cherry":
		return preload("res://tools/eda_cherry_meshes.gd").new().build(self,variant,lod)
	species = kind
	detail = lod
	rng.seed = 16092026 + KINDS.find(kind) * 149 + variant * 7919
	wood = SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	foliage = SurfaceTool.new()
	foliage.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind == "grass":
		grass()
	elif kind in ["violet", "calibrachoa"]:
		flowers(kind)
	elif kind in ["shrub", "hedge"]:
		bush(kind)
	elif kind == "juniper":
		juniper()
	elif kind in ["pine", "cedar", "cypress"]:
		conifer(kind, variant)
	else:
		deciduous(kind, variant)
	var mesh := ArrayMesh.new()
	if kind != "grass":
		wood.index()
		wood.generate_tangents()
		wood.set_material(bark)
		wood.commit(mesh, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	foliage.index()
	foliage.generate_tangents()
	foliage.set_material(leaves)
	foliage.commit(mesh, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	mesh.set_meta("kind", kind)
	mesh.set_meta("variant", variant)
	mesh.set_meta("lod", lod)
	mesh.set_meta("leaf_geometry", "folded non-rectangular silhouettes")
	return mesh

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, uv_a := Vector2.ZERO, uv_b := Vector2.UP, uv_c := Vector2.ONE) -> void:
	var normal := (c - a).cross(b - a).normalized()
	st.set_color(color)
	st.set_normal(normal)
	st.set_uv(uv_a)
	st.add_vertex(a)
	st.set_uv(uv_b)
	st.add_vertex(b)
	st.set_uv(uv_c)
	st.add_vertex(c)

func twig(a: Vector3, b: Vector3, r0: float, r1: float, upright_rings := false) -> void:
	var axis := (b - a).normalized()
	var frame := Basis.IDENTITY if upright_rings else Basis(Quaternion(Vector3.UP, axis))
	# Keep the whole trunk on one ring resolution, including its thin upper tip.
	var sides := (12 if detail==0 else 7) if upright_rings else (7 if r0>0.065 else 4)
	var length := a.distance_to(b)
	var v0 := a.y if upright_rings else 0.0
	var v1 := b.y if upright_rings else length
	for i in sides:
		var t0 := TAU * i / sides
		var t1 := TAU * (i + 1) / sides
		var d0 := frame * Vector3(cos(t0), 0, sin(t0))
		var d1 := frame * Vector3(cos(t1), 0, sin(t1))
		var c := Color(0.7, 0.68, 0.6, 1)
		var circumference := 1.4 if upright_rings else maxf(0.2,r0*TAU)
		var u0 := float(i) / sides * circumference
		var u1 := float(i + 1) / sides * circumference
		# Clockwise outside faces: the former order pointed both winding and normals inward.
		triangle(wood, a + d0*r0, b + d1*r1, b + d0*r1, c, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))
		triangle(wood, a + d0*r0, a + d1*r0, b + d1*r1, c, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1))

func leaf(center: Vector3, direction: Vector3, length: float, width: float, color: Color, shape := "oval") -> void:
	var along := direction.normalized()
	var side := along.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = along.cross(Vector3.RIGHT)
	side = side.normalized().rotated(along, sin(center.dot(Vector3(2.7,4.1,3.3))) * 0.9)
	var normal := side.cross(along).normalized()
	var outline: Array[Vector2]
	if shape == "petal":
		outline = [Vector2(0,-0.5),Vector2(-0.25,-0.35),Vector2(-0.46,-0.1),Vector2(-0.5,0.18),Vector2(-0.4,0.4),Vector2(-0.2,0.5),Vector2(0,0.53),Vector2(0.2,0.5),Vector2(0.4,0.4),Vector2(0.5,0.18),Vector2(0.46,-0.1),Vector2(0.25,-0.35)]
	elif shape == "fan":
		outline = [Vector2(0,-0.5),Vector2(-0.48,0.05),Vector2(-0.5,0.32),Vector2(-0.24,0.5),Vector2(0,0.39),Vector2(0.24,0.5),Vector2(0.5,0.32),Vector2(0.48,0.05)]
	elif shape == "lobed":
		outline = [Vector2(0,-0.5),Vector2(-0.33,-0.25),Vector2(-0.26,-0.05),Vector2(-0.5,0.18),Vector2(-0.19,0.15),Vector2(0,0.5),Vector2(0.19,0.15),Vector2(0.5,0.18),Vector2(0.26,-0.05),Vector2(0.33,-0.25)]
	elif shape == "hedge":
		outline = [Vector2(0,-0.5),Vector2(-0.35,-0.35),Vector2(-0.5,0),Vector2(-0.35,0.35),Vector2(0,0.5),Vector2(0.35,0.35),Vector2(0.5,0),Vector2(0.35,-0.35)]
	else:
		outline = [Vector2(0,-0.5),Vector2(-0.42,-0.2),Vector2(-0.5,0.12),Vector2(0,0.5),Vector2(0.5,0.12),Vector2(0.42,-0.2)]
	var ridge := center + normal * width * (0.07 if shape=="hedge" else 0.13)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		triangle(foliage, ridge, center + side*a.x*width + along*a.y*length, center + side*b.x*width + along*b.y*length, color, Vector2(0.5,0.5), a + Vector2(0.5,0.5), b + Vector2(0.5,0.5))

func foliage_color() -> Color:
	var color := Color("43602e").lerp(Color("738744"), rng.randf())
	if species in ["pine", "cypress", "juniper"]:
		color = Color("294c32").lerp(Color("526e3c"), rng.randf())
		if species == "juniper":
			color = Color("45582c").lerp(Color("6b773a"), rng.randf())
	elif species == "cedar":
		color = Color("385f52").lerp(Color("6c8765"), rng.randf())
	elif species == "willow":
		color = Color("526d34").lerp(Color("8b9a50"), rng.randf())
	color.a = 1.0
	return color

func spray(at: Vector3, direction: Vector3, size: float, count: int, shape := "oval") -> void:
	var axis := direction.normalized()
	var side := axis.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.1:
		side = Vector3.RIGHT
	var end := at + axis * size
	if detail == 0:
		twig(at, end, 0.006, 0.001)
	for i in count:
		# Consume the same random sequence for near/far crown correspondence.
		var t := rng.randf_range(0.08, 1.0)
		var sign_side := -1.0 if i % 2 == 0 else 1.0
		var dir := (axis*0.6 + side*sign_side + Vector3.UP*rng.randf_range(-0.6,0.9)).normalized()
		var c := foliage_color()
		var scale_leaf := rng.randf_range(0.8,1.25)
		if (detail == 1 and i % (3 if detailed_willow else 4 if dense_crown else 6) != 0) or (detail == 0 and i % (1 if detailed_willow else 2) != 0):
			continue
		var length := 0.28 * scale_leaf * ((1.55 if dense_crown else 1.8) if detail == 1 else 1.2)
		if detailed_willow: length = 0.18 * scale_leaf * (1.6 if detail == 1 else 1.0)
		var width := length * 0.63
		if species == "willow":
			width *= 0.28
		if shape == "fan":
			width = length * 1.15
		leaf(at + axis * t * size + dir * length * 0.38, dir, length, width, c, shape)

func willow_strand(at: Vector3, outward: Vector3, length: float) -> void:
	# A short outward shoulder turns into a near-vertical pendant shoot.
	var reach := rng.randf_range(0.22, 0.48)
	var bend := outward.rotated(Vector3.UP, rng.randf_range(-0.35, 0.35))
	var previous := at
	var segments := 4 if detail == 0 else 2
	for segment in segments:
		var t := float(segment + 1) / segments
		var point := at + bend * reach * sin(t * PI * 0.5) + Vector3.DOWN * length * t * t
		twig(previous, point, lerpf(0.009, 0.001, float(segment) / segments), lerpf(0.009, 0.001, t))
		previous = point
	for i in 32:
		# Keep RNG consumption identical between LODs, including omitted leaves.
		var t := (float(i) + rng.randf_range(0.1, 0.9)) / 32.0
		var side := bend.rotated(Vector3.UP, (-1.0 if i % 2 else 1.0) * rng.randf_range(0.7, 1.4))
		var direction := (Vector3.DOWN * rng.randf_range(0.55, 1.0) + side * 0.7).normalized()
		var leaf_length := rng.randf_range(0.15, 0.23)
		var color := foliage_color()
		if detail == 1 and i % 3 != 0:
			continue
		leaf_length *= 1.6 if detail == 1 else 1.0
		var point := at + bend * reach * sin(t * PI * 0.5) + Vector3.DOWN * length * t * t
		leaf(point + direction * leaf_length * 0.42, direction, leaf_length, leaf_length * 0.15, color)

func willow_pruning_head(base: Vector3, end: Vector3, radius: float) -> void:
	var axis := (end - base).normalized()
	var frame := Basis(Quaternion(Vector3.UP, axis))
	var sides := 10 if detail == 0 else 6
	var stations := [0.0, 0.38, 0.82, 1.0]
	var radii := [0.85, 1.17, 1.08, 0.8]
	var length := base.distance_to(end)
	var color := Color(0.7, 0.68, 0.6, 1)
	for ring in stations.size() - 1:
		for side in sides:
			var u0 := float(side) / sides
			var u1 := float(side + 1) / sides
			var d0 := frame * Vector3(cos(u0 * TAU), 0, sin(u0 * TAU))
			var d1 := frame * Vector3(cos(u1 * TAU), 0, sin(u1 * TAU))
			var a := base.lerp(end, stations[ring])
			var b := base.lerp(end, stations[ring + 1])
			var r0: float = radius * radii[ring]
			var r1: float = radius * radii[ring + 1]
			var v0: float = stations[ring] * length
			var v1: float = stations[ring + 1] * length
			triangle(wood, a+d0*r0, b+d1*r1, b+d0*r1, color, Vector2(u0,v0), Vector2(u1,v1), Vector2(u0,v1))
			triangle(wood, a+d0*r0, a+d1*r0, b+d1*r1, color, Vector2(u0,v0), Vector2(u1,v0), Vector2(u1,v1))
	# Closed old cut, with a darker centre, sharing the bark material and draw call.
	for side in sides:
		var a := frame * Vector3(cos(TAU * side / sides), 0, sin(TAU * side / sides)) * radius * 0.8
		var b := frame * Vector3(cos(TAU * (side+1) / sides), 0, sin(TAU * (side+1) / sides)) * radius * 0.8
		triangle(wood, end-axis*0.012, end+a, end+b, Color(0.48,0.45,0.39,1), Vector2(0.5,0.5), Vector2(0.5+a.x,0.5+a.z), Vector2(0.5+b.x,0.5+b.z))

func willow_crown(variant: int) -> void:
	var height := 9.0 + variant * 0.55
	var spread := 3.0 + variant * 0.22
	var lean := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
	var previous := Vector3.ZERO
	for i in 4:
		var t := float(i + 1) / 4.0
		var point := Vector3.UP * height * 0.4 * t + lean * t
		twig(previous, point, lerpf(0.25, 0.12, float(i) / 4.0), lerpf(0.25, 0.12, t), true)
		previous = point
	# Upright scaffold shoots spread from the low fork; no exposed central spike.
	for i in 12:
		var angle := float(i) * 2.399963 + rng.randf_range(-0.25, 0.25)
		var outward := Vector3(cos(angle), 0, sin(angle))
		var start := Vector3.UP * height * rng.randf_range(0.32, 0.4) + lean
		var radius := spread * rng.randf_range(0.65, 1.1)
		var shoulder := start + outward * radius * 0.45 + Vector3.UP * height * 0.24
		var tip := outward * radius + lean + Vector3.UP * height * rng.randf_range(0.85, 1.0)
		# A short old scaffold carries a swollen pruning head and finer regrowth.
		# These proportions describe the tree type, not individually surveyed cuts.
		var fork := start.lerp(shoulder, 0.23)
		var regrowth := start.lerp(shoulder, 0.36)
		twig(start, fork, 0.13, 0.115)
		twig(fork, regrowth, 0.115, 0.052)
		twig(regrowth, shoulder, 0.052, 0.037)
		if i % 3 == 0:
			willow_pruning_head(fork, fork + outward * 0.25 + Vector3.UP * 0.19, 0.12)
		twig(shoulder, tip, 0.037, 0.003)
		for j in 8:
			var t := 0.1 + float(j) * 0.125
			var attach := shoulder.lerp(tip, t)
			var side := outward.rotated(Vector3.UP, (-1.0 if j % 2 else 1.0) * rng.randf_range(0.5, 1.3))
			var end := attach + side * rng.randf_range(0.4, 0.85) + Vector3.UP * 0.12
			twig(attach, end, 0.012, 0.003)
			for strand in 4:
				willow_strand(attach.lerp(end, 0.1 + float(strand) * 0.3), side, rng.randf_range(1.2, 2.6))

func deciduous(kind: String, variant: int) -> void:
	if detailed_willow:
		willow_crown(variant)
		return
	var height := 9.0 + variant * 0.55
	var spread := 3.0 + variant * 0.22
	if kind == "cherry":
		height = 4.8 + variant * 0.3
		spread = 2.45
	if kind == "magnolia":
		height = 6.0 + variant * 0.3
		spread = 1.8
	if kind == "ginkgo":
		height = 10.5 + variant * 0.4
		spread = 2.6
	var lean := Vector3(rng.randf_range(-0.28,0.28),0,rng.randf_range(-0.25,0.25))
	var last := Vector3.ZERO
	for i in 7:
		var t := float(i+1)/7
		var p := Vector3(0, height*t,0) + lean*t*t + Vector3(sin(t*5)*0.09,0,cos(t*6)*0.08)
		twig(last,p,lerpf(0.22,0.015,float(i)/7),lerpf(0.22,0.015,t),true)
		last = p
	for i in 16:
		var t := float(i)/16
		var angle := i*2.399963 + rng.randf_range(-0.35,0.35)
		var radius := spread * sin((t*0.78+0.16)*PI) * rng.randf_range(0.83,1.15)
		var a := Vector3(0,height*(0.32+t*0.52),0) + lean*t
		var outward := Vector3(cos(angle),0,sin(angle))
		var b := a + outward * radius * 0.55 + Vector3.UP*height*0.12
		var end := a + outward*radius + Vector3.UP*height*(0.19 if kind != "willow" else 0.1)
		twig(a,b,0.075*(1-t*0.65),0.037)
		twig(b,end,0.037,0.009)
		for j in 7:
			var f := 0.22 + float(j)/9
			var attach := b.lerp(end,f)
			var side := outward.rotated(Vector3.UP, (-1.0 if j%2 else 1.0)*rng.randf_range(0.45,1.3))
			var tip := attach + side*rng.randf_range(0.45,1.1) + Vector3.UP*rng.randf_range(0.15,0.7)
			if kind == "willow":
				tip.y -= rng.randf_range(0.9,2.0)
			twig(attach,tip,0.015,0.003)
			if kind == "magnolia":
				if detail == 0 or (i % 2 == 0 and j % 2 == 0):
					for k in (3 if detail == 0 else 1):
						magnolia_flower(attach.lerp(tip,0.4+float(k)*0.28),rng.randf_range(0.18,0.24)*(1.0 if detail == 0 else 1.65))
				continue
			for k in 5:
				var leaf_axis := (side + Vector3(rng.randf_range(-0.9,0.9),rng.randf_range(-0.3,0.9),rng.randf_range(-0.9,0.9))).normalized()
				if kind == "willow":
					leaf_axis = (Vector3.DOWN + side * 0.3).normalized()
				var pos := attach.lerp(tip,0.25+float(k)*0.18)
				spray(pos,leaf_axis,rng.randf_range(0.45,0.85),14,"fan" if kind == "ginkgo" else ("lobed" if kind == "maple" else "oval"))

func needle_spray(center: Vector3, axis: Vector3, size: float) -> void:
	var side := axis.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var count := 15 if species == "juniper" else 9
	var half_width := 0.007 if species == "juniper" else 0.025
	var fold := 0.007 if species == "juniper" else 0.03
	for i in count:
		var t := float(i)/count
		var at := center + axis*t*size
		var c := foliage_color()
		if detail == 1 and i%3 != 0:
			continue
		var width := size*(0.28*(1-t)+0.03) * (1.6 if detail == 1 else 1.0)
		for sign_side: float in [-1.0,1.0]:
			var tip := at + side*sign_side*width + axis*size*0.25
			triangle(foliage,at-side*half_width,tip,at+side*half_width+Vector3.UP*fold,c,Vector2(0,0),Vector2(0.5,1),Vector2(1,0))

func conifer(kind: String, variant: int) -> void:
	var h := 8.0 + variant*0.65
	var width := 2.9
	if kind == "cypress":
		h = 5.5 + variant*0.35
		width = 0.95
	var bend := Vector3(0.12*variant,0,-0.09*variant)
	for i in 8:
		var t := float(i)/8
		var u := float(i+1)/8
		twig(Vector3.UP*h*t+bend*t*t,Vector3.UP*h*u+bend*u*u,lerpf(0.18,0.008,t),lerpf(0.18,0.008,u),true)
	for i in 32:
		var t := float(i)/32
		var a := Vector3.UP*h*(0.13+t*0.82)
		var angle := i*2.399963+rng.randf_range(-0.25,0.25)
		var dir := Vector3(cos(angle),0,sin(angle))
		var reach := width*pow(1-t,0.65)*rng.randf_range(0.75,1.16)
		if kind == "pine":
			a.y = h*(0.37+t*0.57)
			reach = width*sin((t*0.65+0.2)*PI)*rng.randf_range(0.7,1.1)
		var tip := a + dir*reach + Vector3.UP*(reach*0.14 if kind != "cypress" else reach*1.0)
		twig(a,tip,0.036*(1-t)+0.01,0.004)
		for j in 9:
			var attach := a.lerp(tip,0.3+float(j)*0.077)
			var sign_side := -1.0 if j%2 else 1.0
			var lateral := dir.rotated(Vector3.UP,sign_side*0.95)
			var end := attach + lateral*reach*0.42 + Vector3.UP*rng.randf_range(-0.08,0.22)
			if kind == "cypress":
				end.y += 0.5
			twig(attach,end,0.009,0.002)
			for k in 4:
				var at := attach.lerp(end,float(k)/4)
				var axis := (lateral+Vector3(rng.randf_range(-0.6,0.6),rng.randf_range(-0.2,0.6),rng.randf_range(-0.6,0.6))).normalized()
				needle_spray(at,axis,0.50 if kind != "cypress" else 0.40)

func juniper() -> void:
	# Prostrate woody stems carry upright fans instead of a miniature tree crown.
	for stem in 12:
		var angle := float(stem) * 2.399963 + rng.randf_range(-0.2, 0.2)
		var direction := Vector3(cos(angle), 0, sin(angle))
		var reach := rng.randf_range(0.55, 0.85)
		var base := direction * 0.08
		var end := direction * reach + Vector3.UP * rng.randf_range(0.15, 0.3)
		twig(base, end, 0.018, 0.002)
		for j in 7:
			var attach := base.lerp(end, 0.15 + float(j) * 0.12)
			var side := direction.rotated(Vector3.UP, (-1.0 if j % 2 else 1.0) * 0.85)
			var axis := (side * 0.7 + Vector3.UP * rng.randf_range(0.6, 1.0)).normalized()
			var length := rng.randf_range(0.22, 0.4)
			if detail == 0:
				twig(attach, attach + axis * length, 0.004, 0.001)
			for k in 3:
				var shoot := (axis + direction * (float(k) - 1.0) * 0.4).normalized()
				needle_spray(attach + axis * float(k) * 0.06, shoot, length)

func bush(kind: String) -> void:
	for stem in 9:
		var angle := stem*2.399963
		var a := Vector3(cos(angle),0,sin(angle))*0.13
		var b := Vector3(cos(angle)*0.42,0.7,sin(angle)*0.42)
		twig(a,b,0.018,0.003)
	for i in (4000 if fine_hedge and kind=="hedge" else 850):
		var dir := Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		var center := Vector3(dir.x*0.66,0.55+dir.y*0.54,dir.z*0.66)
		if fine_hedge and kind=="hedge":
			center = Vector3(rng.randf_range(-0.48,0.48),rng.randf_range(0.12,0.82),rng.randf_range(-0.43,0.43))
			if i%4!=0:
				match rng.randi_range(0,4):
					0: center.y=0.82
					1: center.x=-0.48
					2: center.x=0.48
					3: center.z=-0.43
					4: center.z=0.43
			dir = Vector3(rng.randf_range(-1,1),rng.randf_range(-0.15,0.35),rng.randf_range(-1,1)).normalized()
		elif kind == "hedge":
			center = Vector3(clampf(center.x,-0.48,0.48),clampf(center.y,0.12,0.82),clampf(center.z,-0.43,0.43))
		center += Vector3(rng.randf_range(-0.08,0.08),rng.randf_range(-0.06,0.06),rng.randf_range(-0.08,0.08))
		var c := foliage_color()
		if detail == 1 and i%3 != 0:
			continue
		if fine_hedge and kind=="hedge":
			leaf(center,(dir+Vector3.UP*0.4).normalized(),0.075 if detail==0 else 0.12,0.044 if detail==0 else 0.068,c,"hedge")
		else:
			leaf(center,(dir+Vector3.UP*0.4).normalized(),0.18 if detail == 0 else 0.25,0.11 if detail == 0 else 0.16,c)

func grass() -> void:
	for i in 46:
		var angle := rng.randf()*TAU
		var at := Vector3(cos(angle),0,sin(angle))*sqrt(rng.randf())*0.34
		var side := Vector3(cos(angle+1.3),0,sin(angle+1.3))*rng.randf_range(0.006,0.012)
		var h := rng.randf_range(0.075,0.21)
		var bend := Vector3(cos(angle),0,sin(angle))*h*0.45
		var mid := at+Vector3.UP*h*0.6+bend*0.25
		var tip := at+Vector3.UP*h+bend
		var c := Color("50613a").lerp(Color("899056"),rng.randf())
		if detail == 1 and i%3 != 0:
			continue
		triangle(foliage,at-side,mid-side*0.6,at+side,c)
		triangle(foliage,at+side,mid-side*0.6,mid+side*0.6,c)
		triangle(foliage,mid-side*0.6,tip,mid+side*0.6,c)

func flowers(kind: String) -> void:
	var seed_base := rng.seed
	for i in 12:
		rng.seed = seed_base + i * 7919
		var a := rng.randf()*TAU
		var base := Vector3(cos(a),0,sin(a))*rng.randf_range(0.03,0.19)
		var top := base+Vector3(rng.randf_range(-0.04,0.04),rng.randf_range(0.22,0.38),rng.randf_range(-0.04,0.04))
		if detail == 1 and i%2 == 1:
			continue
		twig(base,top,0.003,0.001)
		for j in 3:
			var dir := Vector3(cos(a+j*2),0.25,sin(a+j*2))
			leaf(base.lerp(top,0.25+j*0.2)+dir*0.04,dir,0.08,0.045,foliage_color())
		var petals := 4 if kind == "violet" else 5
		var color := Color("ae86bc") if kind == "violet" else Color("c74e91").lerp(Color("914caa"),rng.randf())
		for j in petals:
			var dir := Vector3(cos(j*TAU/petals),0.35,sin(j*TAU/petals))
			leaf(top+dir*0.019,dir,0.05,0.033,color)
		for j in 5:
			triangle(foliage,top+Vector3.UP*0.008,top+Vector3(cos(j*TAU/5)*0.009,0,sin(j*TAU/5)*0.009),top+Vector3(cos((j+1)*TAU/5)*0.009,0,sin((j+1)*TAU/5)*0.009),Color("dcc777"))

func magnolia_flower(at: Vector3, size: float) -> void:
	var phase := rng.randf()*TAU
	var count := 9 if detail == 0 else 6
	for i in count:
		var angle := phase+TAU*float(i)/count
		var radial := Vector3(cos(angle),0,sin(angle))
		var layer := float(i%3)/2
		var direction := (Vector3.UP*(0.95-layer*0.3)+radial*(0.35+layer*0.5)).normalized()
		var length := size*(1.0-layer*0.12)
		var color := Color("ece9d9").lerp(Color("fffdf0"),rng.randf()*0.7)
		color.a = 0.35
		leaf(at+direction*length*0.5,direction,length,length*0.63,color,"petal")
