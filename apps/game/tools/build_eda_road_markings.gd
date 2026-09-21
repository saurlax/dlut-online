extends RefCounted

func build(host) -> void:
	var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/mapping/road-details.json"))
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	var geometry := preload("res://tools/build_roads.gd").new()
	var paint := ShaderMaterial.new()
	paint.resource_name = "EDA bounded yellow road paint"
	paint.shader = preload("res://assets/roads/yellow_paint.gdshader")
	for selection: Dictionary in profile.get("yellow_centerlines",[]):
		var road: Dictionary = {}
		for candidate: Dictionary in roads:
			if int(candidate.osm_way_id)==int(selection.osm_way_id): road=candidate
		assert(not road.is_empty(),"Missing registered centerline road")
		var index := int(selection.from_vertex)
		assert(int(road.osm_version)==int(selection.osm_version) and road.points.slice(index,index+2)==selection.expected_points,"Centerline road registration changed")
		var a := Vector2(road.points[index][0],road.points[index][1])
		var b := Vector2(road.points[index+1][0],road.points[index+1][1])
		var axis := (b-a).normalized()
		var start := float(selection.along[0])
		var end := float(selection.along[1])
		var width := float(selection.width_m)
		assert(start>0 and end<a.distance_to(b) and end>start)
		assert(width>0 and width<=0.2)
		var first := a+axis*start
		var last := a+axis*end
		var ribbons := preload("res://scripts/shared/road_geometry.gd").polygons([{"points":[[first.x,first.y],[last.x,last.y]],"width":width}])
		var node := geometry.emit(host,ribbons,-0.056,paint)
		terrain.fit_road(node)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var faces := node.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var order := [0,1,2] if (faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).y>0 else [0,2,1]
			for corner in order: surface.add_vertex(faces[i+corner])
		surface.index()
		surface.generate_normals()
		node.mesh=surface.commit()
		node.set_meta("walk_collision",false)
		node.set_meta("centerline_id",selection.id)
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
