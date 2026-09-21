extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")
# Independent sample locations in the shared WGS84 campus frame.
const SAMPLES := [["2304982",Vector2(395,145),62.4],["2304982",Vector2(422,120),62.4],["2304982",Vector2(365,100),8.2],["2304982",Vector2(405,95),8.2],["2304982",Vector2(385,117),12.3],["77937",Vector2(400,35),20.05],["77938",Vector2(450,45),20.05]]

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var features: Dictionary = {}
	for feature: Dictionary in manifest.features: features[feature.id] = feature
	var bases: Dictionary = {}
	var reference: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	for id in ["2304982","77937","77938","77941"]: bases[id] = reference.get_node("Feature_"+id).position.y
	reference.free()
	var seventh_base: float = bases["2304982"]
	assert(features["2304982"].building_parts[0].osm_id=="way/375541049" and int(features["2304982"].building_parts[0].osm_version)==6)
	for source in [["77937","way/309375780"],["77938","way/309375781"],["77941","way/375541046"]]:
		assert(features[source[0]].osm_id==source[1] and int(features[source[0]].osm_version)==4)
	for server in [false,true]:
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		root.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		if server:
			world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(model)
			var seventh := model.get_node("Feature_2304982")
			# Four existing materials plus shared backing and blade batches.
			assert(seventh.get_child_count()<=6)
			var west_start := Vector2(360.492118,121.294272)
			var west_end := Vector2(354.771941,141.554512)
			var west_axis := (west_end-west_start).normalized()
			var west_out := Vector2(-west_axis.y,west_axis.x)
			for node: MeshInstance3D in seventh.get_children():
				if not node.material_override.resource_name.begins_with("Seventh end "): continue
				assert(not node.get_meta("walk_collision",false),"Endwall louvers must remain decorative")
				for vertex: Vector3 in node.mesh.get_faces():
					var point := node.transform*vertex
					var delta := Vector2(point.x,point.z)-west_start
					assert(delta.dot(west_axis)>0 and delta.dot(west_axis)<west_start.distance_to(west_end),"Louvers left the west end span")
					# The shared metal batch includes window frames reaching 0.175 m.
					assert(delta.dot(west_out)>0.015 and delta.dot(west_out)<0.19,"Louvers moved off the west end wall")
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for sample in SAMPLES:
			var pos: Vector2 = sample[1]
			var base: float = bases[sample[0]]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,base+80,pos.y),Vector3(pos.x,base-1,pos.y)))
			assert(not hit.is_empty(),"Missing roof at "+str(pos))
			assert(absf(hit.position.y-base-float(sample[2]))<0.03,"Wrong roof height at "+str(pos)+": "+str(hit.position))
		# Check each tower rim independently: the roof is lower, the wall keeps the official top.
		var tower := PackedVector2Array()
		for p: Array in features["2304982"].building_parts[0].points: tower.append(Vector2(p[0],p[1]))
		assert(tower.size()==9,"Seventh tower must preserve all nine OSM source corners")
		for edge in tower.size():
			var a := tower[edge]
			var b := tower[(edge+1)%tower.size()]
			var middle := (a+b)/2
			var inward := Vector2(-(b-a).y,(b-a).x).normalized()
			if not Geometry2D.is_point_in_polygon(middle+inward,tower): inward = -inward
			var pos := middle+inward*0.15
			var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,seventh_base+66,pos.y),Vector3(pos.x,seventh_base+61,pos.y)))
			assert(not top.is_empty() and absf(top.position.y-seventh_base-63.6)<0.03,"Missing tower parapet top")
			var outside := middle-inward
			var inside := middle+inward
			var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(outside.x,seventh_base+63,outside.y),Vector3(inside.x,seventh_base+63,inside.y)))
			assert(not side.is_empty() and Vector2(side.position.x,side.position.z).distance_to(middle)<0.03,"Missing tower parapet side")
		# Towers 4/5 follow their photographed facade; tower 6 follows the west end wall.
		for spec in [["77937",4,false,0.9,23.0],["77938",1,true,0.14,23.0],["77941",3,false,0.5,25.5]]:
			var points: Array = features[spec[0]].points
			var first: Array = points[int(spec[1])]
			var last: Array = points[(int(spec[1])+1)%points.size()]
			var a := Vector2(first[0],first[1])
			var b := Vector2(last[0],last[1])
			if spec[2]:
				var old_a := a
				a = b
				b = old_a
			var ring := PackedVector2Array()
			for p: Array in points: ring.append(Vector2(p[0],p[1]))
			var out := Vector2((b-a).y,-(b-a).x).normalized()
			if Geometry2D.is_point_in_polygon((a+b)*0.5+out,ring): out = -out
			var front := a.lerp(b,float(spec[3]))
			var center := front-out*2.05
			var base: float = bases[spec[0]]
			var height: float = spec[4]
			var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(center.x,base+height+3,center.y),Vector3(center.x,base+height-1,center.y)))
			assert(not top.is_empty() and absf(top.position.y-base-height)<0.03,"Missing raised stair tower: "+str(spec[0]))
			var outside := front+out*2
			var inside := front-out
			var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(outside.x,base+height-2,outside.y),Vector3(inside.x,base+height-2,inside.y)))
			assert(not side.is_empty() and Vector2(side.position.x,side.position.z).distance_to(front+out*0.2)<0.03,"Stair tower must remain closed: "+str(spec[0]))
		# Both photographed raised-roof parapets block horizontally and have a top.
		# Reviewed raised-roof north and east edges, independent of generated mesh vertices.
		for segment in [[Vector2(372.948116,101.855957),Vector2(411.642565,112.225166)],[Vector2(411.642565,112.225166),Vector2(405.948001,133.475389)]]:
			var a: Vector2 = segment[0]
			var b: Vector2 = segment[1]
			var axis := (b-a).normalized()
			var inward := Vector2(-axis.y,axis.x)
			var middle := (a+b)*0.5
			var top_pos := middle+inward*0.125
			var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(top_pos.x,seventh_base+14,top_pos.y),Vector3(top_pos.x,seventh_base+12,top_pos.y)))
			assert(not top.is_empty() and absf(top.position.y-seventh_base-12.85)<0.03,"Missing raised-roof parapet top")
			var outside := middle-inward
			var inside := middle+inward
			var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(outside.x,seventh_base+12.55,outside.y),Vector3(inside.x,seventh_base+12.55,inside.y)))
			assert(not side.is_empty() and Vector2(side.position.x,side.position.z).distance_to(middle)<0.03,"Missing raised-roof parapet side")
		# Seventh residence exterior remains closed at ground level.
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(375,seventh_base+1.7,70),Vector3(375,seventh_base+1.7,90)))
		assert(not wall.is_empty() and wall.position.z>75 and wall.position.z<85,"Podium exterior must block walking")
		print("Height/roof checks passed for ","saved server" if server else "client collision",", seventh base=",seventh_base)
		world.free()
		viewport.free()
	print("PASS: client/server seventh residence 63.6m tower rim and 62.4m recessed roof, 8.2m low podium, 12.3m raised podium with 12.85m parapets, lower dormitories 4/5, raised stair towers 4/5/6 and closed exterior")
	quit()
