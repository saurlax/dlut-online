extends SceneTree

var scene := Node3D.new()
var materials: Dictionary = {}
var manifest: Dictionary
var generated_count := 0
var residence_profiles: Dictionary = {}
var seventh_profile: Dictionary = {}
var academic_profiles: Dictionary = {}

func _initialize() -> void:
	call_deferred("build")

func material(key: String, color: Color) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.resource_name = key
	mat.albedo_color = color
	mat.roughness = 0.83
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if key == "Window glass":
		mat.metallic = 0.65
		mat.roughness = 0.19
	elif key not in ["Court markings", "Window frames"]:
		var noise := FastNoiseLite.new()
		noise.seed = 731
		noise.frequency = 0.045
		noise.fractal_octaves = 4
		var texture := NoiseTexture2D.new()
		texture.width = 256
		texture.height = 256
		texture.seamless = true
		texture.noise = noise
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.58,0.58,0.58))
		ramp.set_color(1, Color(1,1,1))
		texture.color_ramp = ramp
		mat.albedo_texture = texture
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE * (0.35 if key in ["Academic", "Residence", "Gate"] else 0.8)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	materials[key] = mat
	return mat

func mesh_node(parent: Node3D, mesh: Mesh, mat: Material, title: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	node.owner = scene
	return node

func box(parent: Node3D, at: Vector3, size: Vector3, mat: Material, title := "Detail") -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var node := mesh_node(parent, shape, mat, title)
	node.position = at
	return node

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func polygon(parent: Node3D, points: PackedVector2Array, height: float, mat: Material, title: String, base := 0.0, holes: Array = []) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	assert(not indices.is_empty(), "Invalid source polygon: " + title)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var rings: Array[PackedVector2Array] = [points]
	var cutouts: Array[PackedVector2Array] = []
	for hole: Array in holes:
		var inner := PackedVector2Array()
		for p: Array in hole: inner.append(Vector2(p[0],p[1]))
		if Geometry2D.is_polygon_clockwise(inner): inner.reverse()
		cutouts.append(inner)
		var wall_ring := inner.duplicate()
		wall_ring.reverse()
		rings.append(wall_ring)
	if holes.is_empty():
		for index in indices:
			st.add_vertex(Vector3(points[index].x, height, points[index].y))
	else:
		var outer := points.duplicate()
		if Geometry2D.is_polygon_clockwise(outer): outer.reverse()
		for quad in preload("res://tools/build_roads.gd").new().tessellate([outer],cutouts):
			for index in [0,2,1,0,3,2]:
				st.add_vertex(Vector3(quad[index].x,height,quad[index].y))
	if height - base > 0.2:
		for ring in rings:
			for i in ring.size():
				var p := ring[i]
				var q := ring[(i+1)%ring.size()]
				var a := Vector3(p.x, base, p.y)
				var b := Vector3(q.x, base, q.y)
				var c := Vector3(q.x, height, q.y)
				var d := Vector3(p.x, height, p.y)
				triangle(st, a, b, c)
				triangle(st, a, c, d)
	st.generate_normals()
	mesh_node(parent, st.commit(), mat, title)

func line(parent: Node3D, a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	var node := box(parent, (a+b)*0.5, Vector3(width, 0.08, a.distance_to(b)), mat)
	node.rotation.y = atan2((b-a).x, (b-a).z)

func facade(parent: Node3D, points: PackedVector2Array, height: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var clockwise := Geometry2D.is_polygon_clockwise(points)
	for i in points.size():
		var p := points[i]
		var q := points[(i+1)%points.size()]
		var length := p.distance_to(q)
		if length < 5:
			continue
		var direction := (q-p).normalized()
		var outward := Vector2(direction.y, -direction.x) * (1.0 if not clockwise else -1.0)
		var count := maxi(1, int(length/4.6))
		for floor_index in range(maxi(1,int((height-3)/3.8))):
			var y := 2.5 + floor_index * 3.8
			for column in range(count):
				var middle := p.lerp(q, (column+0.5)/count) + outward*0.08
				var left := middle-direction*1.15
				var right := middle+direction*1.15
				var a := Vector3(left.x,y,left.y)
				var b := Vector3(right.x,y,right.y)
				var c := Vector3(right.x,y+1.8,right.y)
				var d := Vector3(left.x,y+1.8,left.y)
				triangle(st,a,b,c)
				triangle(st,a,c,d)
				var trim := material("Window frames",Color("aaa9a2"))
				for offset in [-1.2,0.0,1.2]:
					var pos: Vector2 = middle + direction*offset + outward*0.05
					var frame := box(parent,Vector3(pos.x,y+0.9,pos.y),Vector3(0.065,1.94,0.16),trim,"FacadeDetail")
					frame.rotation.y = -atan2(direction.y,direction.x)
				for level in [0.0,1.8]:
					var pos: Vector2 = middle + outward*0.09
					var sill := box(parent,Vector3(pos.x,y+level,pos.y),Vector3(2.52,0.10,0.28),trim,"FacadeDetail")
					sill.rotation.y = -atan2(direction.y,direction.x)
		# Continuous stone base and roof coping give walls human-scale depth.
		for elevation in [0.45,height-0.18]:
			var mid := (p+q)*0.5 + outward*0.10
			var band := box(parent,Vector3(mid.x,elevation,mid.y),Vector3(length,0.65,0.26),material("Stone trim",Color("8c8980")),"FacadeDetail")
			band.rotation.y = -atan2(direction.y,direction.x)
	st.generate_normals()
	mesh_node(parent,st.commit(),material("Window glass",Color("35464f")),"Windows")

func oval(parent: Node3D, center: Vector2, radii: Vector2, elevation: float, mat: Material) -> void:
	var points := PackedVector2Array()
	for i in 80:
		var angle := TAU*i/80.0
		points.append(center + Vector2(cos(angle)*radii.x,sin(angle)*radii.y))
	polygon(parent,points,elevation,mat,"Oval")

func sports(parent: Node3D, points: PackedVector2Array, kind: String) -> void:
	var bounds := Rect2(points[0],Vector2.ZERO)
	for p in points:
		bounds = bounds.expand(p)
	var center := bounds.get_center()
	var white := material("Court markings",Color("f6eedc"))
	if kind == "track":
		var radii := bounds.size*Vector2(0.47,0.47)
		oval(parent,center,radii,0.25,material("Running track",Color("b77765")))
		for lane in range(6):
			var r := radii-Vector2.ONE*(lane*1.5+1.0)
			for i in 80:
				var a := TAU*i/80.0
				var b := TAU*(i+1)/80.0
				line(parent,Vector3(center.x+cos(a)*r.x,0.35,center.y+sin(a)*r.y),Vector3(center.x+cos(b)*r.x,0.35,center.y+sin(b)*r.y),0.18,white)
		oval(parent,center,radii-Vector2(13,15),0.4,material("Field grass",Color("739578")))
		var width := radii.x*1.2
		var depth := radii.y*1.25
		var corners := [Vector3(center.x-width/2,0.5,center.y-depth/2),Vector3(center.x+width/2,0.5,center.y-depth/2),Vector3(center.x+width/2,0.5,center.y+depth/2),Vector3(center.x-width/2,0.5,center.y+depth/2)]
		for i in 4:
			line(parent,corners[i],corners[(i+1)%4],0.25,white)
		line(parent,Vector3(center.x-width/2,0.5,center.y),Vector3(center.x+width/2,0.5,center.y),0.25,white)
	else:
		var count := 4 if kind == "basketball" else 2
		for court in count:
			var c := Vector2(center.x,bounds.position.y+bounds.size.y*(court+0.5)/count)
			var size := Vector2(bounds.size.x*0.78,bounds.size.y/count*0.8)
			box(parent,Vector3(c.x,0.3,c.y),Vector3(size.x,0.08,size.y),material("Court surface",Color("638c91")))
			var corners := [Vector3(c.x-size.x/2,0.4,c.y-size.y/2),Vector3(c.x+size.x/2,0.4,c.y-size.y/2),Vector3(c.x+size.x/2,0.4,c.y+size.y/2),Vector3(c.x-size.x/2,0.4,c.y+size.y/2)]
			for i in 4:
				line(parent,corners[i],corners[(i+1)%4],0.2,white)
			line(parent,Vector3(c.x-size.x/2,0.4,c.y),Vector3(c.x+size.x/2,0.4,c.y),0.2,white)


func merge_meshes(parent: Node3D) -> void:
	var buckets: Dictionary = {}
	for child in parent.get_children():
		if child is MeshInstance3D:
			# Roads and traced overlays carry distinct terrain offsets and source
			# metadata even when they share asphalt. Preserve those mesh boundaries.
			if child.get_meta("road_surface",false):
				continue
			var key: String = child.material_override.resource_name + ("_Solid" if child.get_meta("walk_collision",false) else "")
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append(child)
		elif child is Node3D:
			merge_meshes(child)
	for key in buckets:
		var nodes: Array = buckets[key]
		if nodes.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)
		for node in nodes:
			st.append_from(node.mesh,0,node.transform)
		var mat: Material = nodes[0].material_override
		var collision: bool = nodes[0].get_meta("walk_collision",false)
		for node in nodes:
			parent.remove_child(node)
			node.free()
		var merged := mesh_node(parent,st.commit(),mat,key.replace(" ","_"))
		merged.set_meta("walk_collision",collision)

func build() -> void:
	scene.name = "DevelopmentCampus"
	root.add_child(scene)
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	if not valid_ground_sources():
		quit(1)
		return
	var reference_path := ProjectSettings.globalize_path("res://").path_join("../../references/eda/buildings/residence_facades.json").simplify_path()
	residence_profiles = JSON.parse_string(FileAccess.get_file_as_string(reference_path))
	academic_profiles = JSON.parse_string(FileAccess.get_file_as_string(reference_path.get_base_dir().path_join("academic_facades.json")))
	seventh_profile = JSON.parse_string(FileAccess.get_file_as_string(reference_path.get_base_dir().path_join("seventh-residence/profile.json")))
	var map_bounds: Array = manifest.get("bounds",[-640,-410,1280,930])
	box(scene,Vector3(map_bounds[0]+map_bounds[2]/2.0,-6,map_bounds[1]+map_bounds[3]/2.0),Vector3(map_bounds[2],12,map_bounds[3]),material("Campus base",Color("74795b")),"CampusBase")
	preload("res://tools/build_roads.gd").new().build(self, "eda")
	for feature in manifest.features:
		var group := Node3D.new()
		group.name = "Feature_" + feature.id
		group.set_meta("source_id",feature.id)
		group.set_meta("geometry_status",feature.get("geometry_status",""))
		group.set_meta("display_name",feature.name)
		group.set_meta("height_is_approximate",true)
		scene.add_child(group)
		group.owner = scene
		if feature.kind == "reference":
			continue
		var points := PackedVector2Array()
		for point in feature.points:
			points.append(Vector2(point[0],point[1]))
		var kind: String = feature.kind
		var height: float = feature.height if feature.height != null else 0.0
		match kind:
			"building":
				if feature.id == "77943":
					var registration: Dictionary = {}
					if feature.has("osm_id"):
						var profile_path := reference_path.get_base_dir().path_join("dining_profile.json")
						registration = JSON.parse_string(FileAccess.get_file_as_string(profile_path))["77943"].osm_registration
						assert(feature.osm_id==registration.osm_id and int(feature.osm_version)==int(registration.osm_version),"Dining OSM source changed")
						assert(points.size()==int(registration.expected_vertices),"Dining OSM ring changed")
					preload("res://tools/build_eda_dining.gd").new().build(self,group,points,registration)
					generated_count += 1
					continue
				if feature.id == "77921":
					var profile_path := reference_path.get_base_dir().path_join("comprehensive_profile.json")
					var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile_path))["77921"]
					if feature.has("osm_id"):
						var registration: Dictionary = profile.osm_registration
						assert(feature.osm_id == registration.osm_id,"Unregistered comprehensive footprint")
						assert(int(feature.get("osm_version",-1)) == int(registration.osm_version),"Comprehensive OSM version changed; review facade anchors")
						profile.merge(registration,true)
					preload("res://tools/build_eda_comprehensive.gd").new().build(self,group,points,profile)
					generated_count += 1
					continue
				if feature.id == "77923":
					var registration: Dictionary = {}
					if feature.has("osm_id"):
						var profile_path := reference_path.get_base_dir().path_join("gym_profile.json")
						registration = JSON.parse_string(FileAccess.get_file_as_string(profile_path))["77923"].osm_registration
						assert(feature.osm_id==registration.osm_id and int(feature.osm_version)==int(registration.osm_version),"Gym OSM source changed")
						assert(points.size()==int(registration.expected_vertices),"Gym OSM ring changed")
					preload("res://tools/build_eda_gym.gd").new().build(self,group,points,registration)
					generated_count += 1
					continue
				if academic_profiles.has(feature.id):
					var profile: Dictionary = academic_profiles[feature.id].duplicate(true)
					if feature.has("osm_id"):
						assert(profile.has("osm_registration"),"Academic OSM facade registration missing")
						var registration: Dictionary = profile.osm_registration
						assert(feature.osm_id==registration.osm_id and int(feature.osm_version)==int(registration.osm_version),"Academic OSM version changed")
						assert(points.size()==int(registration.expected_vertices),"Academic OSM ring changed")
						assert(feature.get("footprint_refinement","")==registration.get("footprint_refinement",""),"Academic footprint refinement changed")
						profile.merge(registration,true)
					preload("res://tools/build_eda_academic.gd").new().build(self,group,points,profile)
					generated_count += 1
					continue
				if feature.id == "2304982":
					var profile: Dictionary = seventh_profile.duplicate(true)
					if feature.has("building_parts"):
						profile.merge(profile.osm_registration,true)
						profile.tower_points = feature.building_parts[0].points
						assert(feature.building_parts[0].osm_id=="way/375541049" and feature.building_parts[1].osm_id=="way/1381473266")
					preload("res://tools/build_eda_seventh.gd").new().build(self,group,points,profile)
					generated_count += 1
					continue
				if residence_profiles.has(feature.id):
					var profile: Dictionary = residence_profiles[feature.id].duplicate(true)
					if feature.has("osm_id"):
						assert(profile.has("osm_registration"),"Residence OSM facade registration missing")
						var registration: Dictionary = profile.osm_registration
						assert(feature.osm_id==registration.osm_id and int(feature.osm_version)==int(registration.osm_version),"Residence OSM source changed")
						assert(points.size()==int(registration.expected_vertices),"Residence OSM ring changed")
						profile.merge(registration,true)
					preload("res://tools/build_eda_residences.gd").new().build(self,group,points,profile)
					generated_count += 1
					continue
				if feature.id in ["77914","77917"]:
					var registration: Dictionary = {}
					if feature.has("osm_id"):
						var profiles_path := reference_path.get_base_dir().path_join("library_information_profiles.json")
						var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profiles_path))[feature.id]
						assert(profile.has("osm_registration"),"OSM photo facade registration missing")
						registration = profile.osm_registration
						assert(feature.osm_id == registration.osm_id and int(feature.get("osm_version",-1)) == int(registration.osm_version),"OSM photo facade source changed")
						assert(feature.get("footprint_refinement","") == registration.footprint_refinement,"Photo facade refinement mismatch")
					preload("res://tools/build_photo_facades.gd").new().build(self,group,points,feature.id=="77917",registration)
					generated_count += 1
					continue
				var color := Color("967c6c") if "宿舍" in feature.name else Color("b9b6ab")
				polygon(group,points,height,material("Residence" if "宿舍" in feature.name else "Academic",color),"Building")
				polygon(group,points,height+0.45,material("Roof",Color("92938b")),"Roof",height)
				# An unreferenced building keeps only its registered footprint shell.
				group.set_meta("facade_source","unavailable")
				group.set_meta("interior_available",false)
			"water":
				polygon(group,points,0.2,preload("res://assets/water/campus_water.tres"),"Lake")
			"hill":
				polygon(group,points,0.12,material("Hill footprint",Color("7e9a7c")),"HillBase")
				var center := Vector2.ZERO
				for p in points:
					center += p/points.size()
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_smooth_group(-1)
				for i in points.size():
					var p := points[i]
					var q := points[(i+1)%points.size()]
					triangle(st,Vector3(p.x,0.2,p.y),Vector3(q.x,0.2,q.y),Vector3(center.x,height,center.y))
				st.generate_normals()
				mesh_node(group,st.commit(),material("Hill",Color("73795d")),"SchematicTerrain")
			"track", "basketball", "tennis":
				polygon(group,points,0.15,material("Sports base",Color("bdbaa0")),"SportsBase")
				if feature.has("sports_surfaces"):
					group.get_child(group.get_child_count()-1).set_meta("walk_collision",true)
					group.set_meta("sports_source_count",feature.sports_surfaces.size())
					for surface: Dictionary in feature.sports_surfaces:
						var court := PackedVector2Array()
						for p: Array in surface.points: court.append(Vector2(p[0],p[1]))
						var surface_id: String = surface.get("id",surface.get("osm_id",""))
						assert(not surface_id.is_empty(),"Sports surface source identity missing")
						var surface_kind: String = surface.get("surface_type","court")
						var surface_material := material("Running surface",Color("b77765")) if surface_kind=="running" else material("Field grass",Color("739578")) if surface_kind=="grass" else material("Court surface",Color("638c91"))
						polygon(group,court,0.3,surface_material,"Court_"+surface_id.replace("/","_"),0.0 if surface_kind=="court" else 0.15,surface.get("holes",[]))
						group.get_child(group.get_child_count()-1).set_meta("walk_collision",true)
						if surface_kind!="court": continue
						for i in court.size():
							var a := court[i]
							var b := court[(i+1)%court.size()]
							line(group,Vector3(a.x,0.4,a.y),Vector3(b.x,0.4,b.y),0.12,material("Court markings",Color("f6eedc")))
					for outline: Dictionary in feature.get("sports_lines",[]):
						for i in outline.points.size():
							var a: Array = outline.points[i]
							var b: Array = outline.points[(i+1)%outline.points.size()]
							line(group,Vector3(a[0],0.4,a[1]),Vector3(b[0],0.4,b[1]),0.12,material("Court markings",Color("f6eedc")))
				else:
					sports(group,points,kind)
			"gate":
				# South-gate photos show a low plaque wall/retractable gate;
				# the other two photo responses are empty. None supports the
				# former uniform pillars, overhead beam or flat selection pad.
				group.set_meta("geometry_status",feature.geometry_status)
			_:
				polygon(group,points,0.1,material("Paving" if kind=="plaza" else "Reserve",Color("a9a79e") if kind=="plaza" else Color("adba99")),"Ground")
				if kind=="plaza" and feature.has("osm_id"):
					var surface: MeshInstance3D = group.get_child(group.get_child_count()-1)
					surface.set_meta("road_surface",true)
					surface.set_meta("walk_collision",true)
		generated_count += 1
	preload("res://tools/build_vegetation.gd").new().build(self)
	if not preload("res://tools/build_photo_surfaces.gd").new().build(self, "eda"):
		quit(1)
		return
	preload("res://tools/build_terrain.gd").new().build(self, "eda")
	merge_meshes(scene)
	for mat in materials.values():
		if mat.albedo_texture is NoiseTexture2D and mat.albedo_texture.get_image() == null:
			await mat.albedo_texture.changed
	var packed := PackedScene.new()
	assert(packed.pack(scene)==OK)
	assert(ResourceSaver.save(packed,"res://assets/campuses/eda/models/development_campus.tscn")==OK)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(scene,state)==OK)
	assert(document.write_to_filesystem(state,"res://assets/campuses/eda/models/development_campus.glb")==OK)
	print("MODEL PASS: %d source identity nodes, generated TSCN and GLB" % generated_count)
	quit()

func valid_ground_sources() -> bool:
	for feature: Dictionary in manifest.features:
		if feature.has("reference_points") or feature.has("reference_render_polygons") or ((not feature.get("points",[]).is_empty() or not feature.get("render_polygons",[]).is_empty()) and not feature.has("osm_id")):
			push_error("Unregistered selection geometry rejected: " + str(feature.id))
			return false
		if feature.has("withheld_geometry") and (feature.kind != "reference" or not feature.points.is_empty() or not feature.get("render_polygons",[]).is_empty()):
			push_error("Withheld source must remain empty: " + str(feature.id))
			return false
	return true
