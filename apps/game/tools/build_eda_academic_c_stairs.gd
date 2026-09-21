extends RefCounted
const Profile=preload("res://tools/eda_stair_profile.gd")
var profile: Dictionary
var terrain
var origin: Vector2
var axis: Vector2
var side: Vector2

func level(station: float) -> float:
	var value:=float(profile.low_landing_y)
	for start: float in profile.flight_starts_m:
		for riser in int(profile.risers_per_flight):
			if station>=start+riser*float(profile.going_m): value+=float(profile.riser_height_m)
	return value

func surface_y(station: float, cross: float, flat: float, walking: bool) -> float:
	var value:=flat
	if walking:
		for i in profile.ramp_ranges_m.size():
			var ramp: Array=profile.ramp_ranges_m[i]
			if station>=float(ramp[0]) and station<=float(ramp[1]):
				var low: float=float(profile.low_landing_y)+i*int(profile.risers_per_flight)*float(profile.riser_height_m)
				value=low+(station-float(ramp[0]))/(float(ramp[1])-float(ramp[0]))*int(profile.risers_per_flight)*float(profile.riser_height_m)
	var p:=Profile.point(profile,station,cross)
	var original: float=terrain.elevation(p.x,p.y)+float(profile.road_lift_m)
	var blend:=float(profile.end_blend_length_m)
	var first:=float(profile.station_range_m[0])
	var last:=float(profile.station_range_m[1])
	if station<first+blend: value=lerpf(original,value,(station-first)/blend)
	if station>last-blend: value=lerpf(value,original,(station-last+blend)/blend)
	return value

func vertex(station: float, cross: float, flat: float, walking: bool) -> Vector3:
	var p:=Profile.point(profile,station,cross)
	return Vector3(p.x,surface_y(station,cross,flat,walking),p.y)

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, vertical:=false) -> void:
	if (c-a).cross(b-a).length_squared()<0.00000000001: return
	var vertices: Array[Vector3]=[a,b,c]
	if (c-a).cross(b-a).dot(outward)<0: vertices.reverse()
	for v in vertices:
		var d:=Vector2(v.x,v.z)-origin
		st.set_uv(Vector2(d.dot(axis)-3.2,v.y if vertical else d.dot(side)))
		st.add_vertex(v)

func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward:=Vector3.UP, vertical:=false) -> void:
	triangle(st,a,b,c,outward,vertical)
	triangle(st,a,c,d,outward,vertical)

func cross_cuts(station: float) -> Array[float]:
	var half:=float(profile.width_m)/2
	var result: Array[float]=[-half,half]
	var p:=Profile.point(profile,station,0)
	var grid:=Vector2(terrain.data.origin_xz[0],terrain.data.origin_xz[1])
	var step:=float(terrain.data.step_m)
	# Include exact original triangle-grid crossings at full-width end ties.
	for triple in [[p.x-grid.x,side.x],[p.y-grid.y,side.y],[p.x+p.y-grid.x-grid.y,side.x+side.y]]:
		var slope:=float(triple[1])
		if absf(slope)<0.00001: continue
		var base:=float(triple[0])
		var lo:=mini(floori((base-half*slope)/step),floori((base+half*slope)/step))
		var hi:=maxi(ceili((base-half*slope)/step),ceili((base+half*slope)/step))
		for i in range(lo,hi+1):
			var u: float=(i*step-base)/slope
			if u>-half+0.00001 and u<half-0.00001: result.append(u)
	result.sort()
	return result

func patch(st: SurfaceTool, start: float, end: float, flat: float, walking: bool) -> void:
	# Interior landings and each bounded ramp are planar. Extra strips only add
	# coincident physics seams; subdivision is needed solely for terrain end ties.
	if start>=float(profile.station_range_m[0])+float(profile.end_blend_length_m)-0.00001 and end<=float(profile.station_range_m[1])-float(profile.end_blend_length_m)+0.00001:
		var half:=float(profile.width_m)/2
		quad(st,vertex(start,-half,flat,walking),vertex(end,-half,flat,walking),vertex(end,half,flat,walking),vertex(start,half,flat,walking))
		return
	var count:=maxi(1,ceili((end-start)/0.25))
	for i in count:
		var a:=lerpf(start,end,float(i)/count)
		var b:=lerpf(start,end,float(i+1)/count)
		var cuts:=cross_cuts(a)
		cuts.append_array(cross_cuts(b))
		cuts.sort()
		for j in cuts.size()-1:
			if cuts[j+1]-cuts[j]<0.00001: continue
			quad(st,vertex(a,cuts[j],flat,walking),vertex(b,cuts[j],flat,walking),vertex(b,cuts[j+1],flat,walking),vertex(a,cuts[j+1],flat,walking))

