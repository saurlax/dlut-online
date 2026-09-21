extends RefCounted
## Photo-constrained local grading. Original DSM rows remain intact; the manifest
## supplies the same reviewed shoreline to grading, water, maps and collision.
const Water = preload("res://scripts/shared/water.gd")
var profile: Dictionary = {}
var regions: Array[Dictionary] = []
var water_levels: Dictionary = {}
var cells: Dictionary = {}
var samples: Dictionary = {}
var origin := Vector2.ZERO
var base_step := 10.0

func load_campus(campus: String, data: Dictionary) -> void:
	var path := "res://../../references/%s/terrain/lake-shores.json" % campus
	if not FileAccess.file_exists(path): return
	profile = JSON.parse_string(FileAccess.get_file_as_string(path))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/%s/data/campus.json" % campus))
	origin = Vector2(data.origin_xz[0], data.origin_xz[1])
	base_step = float(data.step_m)
	for selection: Dictionary in profile.lakes:
		var found := false
		for feature: Dictionary in manifest.features:
			if feature.id != selection.feature_id: continue
			assert(feature.kind == "water" and feature.osm_id == selection.osm_id)
			assert(feature.get("holes", []).is_empty(), "Register island grading before extending this photo profile")
			var name := "Feature_" + str(feature.id)
			assert(data.feature_base_y.has(name))
			var ring := PackedVector2Array()
			for p: Array in feature.points: ring.append(Vector2(p[0], p[1]))
			assert(ring.size() >= 3)
			var bounds := Rect2(ring[0], Vector2.ZERO)
			for p in ring: bounds = bounds.expand(p)
			var level := float(data.feature_base_y[name]) + float(profile.water_offset_m)
			water_levels[name] = level
			regions.append({"polygon":ring, "holes":[], "bounds":bounds.grow(float(profile.blend_end_m)), "level":level})
			var first := Vector2i(((bounds.position - Vector2.ONE * float(profile.blend_end_m) - origin) / base_step).floor())
			var last := Vector2i(((bounds.end + Vector2.ONE * float(profile.blend_end_m) - origin) / base_step).ceil())
			for row in range(maxi(0,first.y),mini(int(data.height)-1,last.y)):
				for col in range(maxi(0,first.x),mini(int(data.width)-1,last.x)):
					cells[Vector2i(col,row)] = true
			found = true
		assert(found, "Missing registered lake " + str(selection.feature_id))

func divisions(col: int, row: int) -> int:
	return int(round(base_step / float(profile.mesh_step_m))) if cells.has(Vector2i(col,row)) else 1

func elevation(terrain: RefCounted, x: float, z: float) -> float:
	var at := Vector2(x,z)
	var cell := Vector2i(((at-origin)/base_step).floor())
	if not cells.has(cell): return terrain.raw_elevation(x,z)
	var step := float(profile.mesh_step_m)
	var grid := (at-origin)/step
	var corner := Vector2i(grid.floor())
	var uv := grid-Vector2(corner)
	var a := sample(terrain,corner)
	var b := sample(terrain,corner+Vector2i.RIGHT)
	var c := sample(terrain,corner+Vector2i.DOWN)
	var d := sample(terrain,corner+Vector2i.ONE)
	# Match the exact local triangles used for terrain, roads and collision.
	return a+uv.x*(b-a)+uv.y*(c-a) if uv.x+uv.y <= 1.0 else d+(1.0-uv.x)*(c-d)+(1.0-uv.y)*(b-d)

func sample(terrain: RefCounted, grid: Vector2i) -> float:
	if samples.has(grid): return samples[grid]
	var at := origin+Vector2(grid)*float(profile.mesh_step_m)
	var raw: float = terrain.raw_elevation(at.x,at.y)
	var displacement := 0.0
	var total := 0.0
	for region: Dictionary in regions:
		if not region.bounds.has_point(at): continue
		var distance := 0.0 if Geometry2D.is_point_in_polygon(at,region.polygon) else Water.shore_distance(region,at)
		var weight := 1.0-smoothstep(float(profile.shelf_width_m),float(profile.blend_end_m),distance)
		var height := float(region.level)+lerpf(float(profile.wet_edge_offset_m),float(profile.bank_height_m),smoothstep(0.0,float(profile.bank_width_m),distance))
		displacement += (height-raw)*weight
		total += weight
	var result := raw+displacement/maxf(1.0,total)
	samples[grid] = result
	return result
