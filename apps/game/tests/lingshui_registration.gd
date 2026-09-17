extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/campus.json"))
	var model: Node3D = load("res://assets/campuses/lingshui/models/lingshui_campus.tscn").instantiate()
	root.add_child(model)
	var checked := 0
	for feature: Dictionary in data.features:
		if feature.id not in ["77398","77443","77444","77446","77423","77357","77447","77426","77386","77355","77385","77395","77396","77394","17937827","35995473","77440","78148","625864","77458","77495","77500","77502","77555","77556","77557","77558","77559","29813247","77481","77462","77430","77383","77358","77539","77540","77542","77553","77519","77564","77565","77566","77567","77562","77563","77496","77483","77380","77505","77506","77382","77378","77379","77487","34785233","77509","77356","77387","77412","77413","77416","77427","77429","77431","77439","77441","77461","77499","77504","77507","77508","77510","77511","77512","77513","77514"]: continue
		assert(feature.has("osm_id") and not feature.has("reference_points"))
		if feature.id in ["77398","77443","77444","77446","77423","77357","77447","77426","77386","77355","77385","77395","77396","77394","17937827","35995473","77440","78148","625864","77458","77495","77500","77502","77555","77556","77557","77558","77559","29813247","77481","77462","77430","77383","77358","77539","77540","77542","77553","77519","77564","77565","77566","77567","77562","77563","77496","77483","77380","77505","77506","77382","77378","77379","77487","34785233","77509","77356","77387","77461","77499","77504","77507","77508","77510","77511","77512","77513","77514"]:
			var outline := PackedVector2Array()
			for p in feature.points: outline.append(Vector2(p[0],p[1]))
			var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/osm_roads.json")).roads
			for road in roads:
				var line := PackedVector2Array()
				for p in road.points: line.append(Vector2(p[0],p[1]))
				var length := 0.0
				for piece in Geometry2D.intersect_polyline_with_polygon(line,outline):
					for i in range(1,piece.size()): length += piece[i-1].distance_to(piece[i])
				assert(length<0.5,"Registered residence again covers a road centerline")
		var group: Node3D = model.get_node("Feature_"+feature.id+"_0")
		var roof := PackedVector2Array()
		var lower_windows := 0
		var lingxi_atrium_span := Vector2(INF,-INF)
		var bochuan_south_vertices := 0
		var museum_glass_span := Vector2(INF,-INF)
		var museum_glass_height := Vector2(INF,-INF)
		var police_window_span := Vector2(INF,-INF)
		var houde_window_span := Vector2(INF,-INF)
		for mesh: MeshInstance3D in group.get_children():
			for vertex: Vector3 in mesh.mesh.get_faces():
				var p := mesh.transform*vertex
				if feature.id == "77398" and mesh.material_override.resource_name == "Window glass":
					var a := Vector2(feature.points[1][0],feature.points[1][1])
					var b := Vector2(feature.points[2][0],feature.points[2][1])
					var along := (Vector2(p.x,p.z)-a).dot((b-a).normalized())
					police_window_span.x=minf(police_window_span.x,along)
					police_window_span.y=maxf(police_window_span.y,along)
					assert(Vector2(p.x,p.z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(p.x,p.z),a,b))<0.152,"Police windows detached from registered south facade")
				if feature.id == "77446" and mesh.material_override.resource_name == "Window glass":
					var a := Vector2(feature.points[2][0],feature.points[2][1])
					var b := Vector2(feature.points[3][0],feature.points[3][1])
					var along := (Vector2(p.x,p.z)-a).dot((b-a).normalized())
					houde_window_span.x = minf(houde_window_span.x,along)
					houde_window_span.y = maxf(houde_window_span.y,along)
					assert(Vector2(p.x,p.z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(p.x,p.z),a,b))<0.152, "Houde windows detached from south wall")
				if (mesh.material_override.resource_name=="Lingshui roof" and absf(p.y-float(feature.height)-0.18)<0.001) or (feature.id in ["77440","77430","77540","77542","77553","77519","77499","77504"] and mesh.material_override.resource_name=="Gabled hall roof"):
					roof.append(Vector2(p.x,p.z))
				if feature.id == "77357" and mesh.material_override.resource_name == "Window glass":
					var a := Vector2(feature.points[14][0],feature.points[14][1])
					var b := Vector2(feature.points[15][0],feature.points[15][1])
					var axis := (b-a).normalized()
					var offset := Vector2(p.x,p.z)-a
					var along := offset.dot(axis)
					var fraction := along/a.distance_to(b)
					assert(absf(offset.cross(axis))<0.202 and fraction>0.0618047 and fraction<0.9381953, "Lingxi glazing escaped reviewed west facade")
					if absf(p.y-1.89)<0.002 or absf(p.y-23.49)<0.002:
						lingxi_atrium_span.x = minf(lingxi_atrium_span.x,along)
						lingxi_atrium_span.y = maxf(lingxi_atrium_span.y,along)
				if feature.id == "77447" and mesh.material_override.resource_name == "Window glass":
					var a := Vector2(feature.points[3][0],feature.points[3][1])
					var b := Vector2(feature.points[4][0],feature.points[4][1])
					var axis := (b-a).normalized()
					var offset := Vector2(p.x,p.z)-a
					if absf(offset.cross(axis))<0.152:
						var along := offset.dot(axis)
						assert(along>a.distance_to(b)-16.471765 and along<a.distance_to(b), "Bochuan east-wing windows spread across south front")
						assert(p.y>1.199 and p.y<23.401, "Bochuan five window rows stretched vertically")
						bochuan_south_vertices += 1
					else:
						a = Vector2(feature.points[7][0],feature.points[7][1])
						b = Vector2(feature.points[0][0],feature.points[0][1])
						axis = (b-a).normalized()
						offset = Vector2(p.x,p.z)-a
						var t := offset.dot(axis)/a.distance_to(b)
						assert(absf(offset.cross(axis))<0.152 and ((t>0.035 and t<0.31) or (t>0.69 and t<0.965)), "Bochuan north windows occupy unreviewed center or other wall")
				if feature.id == "77426" and mesh.material_override.resource_name == "Window glass":
					var a := Vector2(feature.points[14][0],feature.points[14][1])
					var b := Vector2(feature.points[15][0],feature.points[15][1])
					var axis := (b-a).normalized()
					var offset := Vector2(p.x,p.z)-a
					if absf(offset.cross(axis))<0.15:
						var along := offset.dot(axis)
						museum_glass_span.x = minf(museum_glass_span.x,along)
						museum_glass_span.y = maxf(museum_glass_span.y,along)
						museum_glass_height.x = minf(museum_glass_height.x,p.y)
						museum_glass_height.y = maxf(museum_glass_height.y,p.y)
				if feature.id == "77386" and mesh.material_override.resource_name == "Window glass":
					var a := Vector2(feature.points[13][0], feature.points[13][1])
					var b := Vector2(feature.points[14][0], feature.points[14][1])
					var along := (Vector2(p.x,p.z)-a).dot((b-a).normalized())/a.distance_to(b)
					assert(along>0.294667685 and along<0.686545894, "Main windows extended beyond reviewed central facade")
					lower_windows += 1
				if feature.id in ["77555","77556","77557","77558","77559"] and mesh.material_override.resource_name=="Window glass":
					var edge := 1 if feature.id=="77555" else 2
					var a := Vector2(feature.points[edge][0],feature.points[edge][1])
					var b := Vector2(feature.points[(edge+1)%4][0],feature.points[(edge+1)%4][1])
					var direction := (b-a).normalized()
					var offset := Vector2(p.x,p.z)-a
					assert(offset.dot(direction)>0 and offset.dot(direction)<a.distance_to(b),"Photo window extends past source wall")
					assert(absf(offset.cross(direction))<0.152,"Photo window detached from registered long wall")
					lower_windows += 1
				if feature.id in ["77412","77413"] and mesh.material_override.resource_name=="Window glass" and p.y<3:
					assert(p.z>-228,"Visible ground-floor windows moved away from the south end")
					lower_windows += 1
			if mesh.get_meta("walk_collision",false): preload("res://scripts/shared/campus_collision.gd")._collider(mesh)
		if feature.id in ["77386","77412","77413","77555","77556","77557","77558","77559"]: assert(lower_windows>0)
		if feature.id == "77357": assert(absf(lingxi_atrium_span.y-lingxi_atrium_span.x-68.21831292625154*0.44)<0.003, "Lingxi curtain wall stretched with new footprint")
		if feature.id == "77447": assert(bochuan_south_vertices>0)
		if feature.id == "77426":
			assert(absf(museum_glass_span.y-museum_glass_span.x-4.9)<0.002, "Museum entrance glazing stretched with source edge")
			assert(absf(museum_glass_height.x-4.1)<0.002 and absf(museum_glass_height.y-12.2)<0.002, "Museum entrance glazing height changed")
		for coordinate: Array in feature.points:
			var found := false
			for p in roof:
				if p.distance_to(Vector2(coordinate[0],coordinate[1]))<0.001: found = true
			assert(found,"Saved roof corner differs from the registered source")
		if feature.id == "77446":
			assert(absf(houde_window_span.y-houde_window_span.x-(53.22875249587124*13.0/14.0+2.05))<0.005, "Houde window row stretched during registration")
		if feature.id=="77398": assert(absf(police_window_span.y-police_window_span.x-(13.96484249821674*0.75+2.0))<0.005,"Police window spacing stretched during registration")
		checked += 1
	assert(checked==76)
	await physics_frame
	await physics_frame
	for feature: Dictionary in data.features:
		if feature.id not in ["77555","77556","77557","77558","77559"]: continue
		var group: Node3D = model.get_node("Feature_"+feature.id+"_0")
		for edge in 4:
			var a := Vector2(feature.points[edge][0],feature.points[edge][1])
			var b := Vector2(feature.points[(edge+1)%4][0],feature.points[(edge+1)%4][1])
			var center := (a+b)*0.5
			var direction := (b-a).normalized()
			var normal := Vector3(direction.y,0,-direction.x)
			var p := Vector3(center.x,group.position.y+2,center.y)
			var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+normal,p-normal))
			if hit.is_empty(): hit = model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p-normal,p+normal))
			assert(not hit.is_empty() and hit.position.distance_to(p)<0.03,"East 30-34 wall collider detached")
	var balcony_samples: Array[Vector3] = []
	for feature: Dictionary in data.features:
		if feature.id not in ["77500","77502"]: continue
		var group: Node3D = model.get_node("Feature_"+feature.id+"_0")
		var edge := 2 if feature.id=="77500" else 0
		var a := Vector2(feature.points[edge][0],feature.points[edge][1])
		var b := Vector2(feature.points[(edge+1)%4][0],feature.points[(edge+1)%4][1])
		var direction := (b-a).normalized()
		var outward := Vector2(direction.y,-direction.x)
		if outward.y<0: outward = -outward
		var center := a.lerp(b,0.6 if feature.id=="77500" else 0.4)+outward*0.7
		for top in [3.5,7.0,10.5,14.0,17.5]:
			var p := Vector3(center.x,group.position.y+top,center.y)
			var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.05,p-Vector3.UP*0.05))
			assert(not hit.is_empty() and hit.position.distance_to(p)<0.002,"Migrated balcony floor missing")
			balcony_samples.append(p)
	assert(balcony_samples.size()==10)
	for sample in [["77412",384.25,-235],["77413",444.86,-239]]:
		var group: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		var p := Vector3(sample[1],group.position.y+6,sample[2])
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.RIGHT*4,p-Vector3.RIGHT*4))
		assert(not hit.is_empty() and absf(hit.position.x-p.x)<0.1,"East wall collision detached from registered footprint")
	for sample in [["77416",420,410.23],["77427",470,230.24],["77429",618,225.23],["77431",470,99.23],["77439",838,73.1595],["77441",860,0.744]]:
		var group: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		var p := Vector3(sample[1],group.position.y+6,sample[2])
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.BACK*4,p-Vector3.BACK*4))
		assert(not hit.is_empty() and absf(hit.position.z-p.z)<0.1,"Registered north/south wall collision detached")
	for sample in [["77507",-339.109,161.548],["77508",-379.550,165.291],["77510",-379.552,93.131],["77511",-343.416,88.177],["77512",-378.814,13.064],["77513",-334.055,-10.875],["77514",-292.211,-45.333]]:
		var residence: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		for level in ([3.5,7.0,10.5,14.0] if sample[0] in ["77507","77508","77510","77511"] else [3.5,7.0,10.5,14.0,17.5]):
			var p := Vector3(sample[1],residence.position.y+level,sample[2])
			var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.4,p-Vector3.UP*0.4))
			assert(not hit.is_empty() and absf(hit.position.y-p.y)<0.02,"Registered south balcony floor detached")
	for sample in [["77496",-314.836,318.414,1,0],["77496",-316.401,344.496,0,1],["77483",-65.226,395.269,1,0],["77380",-59.321,-55.270,1,0],["77505",-237.768,79.343,1,0],["77506",-189.986,61.938,1,0],["77382",26.755,154.662,1,0],["77379",-23.163,-123.977,1,0],["77379",3.306,-150.265,0,1],["77379",-11.781,-147.544,1,0],["77379",-14.723,-143.965,0,1],["77379",-18.441,-142.723,0,1],["77487",1.384,252.992,0,1],["77487",5.644,251.550,1,0],["34785233",314.143,-50.851,0,1],["77509",-404.526,138.065,1,0],["77509",-418.079,178.123,0,1],["77356",-615.660,-72.108,1,0],["77356",-572.163,-35.895,0,1],["77356",-610.946,-42.791,0,1],["77356",-590.621,-46.448,1,0],["77387",356.302,379.006,1,0]]:
		var group: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		var p := Vector3(sample[1],group.position.y+6,sample[2])
		var direction := Vector3(sample[3],0,sample[4])
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+direction*3,p-direction*3))
		assert(not hit.is_empty() and hit.position.distance_to(p)<0.03,"Teaching/houmin wall collision detached")
	var teaching: Node3D = model.get_node("Feature_77356_0")
	var notch := Vector3(-595,teaching.position.y,-48)
	var notch_hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(notch+Vector3.UP*30,notch+Vector3.UP*2))
	assert(notch_hit.is_empty(),"Teaching building setback was filled by collision geometry")
	var residence26: Node3D = model.get_node("Feature_77509_0")
	var outside_l := Vector3(-430,residence26.position.y,130)
	assert(model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(outside_l+Vector3.UP*30,outside_l+Vector3.UP*2)).is_empty(),"Residence 26 L-shaped setback was filled")
	var haihan: Node3D = model.get_node("Feature_77379_0")
	var courtyard := Vector3(-10,haihan.position.y,-120)
	assert(model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(courtyard+Vector3.UP*30,courtyard+Vector3.UP*2)).is_empty(),"Haihan courtyard was filled")
	var teaching1: Node3D = model.get_node("Feature_77378_0")
	for location in [Vector2(95,-70),Vector2(110,-70),Vector2(123,-70)]:
		var p := Vector3(location.x,teaching1.position.y,location.y)
		assert(model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*30,p+Vector3.UP*2)).is_empty(),"Teaching 1 forecourt gap was filled")
	var laofu: Node3D = model.get_node("Feature_77382_0")
	var rear_gap := Vector3(5,laofu.position.y,155)
	assert(model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(rear_gap+Vector3.UP*15,rear_gap+Vector3.UP*2)).is_empty(),"Laofu rear setback was filled")
	var north: Node3D = model.get_node("Feature_77461_0")
	# Three southern segments and the eastern end must follow the bent source footprint.
	for sample in [[192.755,-688.241,0,1],[166.346,-679.887,0,1],[140.115,-666.189,0,1],[204.908,-699.418,1,0]]:
		var p := Vector3(sample[0],north.position.y+6,sample[1])
		var direction := Vector3(sample[2],0,sample[3])
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+direction*3,p-direction*3))
		assert(not hit.is_empty() and hit.position.distance_to(p)<0.03,"North residence bent wall collision detached")
	# Independent source-frame samples check ridge height and both roof slopes.
	for sample in [["77499",-289.424,198.333],["77504",-305.776,75.981]]:
		var residence: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		var peak := Vector3(sample[1],residence.position.y+26.0,sample[2])
		var space := model.get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(peak+Vector3.UP,peak-Vector3.UP))
		assert(not hit.is_empty() and absf(hit.position.y-peak.y)<0.03,"Registered roof ridge height/location differs")
		for offset in [-4.0,4.0]:
			var p := peak+Vector3(offset,0,0)
			var slope := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP*4))
			assert(not slope.is_empty() and slope.position.y<peak.y-1.0 and slope.position.y>peak.y-3.0,"Gabled roof slope collision detached")
	for sample in [["77499",-277.075,231.595],["77504",-292.807,109.785]]:
		var residence: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		for level in [7.0,10.5,14.0,17.5]:
			var p := Vector3(sample[1],residence.position.y+level,sample[2])
			var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.4,p-Vector3.UP*0.4))
			assert(not hit.is_empty() and absf(hit.position.y-p.y)<0.02,"East long balcony collision detached")
	for sample in [["77562",737.597,-133.164],["77563",733.203,-158.845]]:
		var residence: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		for level in [7.93,11.48]:
			var p := Vector3(sample[1],residence.position.y+level,sample[2])
			var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.08,p-Vector3.UP*0.08))
			assert(not hit.is_empty() and absf(hit.position.y-p.y)<0.02,"East-end window platform slab detached")
	for sample in [["77564", 728.454, -182.323, 11.48], ["77564", 719.551, -181.823, 11.48], ["77564", 716.583, -181.656, 11.48], ["77564", 719.551, -181.823, 7.93], ["77564", 716.583, -181.656, 7.93], ["77565", 785.397, -81.835, 4.38], ["77565", 785.397, -81.835, 7.93], ["77565", 785.397, -81.835, 11.48], ["77565", 776.496, -81.334, 4.38], ["77565", 776.496, -81.334, 7.93], ["77565", 776.496, -81.334, 11.48], ["77565", 773.529, -81.167, 4.38], ["77565", 773.529, -81.167, 7.93], ["77565", 773.529, -81.167, 11.48], ["77565", 764.629, -80.666, 4.38], ["77565", 764.629, -80.666, 7.93], ["77565", 764.629, -80.666, 11.48], ["77566", 781.394, -107.237, 4.38], ["77566", 781.394, -107.237, 7.93], ["77566", 781.394, -107.237, 11.48], ["77567", 776.315, -132.196, 4.38], ["77567", 776.315, -132.196, 7.93], ["77567", 776.315, -132.196, 11.48]]:
		var residence: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		var p := Vector3(sample[1],residence.position.y+sample[3],sample[2])
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.08,p-Vector3.UP*0.08))
		assert(not hit.is_empty() and absf(hit.position.y-p.y)<0.02,"East residences 39-42 platform collision detached")
	for sample in [["77540", 525.334, -105.278, 13.4], ["77542", 529.987, -181.632, 11.0], ["77553", 611.889, -184.12, 11.2], ["77519", 466.009, -218.958, 12.3]]:
		var group: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		var peak := Vector3(sample[1],group.position.y+sample[3],sample[2])
		var space := model.get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(peak+Vector3.UP*0.3,peak-Vector3.UP*0.3))
		assert(not hit.is_empty() and absf(hit.position.y-peak.y)<0.03,"East gabled ridge detached from new footprint")
		for offset in [-3.0,3.0]:
			var p := peak+Vector3(0,0,offset)
			var slope := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.3,p-Vector3.UP*2.0))
			assert(not slope.is_empty() and slope.position.y<peak.y-0.5 and slope.position.y>peak.y-1.8,"East gabled slope detached")
	var zhishun: Node3D = model.get_node("Feature_77358_0")
	var zhishun_void := Vector3(-560,zhishun.position.y+10,-360)
	var zhishun_void_hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(zhishun_void+Vector3.UP*15,zhishun_void))
	assert(zhishun_void_hit.is_empty(),"Zhishun inner recess filled by an enclosing silhouette")
	for sample in [["77462",253.995,-694.843],["77383",83.5,132.111],["77383",108.507,133.384],["77383",116.670,131.363],["77383",124.946,133.584],["77383",149.816,131.675]]:
		var group: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		var p := Vector3(sample[1],group.position.y+6,sample[2])
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.BACK*2,p-Vector3.BACK*2))
		assert(not hit.is_empty() and absf(hit.position.z-p.z)<0.03,"Registered facade wall displaced")
	var wind: Node3D = model.get_node("Feature_77430_0")
	for offset in [-4.0,0.0,4.0]:
		var p := Vector3(874.772+offset,wind.position.y+6.5,109.494)
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.2,p-Vector3.UP*1.5))
		var expected := p.y-absf(offset)/7.4698*1.5
		assert(not hit.is_empty() and absf(hit.position.y-expected)<.03,"Wind laboratory roof ridge/slope detached")
	var qinyuan: Node3D = model.get_node("Feature_77481_0")
	for sample in [[-45.906,372.226],[-54.297,375.623],[-37.511,375.229]]:
		var p := Vector3(sample[0],qinyuan.position.y+3,sample[1])
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p-Vector3.BACK,p+Vector3.BACK))
		assert(not hit.is_empty() and absf(hit.position.z-p.z)<.05,"Qinyuan recessed glazing wall misplaced")
	var public_surfaces: Array[Vector3] = []
	for feature: Dictionary in data.features:
		if feature.id not in ["77440","625864"]: continue
		var group: Node3D = model.get_node("Feature_"+feature.id+"_0")
		if feature.id=="77440":
			var angle: float = feature.facade.roof_rotation
			var center := Vector2.ZERO
			var low := INF
			var high := -INF
			for pair: Array in feature.points:
				var p := Vector2(pair[0],pair[1]).rotated(-angle)
				center += p/4
				low = minf(low,p.y)
				high = maxf(high,p.y)
			for fraction in [-0.25,0.0,0.25]:
				var p := Vector2(center.x,(low+high)/2+fraction*(high-low)).rotated(angle)
				public_surfaces.append(Vector3(p.x,group.position.y+(10.6 if fraction==0 else 9.9),p.y))
		else:
			for edge in [0,1]:
				var a := Vector2(feature.points[edge][0],feature.points[edge][1])
				var b := Vector2(feature.points[edge+1][0],feature.points[edge+1][1])
				var direction := (b-a).normalized()
				var outward := Vector2(direction.y,-direction.x)
				if (edge==0 and outward.x>0) or (edge==1 and outward.y<0): outward = -outward
				var p := (a+b)/2+outward*0.7
				for top in [4.275,8.375,12.775]: public_surfaces.append(Vector3(p.x,group.position.y+top,p.y))
	assert(public_surfaces.size()==9)
	for p: Vector3 in public_surfaces:
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.05,p-Vector3.UP*0.05))
		assert(not hit.is_empty() and hit.position.distance_to(p)<0.003,"Registered laboratory roof or office eave misplaced")
	# Source setbacks must remain empty; bounding boxes would fill these points.
	for sample in [["77357",-738,-142],["77447",212,505],["77447",285,505],["77426",450,220],["77394",260,95],["35995473",394,142],["35995473",370,122],["77395",160,325],["77385",160,190],["77385",225,190]]:
		var group: Node3D = model.get_node("Feature_"+str(sample[0])+"_0")
		var p := Vector3(sample[1],group.position.y,sample[2])
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*30,p+Vector3.UP))
		assert(hit.is_empty(),"Source building setback filled")
	var hex_ring := PackedVector2Array()
	var east_ring := PackedVector2Array()
	for feature: Dictionary in data.features:
		if feature.id=="17937827":
			for p: Array in feature.points: hex_ring.append(Vector2(p[0],p[1]))
		if feature.id=="77396":
			for p: Array in feature.points: east_ring.append(Vector2(p[0],p[1]))
	assert(hex_ring.size()==6 and east_ring.size()==15)
	assert(Geometry2D.intersect_polygons(hex_ring,east_ring).is_empty(),"Main east wing overlaps the hexagonal building")
	var hex_group: Node3D = model.get_node("Feature_17937827_0")
	var hex_center := Vector3(340,hex_group.position.y,362)
	var hex_hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(hex_center+Vector3.UP*35,hex_center+Vector3.UP*8))
	assert(not hex_hit.is_empty() and absf(hex_hit.position.y-hex_center.y-10.1)<0.003,"Neighbour roof still covers the hexagonal building")
	var main_group: Node3D = model.get_node("Feature_77386_0")
	var main_base_y := main_group.position.y
	check_main_portico(model, data, main_base_y)
	var laboratory_base_y: float = model.get_node("Feature_77423_0").position.y
	check_three_beam_clearance(model, data, laboratory_base_y)
	var houde_base_y: float = model.get_node("Feature_77446_0").position.y
	check_houde_clearance(model, data, houde_base_y)
	var science_bases := {"77443": model.get_node("Feature_77443_0").position.y, "77444": model.get_node("Feature_77444_0").position.y}
	check_science_park_clearance(model, data, science_bases)
	var police_base_y: float = model.get_node("Feature_77398_0").position.y
	check_police_clearance(model,data,police_base_y)
	model.queue_free()
	var server: Node3D = load("res://scenes/server/lingshui.scn").instantiate()
	root.add_child(server)
	await physics_frame
	await physics_frame
	for p: Vector3 in balcony_samples+public_surfaces:
		var hit := server.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.05,p-Vector3.UP*0.05))
		assert(not hit.is_empty() and hit.position.distance_to(p)<0.002,"Exported registered surface missing")
	check_main_portico(server, data, main_base_y)
	check_three_beam_clearance(server, data, laboratory_base_y)
	check_houde_clearance(server, data, houde_base_y)
	check_science_park_clearance(server, data, science_bases)
	check_police_clearance(server,data,police_base_y)
	print("LINGSHUI REGISTRATION PASS: seventy-six roofs, registered walls and sixty-six residence platform floors and eight gabled roofs; ten balcony floors and nine roof/eave samples, bounded main portico and three-beam road clearance in client and exported server")
	quit()

