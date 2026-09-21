extends RefCounted

# Bounded cubic interpolation between registered controls, not a new footprint fit.
var outline: PackedVector2Array
var edges: PackedInt32Array
var settings: Dictionary
var envelope
var shift_cache: Dictionary = {}
var control_cache: Dictionary = {}
var material_cache: Dictionary = {}
var bezier_cache: Dictionary = {}

func configure(points: PackedVector2Array, profile: Dictionary, upper_envelope = null) -> void:
	outline=points
	edges=PackedInt32Array(profile.edges)
	settings=profile
	envelope=upper_envelope

func control(index: int, y: float) -> Vector2:
	index=posmod(index,outline.size())
	var key := Vector2(index,y)
	if control_cache.has(key): return control_cache[key]
	var p := outline[index]
	if envelope != null:
		var d: Vector3 = envelope.displacement(Vector3(p.x,y,p.y))
		p+=Vector2(d.x,d.z)
	control_cache[key]=p
	return p

func tangent(vertex: int, y: float) -> Vector2:
	var p := control(vertex,y)
	var before := p-control(vertex-1,y)
	var after := control(vertex+1,y)-p
	if posmod(vertex-1,outline.size()) not in edges: return after.normalized()
	if vertex not in edges: return before.normalized()
	var direction := (before.normalized()+after.normalized()).normalized()
	# Keep coordinate extrema at registered controls, including the original envelope.
	if before.x*after.x<=0.0: direction.x=0.0
	if before.y*after.y<=0.0: direction.y=0.0
	return direction.normalized()

func shift(at: Vector3) -> Vector3:
	if shift_cache.has(at): return shift_cache[at]
	var value := evaluate_shift(at)
	shift_cache[at]=value
	return value

func evaluate_shift(at: Vector3) -> Vector3:
	var p := Vector2(at.x,at.z)
	var weighted := Vector2.ZERO
	var total := 0.0
	for edge in outline.size():
		var a := control(edge,at.y)
		var b := control(edge+1,at.y)
		var t := clampf((p-a).dot(b-a)/(b-a).length_squared(),0.0,1.0)
		var distance := p.distance_squared_to(a.lerp(b,t))
		var delta := Vector2.ZERO
		if edge in edges and distance<20.25:
			delta=curve_delta(edge,t,at.y)*(1.0-smoothstep(2.5,4.5,sqrt(distance)))
		# On a registered chord interpolation is exact. Off it, all neighbouring
		# edge fields blend continuously instead of switching at Voronoi seams.
		if distance<0.000000000001: return Vector3(delta.x,0,delta.y)
		var weight := 1.0/(distance*distance)
		weighted+=delta*weight
		total+=weight
	weighted/=total
	return Vector3(weighted.x,0,weighted.y)

func curve_delta(edge: int, fraction: float, y: float) -> Vector2:
	var key := Vector2(edge,y)
	if not bezier_cache.has(key):
		var a := control(edge,y)
		var b := control(edge+1,y)
		var handle := a.distance_to(b)/3.0
		var c := a+tangent(edge,y)*handle
		var d := b-tangent((edge+1)%outline.size(),y)*handle
		var low := control(0,y)
		var high := low
		for i in outline.size():
			low=low.min(control(i,y))
			high=high.max(control(i,y))
		bezier_cache[key]=PackedVector2Array([a,c.clamp(low,high),d.clamp(low,high),b])
	var controls: PackedVector2Array = bezier_cache[key]
	var delta := controls[0].bezier_interpolate(controls[1],controls[2],controls[3],fraction)-controls[0].lerp(controls[3],fraction)
	assert(delta.length()<=float(settings.max_deviation),"Registered curve exceeded its displacement bound")
	return delta

func middle(a: Dictionary, b: Dictionary) -> Dictionary:
	return {"p":a.p.lerp(b.p,.5),"uv":a.uv.lerp(b.uv,.5),"uv2":a.uv2.lerp(b.uv2,.5),"color":a.color.lerp(b.color,.5)}

