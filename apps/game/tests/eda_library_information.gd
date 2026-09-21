extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")
var envelope: Dictionary
var curve_reference

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/buildings/library_information_profiles.json"))
	envelope = profiles["77917"].osm_registration.rotunda_envelope
	var reference: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	var info_base: float = reference.get_node("Feature_77914").position.y
	var library_base: float = reference.get_node("Feature_77917").position.y
	check_wing_glazing(reference.get_node("Feature_77917"))
	reference.free()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var info := PackedVector2Array()
	var library := PackedVector2Array()
	for f in manifest.features:
		if f.id=="77914":
			assert(is_equal_approx(float(f.height),17.6))
			for p in f.points: info.append(Vector2(p[0],p[1]))
		if f.id=="77917":
			assert(is_equal_approx(float(f.height),22.0))
			for p in f.points: library.append(Vector2(p[0],p[1]))
	assert(info.size()==12 and library.size()==39)
	var old_envelope := preload("res://tools/build_eda_library_rotunda.gd").new()
	old_envelope.configure(library,envelope)
	curve_reference=preload("res://tools/eda_ellipse_envelope.gd").new()
	curve_reference.configure(library,profiles["77917"].osm_registration.curve_refinement,old_envelope)
	# Registered long-wing north edge; source-defined fractions preserve the
	# photo frame while permitting a changed origin and rotated source wall.
	var axis := (info[5]-info[4]).normalized()
	var inward := Vector2(-axis.y,axis.x)
	assert(Geometry2D.is_point_in_polygon((info[4]+info[5])/2+inward,info))
	var first := info[4].lerp(info[5],0.04)+inward*5.0
	var last := info[4].lerp(info[5],0.975)+inward*5.0

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
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		check_ellipse_perimeter(space,library_base)
		var end_axis := (info[7]-info[6]).normalized()
		var end_out := Vector2(end_axis.y,-end_axis.x)
		for distance: float in [2.0,5.0,8.0]:
			var p := info[6]+end_axis*distance
			var start := p+end_out*1.0
			var finish := p-end_out*2.0
			var wall_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(start.x,info_base+2,start.y),Vector3(finish.x,info_base+2,finish.y)))
			assert(not wall_hit.is_empty() and Vector2(wall_hit.position.x,wall_hit.position.z).distance_to(p)<0.01,"East ground facade must be closed at the registered wall")
			var capsule := CapsuleShape3D.new()
			capsule.radius=0.35
			capsule.height=1.8
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape=capsule
			query.transform=Transform3D(Basis.IDENTITY,Vector3(start.x,info_base+1.0,start.y))
			query.motion=Vector3(-end_out.x,0,-end_out.y)*3.0
			var travel := space.cast_motion(query)[0]
			assert(travel>0.15 and travel<0.25,"Character can enter the removed east portico")
		print("INFORMATION EAST BASE PASS server=",server," three closed-wall rays and blocked capsule routes")
		for sample in [[Vector2(50,485),info_base+17.82],[Vector2(-40,485),info_base+17.82],[Vector2(106,360),library_base+22.22],[Vector2(64,360),library_base+32.24],[Vector2(90,425),library_base+17.82],[Vector2(90,451),library_base+13.42]]:
			var pos: Vector2 = sample[0]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,50,pos.y),Vector3(pos.x,0,pos.y)))
			assert(not hit.is_empty())
			assert(absf(hit.position.y-float(sample[1]))<0.02,"Body roof must match declared scale")
		# Information roof beams remain open between spans, with solid supports.
		for sample in [[first.lerp(last,0.5)+inward*4.25,info_base+20.02],[first.lerp(last,0.0625)+inward*4.25,info_base+17.82]]:
			var pos: Vector2 = sample[0]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,info_base+25,pos.y),Vector3(pos.x,info_base+17,pos.y)))
			assert(not hit.is_empty() and absf(hit.position.y-float(sample[1]))<0.02,"Roof frame beam or open bay is incorrect")
		var near := first-inward*2
		var far := first+inward*2
		var roof_column := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(near.x,info_base+18.8,near.y),Vector3(far.x,info_base+18.8,far.y)))
		assert(not roof_column.is_empty(),"Missing roof frame support")
		var front := first-inward*0.25
		assert(Vector2(roof_column.position.x,roof_column.position.z).distance_to(front)<0.025)
		near += axis*0.22
		far += axis*0.22
		var round_side := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(near.x,info_base+18.8,near.y),Vector3(far.x,info_base+18.8,far.y)))
		assert(not round_side.is_empty(),"Missing off-axis round support")
		var depth: float = (Vector2(round_side.position.x,round_side.position.z)-first).dot(inward)
		assert(depth>-0.15 and depth< -0.07,"Roof support must retain its round section")
		# Both registered ground setbacks stay open above terrain; an outer
		# rectangle or the former oblique silhouette would incorrectly fill them.
		for p: Vector2 in [Vector2(-8,466),Vector2(-8,497)]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,info_base+25,p.y),Vector3(p.x,info_base+3,p.y)))
			assert(hit.is_empty(),"Information-building setback filled")
		# The six registered broad fins begin above the unchanged lower facade.
		# Check their actual front faces at two heights, not the retired mid-edge columns.
		assert(envelope.fin_stations.size()==6)
		for station: Dictionary in envelope.fin_stations:
			var edge := int(station.edge)
			var out := envelope_outward(library,edge)
			var at := library[edge].lerp(library[edge+1],float(station.fraction))
			var front_at := at+out*(0.33+float(station.depth))
			for y in [11.0,20.0]:
				var expected := envelope_position(library,Vector3(front_at.x,y,front_at.y))+Vector3(0,library_base,0)
				var normal := Vector3(out.x,0,out.y)
				var column := space.intersect_ray(PhysicsRayQueryParameters3D.create(expected+normal*0.2,expected-normal*0.2))
				assert(not column.is_empty(),"Missing upper radial fin")
				assert(column.position.distance_to(expected)<0.02,"Upper radial fin front must follow the shared envelope")
		var out := envelope_outward(library,20)
		var mid := (library[20]+library[21])/2
		var ring_at := mid+out*1.3
		var ring_pos := envelope_position(library,Vector3(ring_at.x,24.0,ring_at.y))
		var ring := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(ring_pos.x,library_base+30,ring_pos.z),Vector3(ring_pos.x,library_base+23,ring_pos.z)))
		assert(not ring.is_empty() and absf(ring.position.y-library_base-24.14)<0.02,"Missing raised ring")
		# Samples straddle each shared ring corner, where independent offset
		# boxes previously left visible gaps. Check both exposed faces.
		var ring_edges := PackedInt32Array([2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,31,32,33,34,35,36])
		var ring_builder := preload("res://tools/build_eda_library_ring.gd").new()
		for vertex in ring_edges:
			var previous := (vertex-1+library.size())%library.size()
			if not previous in ring_edges: continue
			var joint := ring_builder.corner(library,ring_edges,vertex,vertex,1.3)
			for adjacent in [previous,vertex]:
				var edge_mid := (library[adjacent]+library[(adjacent+1)%library.size()])/2+ring_builder.outward(library,adjacent)*1.3
				var p := joint.move_toward(edge_mid,0.025)
				var moved := envelope_position(library,Vector3(p.x,24.0,p.y))
				var above := Vector3(moved.x,library_base+25,moved.z)
				var below := Vector3(moved.x,library_base+23,moved.z)
				var top_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(above,below))
				var bottom_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(below,above))
				assert(not top_hit.is_empty() and absf(top_hit.position.y-library_base-24.14)<0.01,"Ring corner top gap")
				assert(not bottom_hit.is_empty() and absf(bottom_hit.position.y-library_base-23.86)<0.01,"Ring corner underside gap")
		print("LIBRARY RING PASS server=",server," joined corners and downward underside")
		check_roof_members(space,library,library_base)
		assert(await check_connector(world,space,library,library_base),"Connector gallery traversal")
		print("INFORMATION/LIBRARY PASS: server=",server," shared frame, setbacks, roof frame, round column, library wings/ring")
		world.free()
		viewport.free()
	print("PASS: information/library declared heights, lower library wing, roofs, open roof frame, upper radial fins and ring")
	quit()