func check_science_park_clearance(world: Node3D, data: Dictionary, bases: Dictionary) -> void:
	var outlines: Dictionary = {}
	var sources := {"77443": "way/219032067", "77444": "way/219032047"}
	for feature: Dictionary in data.features:
		if not sources.has(feature.id): continue
		assert(feature.osm_id == sources[feature.id] and feature.osm_version == 1)
		var ring := PackedVector2Array()
		for p: Array in feature.points: ring.append(Vector2(p[0],p[1]))
		outlines[feature.id] = ring
	assert(outlines.size()==2 and outlines["77443"].size()==13 and outlines["77444"].size()==10)
	assert(Geometry2D.intersect_polygons(outlines["77443"],outlines["77444"]).is_empty(), "Science park and academic apartments merged")
	var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/osm_roads.json")).roads
	for ribbon in preload("res://scripts/shared/road_geometry.gd").polygons(roads):
		for ring in outlines.values():
			assert(Geometry2D.intersect_polygons(ring,ribbon).is_empty(), "Science park group covers full road width")
	var space := world.get_world_3d().direct_space_state
	for sample in [["77443",600.0,720.0],["77444",565.0,660.0]]:
		var p := Vector3(float(sample[1]),float(bases[sample[0]])+18.0,float(sample[2]))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.05,p-Vector3.UP*0.05))
		assert(not hit.is_empty() and p.distance_to(hit.position)<0.003, "Registered science park building top missing")
	for sample in [Vector2(560,700),Vector2(630,710)]:
		var p := Vector3(sample.x,float(bases["77443"]),sample.y)
		assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*30,p+Vector3.UP*3)).is_empty(), "Old science park silhouette fills north recess")

