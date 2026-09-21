extends RefCounted

func build(host, terrain, data: Dictionary) -> void:
	var zone: Dictionary = {}
	for candidate: Dictionary in data.linear_zones:
		if candidate.id=="academic-c-west-ginkgo-rows": zone=candidate
	assert(not zone.is_empty())
	var origin := Vector2(zone.expected_points[0][0],zone.expected_points[0][1])
	var end := Vector2(zone.expected_points[1][0],zone.expected_points[1][1])
	var axis := (end-origin).normalized()
	var side := Vector2(-axis.y,axis.x)
	var start := float(zone.start_distance)-1.5
	var finish := float(zone.start_distance)+(int(zone.station_count)-1)*float(zone.spacing)+1.5
	var along: Array[float] = [start,finish]
	var across: Array[float] = [-11.5,-4.3]
	var holes: Array[Rect2] = []
	for plant: Dictionary in data.instances:
		if plant.zone!=zone.id: continue
		var delta := Vector2(plant.position[0],plant.position[2])-origin
		var center := Vector2(delta.dot(axis),delta.dot(side))
		var hole := Rect2(center-Vector2.ONE*0.9,Vector2.ONE*1.8)
		holes.append(hole)
		along.append_array([hole.position.x,hole.end.x])
		across.append_array([hole.position.y,hole.end.y])
	along = subdivide(along)
	across = subdivide(across)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in along.size()-1:
		for j in across.size()-1:
			var midpoint := Vector2((along[i]+along[i+1])*0.5,(across[j]+across[j+1])*0.5)
			var excluded := false
			for hole in holes:
				if hole.has_point(midpoint): excluded=true
			if excluded: continue
			var uv := [Vector2(along[i],across[j]),Vector2(along[i+1],across[j]),Vector2(along[i+1],across[j+1]),Vector2(along[i],across[j+1])]
			for index in [0,1,2,0,2,3]:
				var p: Vector2 = origin+axis*uv[index].x+side*uv[index].y
				st.set_uv(uv[index])
				st.add_vertex(Vector3(p.x,terrain.elevation(p.x,p.y)+0.018,p.y))
	st.generate_normals()
	var material := ShaderMaterial.new()
	material.resource_name = "EDA C west square paving"
	material.shader = load("res://assets/campuses/eda/materials/ground.gdshader")
	material.set_shader_parameter("surface_kind",4)
	material.set_shader_parameter("base_color",Color("91978e"))
	var node: MeshInstance3D = host.mesh_node(host.scene,st.commit(),material,"CourtyardPaving")
	node.set_meta("walk_collision",true)
	node.set_meta("dimensions_are_approximate",true)

func subdivide(values: Array[float]) -> Array[float]:
	values.sort()
	var result: Array[float] = [values[0]]
	for value in values:
		var previous := result[-1]
		if value-previous<0.000001: continue
		var count := ceili(value-previous)
		for i in range(1,count+1): result.append(lerpf(previous,value,float(i)/count))
	return result