func check_roof_members(space: PhysicsDirectSpaceState3D, points: PackedVector2Array, base: float) -> void:
	var lengths: Array[float] = []
	var total := 0.0
	for edge in range(8,19):
		lengths.append(points[edge].distance_to(points[edge+1]))
		total+=lengths[-1]
	# Eighteen cross members and the seventeen open bays between them.
	for sample in 35:
		var distance := total*(sample+1)/36.0
		var index := 0
		while distance>lengths[index]:
			distance-=lengths[index]
			index+=1
		var edge := index+8
		var axis := (points[edge+1]-points[edge]).normalized()
		var out := Vector2(axis.y,-axis.x)
		var mid := (points[edge]+points[edge+1])/2
		if Geometry2D.is_point_in_polygon(mid+out,points): out=-out
		var p := points[edge].lerp(points[edge+1],distance/lengths[index])-out*0.2
		var moved := envelope_position(points,Vector3(p.x,24.0,p.y))
		var above := Vector3(moved.x,base+24.3,moved.z)
		var below := Vector3(moved.x,base+23.5,moved.z)
		var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(above,below))
		var bottom := space.intersect_ray(PhysicsRayQueryParameters3D.create(below,above))
		if sample%2==0:
			assert(not top.is_empty() and absf(top.position.y-base-23.98)<0.01,"Missing roof cross member top")
			assert(not bottom.is_empty() and absf(bottom.position.y-base-23.82)<0.01,"Missing roof cross member underside")
			var inner := p-out*0.4
			var expected := envelope_position(points,Vector3(inner.x+axis.x*0.09,23,inner.y+axis.y*0.09))+Vector3(0,base,0)
			# A straight physics ray through two mapped endpoints need not cross
			# the mapped intermediate point of a nonlinear curve. Aim through it.
			var probe_axis := Vector3(axis.x,0,axis.y)
			var from := expected+probe_axis*0.2
			var to := expected-probe_axis*0.2
			var support := space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to))
			assert(not support.is_empty(),"Missing inner roof support sample=%d edge=%d from=%s to=%s expected=%s" % [sample,edge,from,to,expected])
			assert(support.position.distance_to(expected)<0.01,"Inner roof support mismatch sample=%d edge=%d error=%f actual=%s expected=%s normal=%s" % [sample,edge,support.position.distance_to(expected),support.position,expected,support.normal])
		else:
			assert(top.is_empty() and bottom.is_empty(),"Roof bay must remain open")
	print("LIBRARY CROSS MEMBERS PASS: 18 beams/supports and 17 open bays, 88 rays")