func check_houde_clearance(world: Node3D, data: Dictionary, base_y: float) -> void:
	var outline := PackedVector2Array()
	for feature: Dictionary in data.features:
		if feature.id != "77446": continue
		assert(feature.osm_id == "way/233806513" and feature.osm_version == 1)
		for p: Array in feature.points: outline.append(Vector2(p[0],p[1]))
	assert(outline.size() == 4)
	var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/osm_roads.json")).roads
	for ribbon in preload("res://scripts/shared/road_geometry.gd").polygons(roads):
		assert(Geometry2D.intersect_polygons(outline,ribbon).is_empty(), "Houde wall covers the full road width")
	var space := world.get_world_3d().direct_space_state
	var roof := Vector3(612,base_y+24.5,470)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(roof+Vector3.UP*0.05,roof-Vector3.UP*0.05))
	assert(not hit.is_empty() and roof.distance_to(hit.position)<0.003, "Houde building top collision missing")
	for x in [595.0,612.0,630.0]:
		var p := Vector3(float(x),base_y,449)
		assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*30,p+Vector3.UP*3)).is_empty(), "Old Houde north silhouette remains in collision world")

func check_three_beam_clearance(world: Node3D, data: Dictionary, base_y: float) -> void:
	var outline := PackedVector2Array()
	for feature: Dictionary in data.features:
		if feature.id != "77423": continue
		assert(feature.osm_id == "way/233806548" and feature.osm_version == 2)
		for p: Array in feature.points: outline.append(Vector2(p[0], p[1]))
	assert(outline.size() == 6)
	var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/osm_roads.json")).roads
	for ribbon in preload("res://scripts/shared/road_geometry.gd").polygons(roads):
		assert(Geometry2D.intersect_polygons(outline, ribbon).is_empty(), "Three-beam wall overlaps the full road width")
	var space := world.get_world_3d().direct_space_state
	var roof := Vector3(822, base_y+18.0, 200)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(roof+Vector3.UP*0.05, roof-Vector3.UP*0.05))
	assert(not hit.is_empty() and roof.distance_to(hit.position)<0.003, "Three-beam roof collision missing")
	# This north-side road segment crossed the old perspective silhouette.
	for side in [-2.0, 0.0, 2.0]:
		var a := Vector2(832.8565, 171.1656)
		var b := Vector2(800.0, 183.003)
		var normal: Vector2 = (b-a).normalized().orthogonal()*float(side)
		var start := Vector3(a.x+normal.x, base_y+3, a.y+normal.y)
		var end := Vector3(b.x+normal.x, base_y+3, b.y+normal.y)
		assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(start, end)).is_empty(), "Old three-beam collision still obstructs north road")