func emit(st: SurfaceTool, tri: Array, has_uv2: bool, has_color: bool, depth := 0) -> void:
	var selected := -1
	var score := 1.0
	for edge in 3:
		var a: Vector3 = tri[edge].p
		var b: Vector3 = tri[(edge+1)%3].p
		var sa := shift(a)
		var sb := shift(b)
		var maximum := 0.0
		var active := maxf(sa.length_squared(),sb.length_squared())
		for t in [.25,.5,.75]:
			var actual := shift(a.lerp(b,t))
			maximum=maxf(maximum,actual.distance_to(sa.lerp(sb,t)))
			active=maxf(active,actual.length_squared())
		var horizontal := Vector2(a.x-b.x,a.z-b.z).length()
		var value := maximum/float(settings.get("mesh_error",.002))
		if active>.0000001: value=maxf(value,horizontal/float(settings.get("max_segment",.5)))
		if value>score:
			score=value
			selected=edge
	if selected>=0 and depth<18:
		var a: Dictionary = tri[selected]
		var b: Dictionary = tri[(selected+1)%3]
		var c: Dictionary = tri[(selected+2)%3]
		var mid := middle(a,b)
		emit(st,[a,mid,c],has_uv2,has_color,depth+1)
		emit(st,[mid,b,c],has_uv2,has_color,depth+1)
		return
	for vertex: Dictionary in tri:
		st.set_uv(vertex.uv)
		if has_uv2: st.set_uv2(vertex.uv2)
		if has_color: st.set_color(vertex.color)
		st.add_vertex(vertex.p+shift(vertex.p))

func apply(parent: Node3D, first_child: int) -> void:
	for child in parent.get_children().slice(first_child):
		if child is MeshInstance3D and not child.get_meta("preserve_round_column",false): deform(child)

func deform(node: MeshInstance3D) -> void:
	# Leave unrelated straight wings and their normals/materials untouched.
	var active := false
	for surface in node.mesh.get_surface_count():
		var arrays: Array = node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		for i in range(0,indices.size(),3):
			for j in 3:
				var a: Vector3 = node.transform*vertices[indices[i+j]]
				var b: Vector3 = node.transform*vertices[indices[i+(j+1)%3]]
				if shift(a).length_squared()>0.0000001 or shift((a+b)*.5).length_squared()>0.0000001:
					active=true
					break
			if active: break
		if active: break
	if not active: return
	var result := ArrayMesh.new()
	for surface in node.mesh.get_surface_count():
		var arrays: Array = node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2]!=null else PackedVector2Array()
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		var output := SurfaceTool.new()
		output.begin(Mesh.PRIMITIVE_TRIANGLES)
		output.set_smooth_group(-1)
		for i in range(0,indices.size(),3):
			var tri: Array = []
			for j in 3:
				var at := indices[i+j]
				tri.append({"p":node.transform*vertices[at],"uv":uv[at] if not uv.is_empty() else Vector2.ZERO,"uv2":uv2[at] if not uv2.is_empty() else Vector2.ZERO,"color":colors[at] if not colors.is_empty() else Color.WHITE})
			emit(output,tri,not uv2.is_empty(),not colors.is_empty())
		output.generate_normals()
		if arrays[Mesh.ARRAY_TANGENT]!=null and not uv.is_empty(): output.generate_tangents()
		output.index()
		output.set_material(node.mesh.surface_get_material(surface))
		output.commit(result)
	node.mesh=result
	node.transform=Transform3D.IDENTITY
	node.set_meta("registered_curve_max_segment",float(settings.get("max_segment",.5)))
	if node.material_override is StandardMaterial3D:
		var source: StandardMaterial3D = node.material_override
		var key := source.get_instance_id()
		if not material_cache.has(key):
			var mat: StandardMaterial3D = source.duplicate()
			mat.resource_name=source.resource_name+" registered curve"
			mat.cull_mode=BaseMaterial3D.CULL_BACK
			material_cache[key]=mat
		node.material_override=material_cache[key]
