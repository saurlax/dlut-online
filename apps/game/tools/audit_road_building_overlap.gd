extends SceneTree
## Read-only horizontal audit. Areas describe generated footprints, not survey accuracy.
const RoadGeometry = preload("res://scripts/shared/road_geometry.gd")
const RoadUnion = preload("res://tools/build_roads.gd")

func ring(raw: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in raw: result.append(Vector2(p[0],p[1]))
	if Geometry2D.is_polygon_clockwise(result): result.reverse()
	return result

func bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0],Vector2.ZERO)
	for p in points: result = result.expand(p)
	return result

func area(pieces: Array[PackedVector2Array]) -> float:
	var result := 0.0
	for p in pieces:
		for i in p.size(): result += (p[i]-p[0]).cross(p[(i+1)%p.size()]-p[0])*0.5
	return absf(result)

func _initialize() -> void:
	var report: Dictionary = {"scope":"Horizontal paved road width including shared-node junctions and subtracting ground-overlay masks as in build_roads; excludes decorative edging and overlay surfaces; does not prove vertical obstruction or measured accuracy", "campuses":{}, "conflicts":[]}
	var union := RoadUnion.new()
	for campus in ["lingshui","eda","panjin"]:
		var path: String = "res://assets/campuses/"+campus+"/data/"
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path+"campus.json"))
		var roads: Array = JSON.parse_string(FileAccess.get_file_as_string(path+"osm_roads.json")).roads
		var ribbons := RoadGeometry.polygons(roads)
		var boxes: Array[Rect2] = []
		for ribbon in ribbons: boxes.append(bounds(ribbon))
		var surface_masks: Array[PackedVector2Array] = []
		for surface in manifest.get("ground_overlays",[]): surface_masks.append(ring(surface.outer))
		var count := 0
		for feature in manifest.features:
			if feature.kind != "building": continue
			var pieces: Array[PackedVector2Array] = []
			var holes: Array[PackedVector2Array] = []
			for raw in feature.get("holes",[]): holes.append(ring(raw))
			for raw in feature.get("render_polygons",[feature.points]):
				var shell := ring(raw)
				var box := bounds(shell)
				for i in ribbons.size():
					if not box.intersects(boxes[i]): continue
					pieces.append_array(Geometry2D.intersect_polygons(shell,ribbons[i]))
			if pieces.is_empty(): continue
			var clipped := union.tessellate(pieces,holes+surface_masks)
			var overlap := area(clipped)
			if overlap<=0.1: continue
			var extent := bounds(clipped[0])
			for piece in clipped: extent = extent.merge(bounds(piece))
			var record: Dictionary = {"campus":campus,"id":feature.id,"part":feature.get("part",0),"name":feature.name,"source":feature.get("osm_id","legacy"),"overlap_m2":overlap,"bounds_xz":[extent.position.x,extent.position.y,extent.end.x,extent.end.y]}
			report.conflicts.append(record)
			count += 1
		report.campuses[campus] = {"conflicting_parts":count,"campus_sha256":FileAccess.get_sha256(path+"campus.json"),"roads_sha256":FileAccess.get_sha256(path+"osm_roads.json")}
	report.conflicts.sort_custom(func(a,b):return a.overlap_m2>b.overlap_m2)
	var output := ProjectSettings.globalize_path("res://../../.local/osm-world/road-width-overlaps.json")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("ROAD WIDTH AUDIT: ",JSON.stringify(report.campuses))
	for item in report.conflicts: print(JSON.stringify(item))
	print("Saved ",output)
	quit()