# Independent structural samples keep the portico local when its host edge grows.
func check_main_portico(world: Node3D, data: Dictionary, base_y: float) -> void:
	var features: Dictionary = {}
	for feature: Dictionary in data.features:
		if feature.id in ["77386", "77395", "77396"]: features[feature.id] = feature
	var main: Dictionary = features["77386"]
	var ring := PackedVector2Array()
	for p in main.points: ring.append(Vector2(p[0], p[1]))
	assert(ring.size() == 20 and main.osm_id == "way/547580516")
	for id in ["77395", "77396"]:
		var neighbor := PackedVector2Array()
		for p in features[id].points: neighbor.append(Vector2(p[0], p[1]))
		assert(Geometry2D.intersect_polygons(ring, neighbor).is_empty(), "Main building overlaps its registered wing")
	var a := ring[13]
	var b := ring[14]
	var direction := (b-a).normalized()
	var outward := Vector2(-direction.y, direction.x)
	assert(not Geometry2D.is_point_in_polygon((a+b)*0.5+outward*0.1, ring))
	var center := a.lerp(b, (0.29466768524405584+0.6865458932330444)*0.5)
	var width := 21.58301933366829
	var space := world.get_world_3d().direct_space_state
	for along in [-width*0.5+0.2, 0.0, width*0.5-0.2]:
		var xz: Vector2 = center+direction*along+outward*1.8
		var p := Vector3(xz.x, base_y+8.375, xz.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.05,p-Vector3.UP*0.05))
		assert(not hit.is_empty() and p.distance_to(hit.position)<0.003, "Main portico roof missing or displaced")
	for along in [-width*0.5-1.0, width*0.5+1.0, -40.0, 40.0]:
		var xz: Vector2 = center+direction*along+outward*1.8
		var p := Vector3(xz.x, base_y+8.375, xz.y)
		assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.05,p-Vector3.UP*0.05)).is_empty(), "Portico stretched across the whole building edge")
	for column in 6:
		var xz: Vector2 = center+direction*((column+0.2)/5.4-0.5)*width+outward*3.4
		var p := Vector3(xz.x,base_y+3.95,xz.y)
		var normal := Vector3(outward.x,0,outward.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+normal*0.1,p-normal*0.1))
		assert(not hit.is_empty() and p.distance_to(hit.position)<0.003, "Registered portico column collision missing")

func check_police_clearance(world: Node3D, data: Dictionary, base_y: float) -> void:
	var outline := PackedVector2Array()
	for feature: Dictionary in data.features:
		if feature.id!="77398":continue
		assert(feature.osm_id=="way/1384296481" and feature.osm_version==2)
		for p: Array in feature.points:outline.append(Vector2(p[0],p[1]))
	assert(outline.size()==6)
	var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/osm_roads.json")).roads
	for ribbon in preload("res://scripts/shared/road_geometry.gd").polygons(roads):
		assert(Geometry2D.intersect_polygons(outline,ribbon).is_empty(),"Police building covers full road width")
	var space := world.get_world_3d().direct_space_state
	var roof := Vector3(303,base_y+8.2,125)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(roof+Vector3.UP*0.05,roof-Vector3.UP*0.05))
	assert(not hit.is_empty() and roof.distance_to(hit.position)<0.003,"Police building top missing")
	for point in [Vector2(317,130),Vector2(309,145)]:
		var p := Vector3(point.x,base_y,point.y)
		assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*20,p+Vector3.UP*3)).is_empty(),"Old police silhouette still fills east setback or south forecourt")
