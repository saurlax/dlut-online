extends RefCounted

# Explicit photo-supported security grilles, separate from structural collision.
func build(builder, group: Node3D, center: Vector2, direction: Vector2, outward: Vector2, bottom: float, width: float, height: float, profile: Dictionary) -> void:
	var metal: Material = builder.material("Window grille metal",Color("7f857c"))
	var bars := int(profile.bars)
	var depth := float(profile.depth)
	if profile.get("style", "") == "flat_horizontal":
		var left := center-direction*width/2
		var right := center+direction*width/2
		for anchor in [left, center, right]:
			rod(builder,group,point(anchor,outward,bottom,height,Vector2(0,depth)),point(anchor,outward,bottom,height,Vector2(1,depth)),0.035,metal)
		for i in range(bars+2):
			var level := Vector2(float(i)/(bars+1),depth)
			rod(builder,group,point(left,outward,bottom,height,level),point(right,outward,bottom,height,level),0.035,metal)
		return
	var curve := PackedVector2Array([
		Vector2(0.0,0.10),Vector2(0.18,depth),Vector2(0.42,depth*0.7),
		Vector2(0.68,0.18),Vector2(1.0,0.18)])
	for i in bars:
		var offset := direction*width*((i+0.5)/bars-0.5)
		for j in curve.size()-1:
			var a := point(center+offset,outward,bottom,height,curve[j])
			var b := point(center+offset,outward,bottom,height,curve[j+1])
			rod(builder,group,a,b,0.028,metal)
	for level in [curve[0],curve[3],curve[4]]:
		var a := point(center-direction*width/2,outward,bottom,height,level)
		var b := point(center+direction*width/2,outward,bottom,height,level)
		rod(builder,group,a,b,0.035,metal)

func point(center: Vector2, outward: Vector2, bottom: float, height: float, curve: Vector2) -> Vector3:
	var flat := center+outward*curve.y
	return Vector3(flat.x,bottom+height*curve.x,flat.y)

func rod(builder, group: Node3D, a: Vector3, b: Vector3, thickness: float, metal: Material) -> void:
	var direction := (b-a).normalized()
	var node: MeshInstance3D = builder.box(group,(a+b)/2,Vector3(thickness,thickness,a.distance_to(b)),metal,"WindowGrille")
	node.basis = Basis.looking_at(direction,Vector3.RIGHT if absf(direction.y)>0.9 else Vector3.UP)
