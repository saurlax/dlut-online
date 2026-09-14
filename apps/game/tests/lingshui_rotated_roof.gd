extends "res://tools/build_model.gd"

# Rotation must preserve footprint, roof heights and merged roof triangles.
func build() -> void:
	root.add_child(scene)
	var angle := 0.37
	var points := PackedVector2Array()
	for p in [Vector2(-5,-10),Vector2(5,-10),Vector2(5,10),Vector2(-5,10)]:
		points.append(p.rotated(angle))
	preload("res://tools/build_lingshui_gabled_hall.gd").new().build(self,scene,points,{"color":"b29a8e","eave_height":6.0,"height":9.0,"ridge_x":0.0,"roof_rotation":angle})
	var count := 0
	for child in scene.get_children():
		count += child.mesh.get_faces().size()/3
	merge_meshes(scene)
	var faces := PackedVector3Array()
	for child in scene.get_children():
		for vertex in child.mesh.get_faces():
			faces.append(child.transform*vertex)
	assert(faces.size()/3==count,"Material merging must retain rotated roof and end caps")
	for x in [-4.0,0.0,4.0]:
		var p := Vector2(x,2).rotated(angle)
		assert(absf(top_at(faces,p)-(9.0-absf(x)*0.6))<0.001,"Roof ridge and eaves must rotate together")
	assert(top_at(faces,Vector2(6,2).rotated(angle))==-INF,"Rotation must not expand footprint")
	print("PASS: rotated roof preserves ridge heights, footprint and merged triangles")
	quit()

func top_at(faces: PackedVector3Array, p: Vector2) -> float:
	var height := -INF
	for i in range(0,faces.size(),3):
		var hit = Geometry3D.ray_intersects_triangle(Vector3(p.x,20,p.y),Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
		if hit != null:
			height = maxf(height,hit.y)
	return height
