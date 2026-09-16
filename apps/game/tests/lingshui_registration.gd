extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/campus.json"))
	var model: Node3D = load("res://assets/campuses/lingshui/models/lingshui_campus.tscn").instantiate()
	root.add_child(model)
	var checked := 0
	for feature: Dictionary in data.features:
		if feature.id not in ["29813247","77481","77462","77430","77383","77358","77539","77540","77542","77553","77519","77564","77565","77566","77567","77562","77563","77496","77483","77380","77505","77506","77382","77378","77379","77487","34785233","77509","77356","77387","77412","77413","77416","77427","77429","77431","77439","77441","77461","77499","77504","77507","77508","77510","77511","77512","77513","77514"]: continue
		assert(feature.has("osm_id") and not feature.has("reference_points"))
		if feature.id in ["29813247","77481","77462","77430","77383","77358","77539","77540","77542","77553","77519","77564","77565","77566","77567","77562","77563","77496","77483","77380","77505","77506","77382","77378","77379","77487","34785233","77509","77356","77387","77461","77499","77504","77507","77508","77510","77511","77512","77513","77514"]:
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
		for mesh: MeshInstance3D in group.get_children():
			for vertex: Vector3 in mesh.mesh.get_faces():
				var p := mesh.transform*vertex
				if (mesh.material_override.resource_name=="Lingshui roof" and absf(p.y-float(feature.height)-0.18)<0.001) or (feature.id in ["77430","77540","77542","77553","77519","77499","77504"] and mesh.material_override.resource_name=="Gabled hall roof"):
					roof.append(Vector2(p.x,p.z))
				if feature.id in ["77412","77413"] and mesh.material_override.resource_name=="Window glass" and p.y<3:
					assert(p.z>-228,"Visible ground-floor windows moved away from the south end")
					lower_windows += 1
			if mesh.get_meta("walk_collision",false): preload("res://scripts/shared/campus_collision.gd")._collider(mesh)
		if feature.id in ["77412","77413"]: assert(lower_windows>0)
		for coordinate: Array in feature.points:
			var found := false
			for p in roof:
				if p.distance_to(Vector2(coordinate[0],coordinate[1]))<0.001: found = true
			assert(found,"Saved roof corner differs from the registered source")
		checked += 1
	assert(checked==48)
	await physics_frame
	await physics_frame
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
	print("LINGSHUI REGISTRATION PASS: forty-eight roofs, registered walls and sixty-six residence platform floors and seven gabled roofs")
	quit()