func check_wing_glazing(group: Node3D) -> void:
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var ring:=PackedVector2Array()
	for feature in manifest.features:
		if feature.id=="77917":
			for p in feature.points:ring.append(Vector2(p[0],p[1]))
	var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/buildings/library_information_profiles.json"))["77917"].osm_registration
	var old_envelope:=preload("res://tools/build_eda_library_rotunda.gd").new()
	old_envelope.configure(ring,profile.rotunda_envelope)
	var curve:=preload("res://tools/eda_ellipse_envelope.gd").new()
	curve.configure(ring,profile.curve_refinement,old_envelope)
	var buckets:Dictionary={}
	for child in group.get_children():
		if not child is MeshInstance3D:continue
		var west:bool=child.material_override.resource_name.begins_with("Library west glazing")
		if not west and not child.material_override.resource_name.begins_with("Photo glazing"):continue
		var faces:PackedVector3Array=child.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var tri:Array[Vector3]=[child.transform*faces[i],child.transform*faces[i+1],child.transform*faces[i+2]]
			var low:=tri[0].min(tri[1]).min(tri[2])/4.0
			var high:=tri[0].max(tri[1]).max(tri[2])/4.0
			for x in range(floori(low.x),floori(high.x)+1):
				for y in range(floori(low.y),floori(high.y)+1):
					for z in range(floori(low.z),floori(high.z)+1):
						var key:=str(west)+str(Vector3i(x,y,z))
						if not buckets.has(key):buckets[key]=[]
						buckets[key].append(tri)
	var checked:=0
	for west in [false,true]:
		var regions:Array=profile.west_facade.windows if west else profile.wing_window_regions
		for region in regions:
			var edge:=int(region.edge)
			var a:=ring[edge];var b:=ring[(edge+1)%ring.size()]
			var normal:=envelope_outward(ring,edge)
			var count:=int(region.bays if west else region.columns)
			for y in region.centers_y:
				for bay in count:
					var fraction:=lerpf(float(region.span[0]),float(region.span[1]),(bay+0.5)/count)
					var at:=a.lerp(b,fraction)+normal*(0.14 if west else 0.16)
					var point:=Vector3(at.x,float(y),at.y)
					point+=old_envelope.displacement(point)
					point+=curve.shift(point)
					var key:=str(west)+str(Vector3i(floori(point.x/4),floori(point.y/4),floori(point.z/4)))
					var covered:=false
					for tri in buckets.get(key,[]):
						var n:Vector3=(tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
						if n.dot(Vector3(normal.x,0,normal.y))<0.98:continue
						var distance:float=n.dot(point-tri[0])
						if absf(distance)>0.005:continue
						var u:Vector3=tri[1]-tri[0];var v:Vector3=tri[2]-tri[0];var w:Vector3=point-n*distance-tri[0]
						var denominator:=u.dot(u)*v.dot(v)-u.dot(v)*u.dot(v)
						if absf(denominator)<0.000000001:continue
						var first:float=(w.dot(u)*v.dot(v)-w.dot(v)*u.dot(v))/denominator
						var second:float=(w.dot(v)*u.dot(u)-w.dot(u)*u.dot(v))/denominator
						if first>=-0.001 and second>=-0.001 and first+second<=1.001:covered=true;break
					assert(covered,"Missing or inward library wing glass panel "+str([west,edge,y,bay]))
					checked+=1
	assert(checked==31)
	print("LIBRARY WING GLAZING PASS: all twelve east and nineteen west panels survive subdivision and face outward")

func check_connector(world: Node3D, space: PhysicsDirectSpaceState3D, points: PackedVector2Array, base: float) -> bool:
	for face in [[1,0.015,0.325,4],[38,0.475,0.985,7]]:
		var a := points[int(face[0])]
		var b := points[(int(face[0])+1)%points.size()]
		var axis := (b-a).normalized()
		var out := Vector2(axis.y,-axis.x)
		if Geometry2D.is_point_in_polygon((a+b)/2+out,points): out=-out
		var first := a.lerp(b,face[1])
		var last := a.lerp(b,face[2])
		for fraction in [0.15,0.5,0.85]:
			var p := first.lerp(last,fraction)-out*1.3
			for pair in [[10.0,8.0,8.8],[14.0,12.0,13.42],[12.0,14.0,13.2]]:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,base+pair[0],p.y),Vector3(p.x,base+pair[1],p.y)))
				assert(not hit.is_empty() and absf(hit.position.y-base-pair[2])<0.015,"Connector floor or roof face missing")
			var back := p-out*2
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,base+10,p.y),Vector3(back.x,base+10,back.y)))
			assert(not hit.is_empty() and absf(hit.position.distance_to(Vector3(p.x,base+10,p.y))-0.9)<0.02,"Gallery rear must remain closed")
		var count := int(face[3])
		for i in count:
			var p := first.lerp(last,(i+0.2)/(count-0.6))
			var end := p-out
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,base+11,p.y),Vector3(end.x,base+11,end.y)))
			assert(not hit.is_empty() and absf(hit.position.distance_to(Vector3(p.x,base+11,p.y))-0.18)<0.02,"Gallery circular column missing")
			assert(hit.normal.dot(Vector3(out.x,0,out.y))>0.98,"Gallery column faces inward")
		var player := CharacterBody3D.new()
		player.floor_snap_length=0.45
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius=0.3;capsule.height=1.8;shape.shape=capsule
		player.add_child(shape);world.add_child(player)
		var start := first.lerp(last,0.15)-out*1.3
		var finish := first.lerp(last,0.85)-out*1.3
		player.position=Vector3(start.x,base+9.72,start.y)
		var arrived := false
		for i in 720:
			await physics_frame
			var delta := Vector3(finish.x,player.position.y,finish.y)-player.position
			if delta.length()<0.1: arrived=true;break
			player.velocity=delta.normalized()*4+Vector3(0,-2,0)
			player.move_and_slide()
			assert(absf(player.position.y-base-9.7)<0.06,"Gallery walking floor dropped")
		player.free()
		if not arrived: return false
	print("LIBRARY CONNECTOR PASS: two gallery routes, closed backs, roof top/underside and eleven outward columns")
	return true

