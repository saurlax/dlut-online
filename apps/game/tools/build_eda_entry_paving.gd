extends RefCounted

func build(host) -> void:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/buildings/library_information_profiles.json"))
	var profile: Dictionary = profiles["77914"].osm_registration.south_entry
	var feature: Dictionary
	for item in host.manifest.features:
		if item.id=="77914": feature=item
	var edge := int(profile.edge)
	var a := Vector2(feature.points[edge][0],feature.points[edge][1])
	var b := Vector2(feature.points[(edge+1)%feature.points.size()][0],feature.points[(edge+1)%feature.points.size()][1])
	var center := a.lerp(b,(float(profile.span[0])+float(profile.span[1]))/2)
	var axis := (b-a).normalized()
	var outward := Vector2(axis.y,-axis.x)
	var toe := float(profile.landing_depth)+int(profile.steps)*float(profile.tread)
	var width := float(profile.approach_width)
	var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads
	var road: Dictionary
	for item: Dictionary in roads:
		if int(item.osm_way_id)==int(profile.approach_road_id): road=item
	assert(not road.is_empty(),"Entry approach road is missing")
	# Match the existing decorative road border, which extends 1.5 m beyond
	# the road surface; do not overlap or replace the registered carriageway.
	var boundaries: Array[PackedVector2Array] = preload("res://scripts/shared/road_geometry.gd").polygons([road],1.5)
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	var columns := ceili(width/0.5)
	var ends: Array[float] = []
	for i in columns+1:
		var start := center+axis*(-width/2+width*i/columns)
		var finish := start+outward*70.0
		var distance := INF
		for ring in boundaries:
			for j in ring.size():
				var hit = Geometry2D.segment_intersects_segment(start+outward*toe,finish,ring[j],ring[(j+1)%ring.size()])
				if hit!=null: distance=minf(distance,(hit-start).dot(outward))
		assert(is_finite(distance) and distance>toe+1 and distance<40,"Entry paving needs road registration review")
		ends.append(distance)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in columns:
		var x0 := -width/2+width*i/columns
		var x1 := -width/2+width*(i+1)/columns
		var rows := ceili(maxf(ends[i],ends[i+1])-toe)*2
		for j in rows:
			var uv := [Vector2(x0,lerpf(toe,ends[i],float(j)/rows)),Vector2(x1,lerpf(toe,ends[i+1],float(j)/rows)),Vector2(x1,lerpf(toe,ends[i+1],float(j+1)/rows)),Vector2(x0,lerpf(toe,ends[i],float(j+1)/rows))]
			for index in [0,2,1,0,3,2]:
				var p: Vector2 = center+axis*uv[index].x+outward*uv[index].y
				st.set_uv(uv[index])
				st.add_vertex(Vector3(p.x,terrain.elevation(p.x,p.y)+0.018,p.y))
	st.generate_normals()
	var material := ShaderMaterial.new()
	material.resource_name = "Information entry grid paving"
	material.shader = load("res://assets/campuses/eda/materials/ground.gdshader")
	material.set_shader_parameter("surface_kind",5)
	material.set_shader_parameter("base_color",Color("b1a699"))
	material.set_shader_parameter("band_color",Color("76897b"))
	var node: MeshInstance3D = host.mesh_node(host.scene,st.commit(),material,"InformationEntryPaving")
	node.set_meta("walk_collision",true)
	node.set_meta("dimensions_are_approximate",true)
