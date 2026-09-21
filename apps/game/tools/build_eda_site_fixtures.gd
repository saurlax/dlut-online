extends RefCounted

func build(host) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/site_fixtures.json"))
	var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	for fixture: Dictionary in data.courtyard_lamps:
		var road: Dictionary = {}
		for candidate: Dictionary in roads:
			if int(candidate.osm_way_id) == int(fixture.road_id): road = candidate
		assert(not road.is_empty() and int(road.osm_version) == int(fixture.road_version))
		var points := [road.points[int(fixture.vertices[0])],road.points[int(fixture.vertices[1])]]
		assert(points == fixture.expected_points,"Courtyard lamp road anchor changed")
		var start := Vector2(points[0][0],points[0][1])
		var end := Vector2(points[1][0],points[1][1])
		var axis := (end-start).normalized()
		var offset := float(fixture.west_side_offset_m)
		assert(offset > float(road.width)*0.5+0.2,"Lamp must remain outside walking surface")
		var station := float(fixture.distance_from_junction_m)
		assert(station > 3.2 and station < start.distance_to(end))
		var point := start+axis*station+Vector2(-axis.y,axis.x)*offset
		var base := Vector3(point.x,terrain.elevation(point.x,point.y),point.y)
		preload("res://tools/build_eda_courtyard_lamp.gd").new().build(host,host.scene,base)
	build_bridge_fixtures(host,data,terrain)

func build_bridge_fixtures(host, data: Dictionary, terrain) -> void:
	var fixture: Dictionary = data.bridge_west_lamps
	var bridge: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/structures/xueyuan_bridge.json"))
	assert(bridge.osm_id == fixture.bridge_id and bridge.west == fixture.expected_west and bridge.east == fixture.expected_east,"Bridge lamp anchor changed")
	var start := Vector2(bridge.west[0],bridge.west[1])
	var end := Vector2(bridge.east[0],bridge.east[1])
	var axis := (end-start).normalized()
	var group := Node3D.new()
	group.name = "XueyuanWestFixtures"
	host.scene.add_child(group)
	group.owner = host.scene
	group.set_meta("absolute_terrain_y",true)
	group.set_meta("static_collision_group",true)
	group.set_meta("dimensions_are_approximate",true)
	for across: float in fixture.across_m:
		assert(absf(across) > float(bridge.deck_width)*0.5+0.5,"Lamp must clear the stair approach")
		var point := start+axis*float(fixture.station_m)+Vector2(-axis.y,axis.x)*across
		var base := Vector3(point.x,terrain.elevation(point.x,point.y),point.y)
		preload("res://tools/build_eda_courtyard_lamp.gd").new().build(host,group,base)
	var boards: Dictionary = data.bridge_west_noticeboards
	for across: float in boards.across_m:
		assert(absf(across)-float(boards.top_bar_width_m)*0.5 > float(bridge.deck_width)*0.5+0.5,"Noticeboard must clear the stair approach")
		var point := start+axis*float(boards.station_m)+Vector2(-axis.y,axis.x)*across
		preload("res://tools/build_eda_noticeboard.gd").new().build(host,group,point,axis,boards,terrain)