# Independently compute the registered miter offsets and height interpolation.
# This intentionally does not invoke the model generator's deformation helper.
func envelope_outward(points: PackedVector2Array, edge: int) -> Vector2:
	var a := points[edge]
	var b := points[(edge+1)%points.size()]
	var result := Vector2((b-a).y,-(b-a).x).normalized()
	return -result if Geometry2D.is_point_in_polygon((a+b)/2+result,points) else result

func envelope_position(points: PackedVector2Array, position: Vector3) -> Vector3:
	var factor := clampf((position.y-float(envelope.start_y))/(float(envelope.top_y)-float(envelope.start_y)),0.0,1.0)
	if is_zero_approx(factor): return position
	var at := Vector2(position.x,position.z)
	var nearest := INF
	var offset := Vector2.ZERO
	for edge in points.size():
		var next := (edge+1)%points.size()
		var line := points[next]-points[edge]
		var fraction := clampf((at-points[edge]).dot(line)/line.length_squared(),0.0,1.0)
		var distance := at.distance_squared_to(points[edge]+line*fraction)
		if distance>=nearest: continue
		nearest=distance
		var ends: Array[Vector2] = []
		for vertex in [edge,next]:
			var normal := envelope_outward(points,vertex)
			var bisector := (envelope_outward(points,(vertex-1+points.size())%points.size())+normal).normalized()
			var weight := float(envelope.vertex_weights.get(str(vertex),0.0))
			ends.append(bisector*float(envelope.top_outset)*weight/maxf(0.5,bisector.dot(normal)))
		offset=ends[0].lerp(ends[1],fraction)
	var moved := position+Vector3(offset.x,0,offset.y)*factor
	# Existing structural tests retain their exact heights/gaps/tolerances at the
	# same registered stations, now mapped into the curved facade coordinate field.
	return moved+curve_reference.shift(moved)

