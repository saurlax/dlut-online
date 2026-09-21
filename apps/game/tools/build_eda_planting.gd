extends RefCounted
## Linear planting uses the same registered road coordinates and terrain as walking.

func append(builder, instances: Array[Dictionary], manifest: Dictionary) -> Array:
	var zones: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/linear_planting.json")).zones
	for zone: Dictionary in zones:
		var path := PackedVector2Array()
		if zone.has("feature_id"):
			for feature: Dictionary in manifest.features:
				if feature.id != zone.feature_id: continue
				assert(feature.osm_id==zone.osm_id and int(feature.osm_version)==int(zone.osm_version),"Facade planting anchor changed")
				var edge := int(zone.edge)
				var selection: Array = [feature.points[edge],feature.points[int(zone.get("end_vertex",(edge+1)%feature.points.size()))]]
				assert(selection==zone.expected_points,"Facade planting geometry changed")
				path = builder.polygon_points(selection)
				if zone.get("path_direction","")=="outward":
					var axis := (path[1]-path[0]).normalized()
					var outward := Vector2(axis.y,-axis.x)
					var origin := path[0].lerp(path[1],float(zone.anchor_fraction))
					if Geometry2D.is_point_in_polygon(origin+outward,builder.polygon_points(feature.points)): outward=-outward
					path = PackedVector2Array([origin,origin+outward*float(zone.path_length)])
					zone.path_points = [[path[0].x,path[0].y],[path[1].x,path[1].y]]
				break
		for road: Dictionary in builder.roads:
			if zone.has("feature_id"): break
			if int(road.osm_way_id) != int(zone.osm_way_id): continue
			assert(int(road.osm_version)==int(zone.osm_version),"Linear planting road version changed")
			var selection: Array = road.points.slice(int(zone.from_vertex),int(zone.to_vertex)+1)
			assert(selection==zone.expected_points,"Linear planting road geometry changed")
			path = builder.polygon_points(selection)
			break
		assert(path.size()>1,"Linear planting road missing")
		var rng := RandomNumberGenerator.new()
		rng.seed = int(zone.seed)
		var distance := float(zone.get("start_distance",float(zone.spacing)*0.5))
		var remaining := int(zone.get("station_count",1000000))
		for index in path.size()-1:
			var a := path[index]
			var b := path[index+1]
			var length := a.distance_to(b)
			var direction := (b-a).normalized()
			var side := Vector2(-direction.y,direction.x)
			while distance < length and remaining > 0:
				for offset in zone.get("offsets", [zone.get("offset", 0.0)]):
					for sign_side in zone.get("sides",[-1.0,1.0]):
						var at: Vector2 = a+direction*distance+side*sign_side*float(offset)
						if not builder.allowed(at,float(zone.clearance)): continue
						var height := rng.randf_range(zone.height[0],zone.height[1])
						var width := rng.randf_range(0.88,1.04)
						var rotation := rng.randf()*TAU
						if zone.get("align_to_path",false): rotation=-atan2(direction.y,direction.x)
						instances.append({"position":[snappedf(at.x,0.001),snappedf(builder.elevation(at),0.001),snappedf(at.y,0.001)],"kind":zone.kind,"height":snappedf(height,0.001),"width":snappedf(width,0.001),"rotation_y":snappedf(rotation,0.001),"variant":rng.randi_range(0,2),"zone":zone.id})
				distance += float(zone.spacing)
				remaining -= 1
			distance -= length
	return zones
