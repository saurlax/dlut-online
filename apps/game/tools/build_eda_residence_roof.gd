extends RefCounted

func build(facade, spec: Dictionary, length: float) -> void:
	var start := float(spec.span[0])*length
	var finish := float(spec.span[1])*length
	var count := int(spec.panels)
	var pitch := (finish-start)/count
	var depth := float(spec.depth)
	var rise := float(spec.rise)
	var along := Vector3(facade.axis.x,0,facade.axis.y)
	var slope := Vector3(facade.outward.x,-rise/depth,facade.outward.y).normalized()
	if slope.cross(along).y<0: along=-along
	var normal := slope.cross(along).normalized()
	var orientation := Basis(along,normal,slope)
	for i in count:
		var at: Vector2 = facade.origin+facade.axis*(start+(i+0.5)*pitch)+facade.outward*float(spec.offset)
		var center := Vector3(at.x,float(spec.low_y)+rise/2,at.y)
		for inset in [false,true]:
			var size := Vector3(pitch-0.06,0.08,sqrt(depth*depth+rise*rise))
			if inset: size-=Vector3(0.10,0.055,0.10)
			var node: MeshInstance3D = facade.host.box(facade.group,center+normal*(0.055 if inset else 0.0),size,facade.glass if inset else facade.frame,"ResidenceRoofPanel")
			node.basis=orientation
			node.set_meta("walk_collision",false)
			if facade.facade_path != null: facade.facade_path.deform(node)