func check_ellipse_perimeter(space: PhysicsDirectSpaceState3D, base: float) -> void:
	var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/buildings/library_information_profiles.json"))["77917"].osm_registration.curve_refinement.ellipse
	var center:=Vector2(profile.center_xz[0],profile.center_xz[1])
	var radii:=Vector2(profile.radii_m[0],profile.radii_m[1])
	for sample in 120:
		var angle:=TAU*sample/120.0
		var direction:=Vector2(cos(angle),sin(angle))
		var p:=center+(radii*direction).rotated(float(profile.rotation_rad))
		var roof:=center+((radii+Vector2.ONE*2.4)*direction*0.97).rotated(float(profile.rotation_rad))
		var cap:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(roof.x,base+23,roof.y),Vector3(roof.x,base+21,roof.y)))
		assert(not cap.is_empty(),"Complete library ellipse has a roof gap")
		if p.x<76 or (p.y>378 and p.x<110):continue
		var normal:Vector2=(direction/radii).rotated(float(profile.rotation_rad)).normalized()
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x+normal.x*3,base+6,p.y+normal.y*3),Vector3(p.x-normal.x,base+6,p.y-normal.y)))
		assert(not hit.is_empty(),"Library ellipse exterior has a gap")
		assert(Vector2(hit.position.x,hit.position.z).distance_to(p)<0.04,"Library retains an indented mapped contour")
		assert(Vector2(hit.normal.x,hit.normal.z).normalized().dot(normal)>.985,"Library ellipse normal mismatch")
	print("LIBRARY ELLIPSE PASS: analytical exposed perimeter and complete roof coverage")