func side_support(st: SurfaceTool, start: float, end: float, flat: float) -> void:
	var count:=maxi(1,ceili((end-start)/0.20))
	for sign_side: float in [-1.0,1.0]:
		var cross:=sign_side*float(profile.width_m)/2
		var stations: Array[float]=[]
		for i in count+1: stations.append(lerpf(start,end,float(i)/count))
		var p:=Profile.point(profile,0,cross)
		var grid:=Vector2(terrain.data.origin_xz[0],terrain.data.origin_xz[1])
		var step:=float(terrain.data.step_m)
		for pair in [[p.x-grid.x,axis.x],[p.y-grid.y,axis.y],[p.x+p.y-grid.x-grid.y,axis.x+axis.y]]:
			var slope:=float(pair[1])
			if absf(slope)<0.00001: continue
			var base:=float(pair[0])
			var lo:=mini(floori((base+start*slope)/step),floori((base+end*slope)/step))
			var hi:=maxi(ceili((base+start*slope)/step),ceili((base+end*slope)/step))
			for i in range(lo,hi+1):
				var station: float=(i*step-base)/slope
				if station>start+0.00001 and station<end-0.00001: stations.append(station)
		stations.sort()
		for i in stations.size()-1:
			if stations[i+1]-stations[i]<0.00001: continue
			var a:=vertex(stations[i],cross,flat,false)
			var b:=vertex(stations[i+1],cross,flat,false)
			var ga:=Vector3(a.x,terrain.elevation(a.x,a.z)+float(profile.side_ground_lift_m),a.z)
			var gb:=Vector3(b.x,terrain.elevation(b.x,b.z)+float(profile.side_ground_lift_m),b.z)
			var outward:=Vector3(side.x,0,side.y)*sign_side
			# Split where the supported path passes through the existing grade.
			var da:=a.y-ga.y
			var db:=b.y-gb.y
			if da*db<0:
				var middle:=a.lerp(b,da/(da-db))
				triangle(st,a,middle,ga,outward*signf(da),true)
				triangle(st,middle,b,gb,outward*signf(db),true)
			else:
				quad(st,a,b,gb,ga,outward*(1.0 if da+db>=0 else -1.0),true)

func mesh(host, st: SurfaceTool, mat: Material, label: String, collision: bool, visible: bool) -> MeshInstance3D:
	st.index()
	st.generate_normals()
	var node: MeshInstance3D=host.mesh_node(host.scene,st.commit(),mat,label)
	node.set_meta("walk_collision",collision)
	node.set_meta("dimensions_are_estimated",true)
	node.visible=visible
	return node

func build(host) -> void:
	profile=Profile.load_profile()
	terrain=preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	origin=Profile.point(profile,0,0)
	axis=(Profile.point(profile,1,0)-origin).normalized()
	side=Vector2(-axis.y,axis.x)
	for pair in [[profile.station_range_m[0],profile.low_landing_y],[profile.station_range_m[1],profile.high_landing_y]]:
		var p:=Profile.point(profile,float(pair[0]),0)
		assert(absf(terrain.elevation(p.x,p.y)+float(profile.road_lift_m)-float(pair[1]))<0.002,"Stair endpoint grade changed")
	var visual:=SurfaceTool.new()
	var support:=SurfaceTool.new()
	var walk:=SurfaceTool.new()
	for st in [visual,support,walk]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)
	var first:=float(profile.station_range_m[0])
	var last:=float(profile.station_range_m[1])
	var cuts: Array[float]=[first,first+float(profile.end_blend_length_m),last-float(profile.end_blend_length_m),last]
	for start: float in profile.flight_starts_m:
		for i in int(profile.risers_per_flight): cuts.append(start+i*float(profile.going_m))
	cuts.sort()
	for i in cuts.size()-1:
		var flat:=level((cuts[i]+cuts[i+1])/2)
		patch(visual,cuts[i],cuts[i+1],flat,false)
		side_support(support,cuts[i],cuts[i+1],flat)
	var half:=float(profile.width_m)/2
	for start: float in profile.flight_starts_m:
		for i in int(profile.risers_per_flight):
			var station:=start+i*float(profile.going_m)
			var low:=level(station-0.0001)
			var high:=level(station+0.0001)
			quad(visual,vertex(station,-half,low,false),vertex(station,half,low,false),vertex(station,half,high,false),vertex(station,-half,high,false),Vector3(-axis.x,0,-axis.y),true)
	var walk_cuts: Array[float]=[first,first+float(profile.end_blend_length_m),last-float(profile.end_blend_length_m),last]
	for ramp: Array in profile.ramp_ranges_m: walk_cuts.append(float(ramp[0]));walk_cuts.append(float(ramp[1]))
	walk_cuts.sort()
	for i in walk_cuts.size()-1: patch(walk,walk_cuts[i],walk_cuts[i+1],level((walk_cuts[i]+walk_cuts[i+1])/2),true)
	var finish:=preload("res://tools/eda_surface_details.gd").new()
	mesh(host,visual,finish.ground_material("EDA C stair stone",Color(0.26,0.27,0.25).linear_to_srgb(),7),"AcademicCStairStone",false,true)
	mesh(host,support,finish.ground_material("EDA C stair side support",Color(0.28,0.29,0.27).linear_to_srgb(),7),"AcademicCStairSupport",true,true)
	mesh(host,walk,host.material("EDA C stair walk collision",Color.WHITE),"AcademicCStairWalkCollision",true,false)
