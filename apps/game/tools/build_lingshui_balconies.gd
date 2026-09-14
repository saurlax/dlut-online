extends RefCounted

# Exterior balconies registered to a photographed edge, without interior openings.
func build(builder, group: Node3D, p: Vector2, q: Vector2, outward: Vector2, entries: Array) -> void:
	var direction := (q-p).normalized()
	var rotation := -atan2(direction.y,direction.x)
	for entry in entries:
		var center := p.lerp(q,float(entry.fraction))
		var width: float = entry.width
		var depth: float = entry.depth
		var top: float = entry.top
		var thickness: float = entry.thickness
		var rail_height: float = entry.rail_height
		var mat: Material = builder.material("Photo balcony " + str(entry.color),Color(str(entry.color)))
		var inset: Material = builder.material("Photo balcony inset " + str(entry.inset_color),Color(str(entry.inset_color)))
		var slab := box(builder,group,center+outward*depth/2,top-thickness/2,Vector3(width,thickness,depth),rotation,mat)
		slab.set_meta("walk_collision",true)
		# Slabs are structural; small posts, rails and decorative panels are visual.
		box(builder,group,center+outward*depth,top+rail_height,Vector3(width+0.12,0.10,0.12),rotation,mat)
		for side in [-1,1]:
			box(builder,group,center+direction*side*width/2+outward*depth/2,top+rail_height,Vector3(0.12,0.10,depth),rotation,mat)
			for end in [0.0,1.0]:
				box(builder,group,center+direction*side*width/2+outward*depth*end,top+rail_height/2,Vector3(0.12,rail_height+0.18,0.12),rotation,mat)
		box(builder,group,center+outward*depth,top+rail_height/2,Vector3(0.09,rail_height,0.10),rotation,mat)
		decorated_panel(builder,group,center+outward*depth,direction,outward,top,width,int(entry.front_insets),entry,mat,inset)
		for side in [-1,1]:
			decorated_panel(builder,group,center+direction*side*width/2+outward*depth/2,outward,direction*side,top,depth,int(entry.side_insets),entry,mat,inset)

func box(builder, group: Node3D, pos: Vector2, y: float, size: Vector3, rotation: float, mat: Material) -> MeshInstance3D:
	var node: MeshInstance3D = builder.box(group,Vector3(pos.x,y,pos.y),size,mat,"PhotoBalcony")
	node.rotation.y = rotation
	return node

# The source shows red solid motifs, not holes through the white lower panel.
func decorated_panel(builder, group: Node3D, center: Vector2, direction: Vector2, outward: Vector2, top: float, width: float, count: int, entry: Dictionary, mat: Material, inset: Material) -> void:
	var rotation := -atan2(direction.y,direction.x)
	var bottom: float = top + float(entry.panel_bottom)
	var height: float = entry.panel_height
	box(builder,group,center,bottom+height/2,Vector3(width,height,0.10),rotation,mat)
	for i in count:
		var pos := center+direction*width*((i+0.5)/count-0.5)+outward*0.055
		beveled_inset(builder,group,pos,direction,bottom+height/2,Vector2(entry.inset_width,entry.inset_height),float(entry.inset_bevel),inset)
	var upper_count := maxi(1,count/2)
	for i in upper_count:
		var pos := center+direction*width*((i+0.5)/upper_count-0.5)
		box(builder,group,pos,top+float(entry.upper_bottom)+float(entry.upper_height)/2,Vector3(width/upper_count-0.18,float(entry.upper_height),0.08),rotation,inset)

func beveled_inset(builder, group: Node3D, center: Vector2, direction: Vector2, y: float, size: Vector2, bevel: float, mat: Material) -> void:
	var h := size/2
	assert(bevel>0.0 and bevel<minf(h.x,h.y))
	var points := PackedVector2Array([Vector2(-h.x+bevel,-h.y),Vector2(h.x-bevel,-h.y),Vector2(h.x,-h.y+bevel),Vector2(h.x,h.y-bevel),Vector2(h.x-bevel,h.y),Vector2(-h.x+bevel,h.y),Vector2(-h.x,h.y-bevel),Vector2(-h.x,-h.y+bevel)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	st.set_uv(Vector2.ZERO)
	st.set_tangent(Plane(Vector3.RIGHT,1.0))
	for i in Geometry2D.triangulate_polygon(points):
		var pos := center+direction*points[i].x
		st.add_vertex(Vector3(pos.x,y+points[i].y,pos.y))
	st.generate_normals()
	# Keep indexed motifs compatible with indexed BoxMesh when merging materials.
	st.index()
	builder.mesh_node(group,st.commit(),mat,"PhotoBalconyInset")
