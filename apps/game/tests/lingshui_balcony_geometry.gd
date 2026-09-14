extends "res://tools/build_model.gd"

# Local regression: solid source-photo infill must survive material merging.
func build() -> void:
	root.add_child(scene)
	var helper := preload("res://tools/build_lingshui_balconies.gd").new()
	var white := material("Balcony panel test",Color.WHITE)
	var red := material("Balcony inset test",Color.RED)
	var entry := {"panel_bottom":0.12,"panel_height":0.52,"inset_width":0.48,"inset_height":0.32,"inset_bevel":0.07,"upper_bottom":0.70,"upper_height":0.30}
	helper.decorated_panel(self,scene,Vector2.ZERO,Vector2.RIGHT,Vector2(0,1),0.0,3.6,4,entry,white,red)
	var count := 0
	for child in scene.get_children():
		count += child.mesh.get_faces().size()/3
	merge_meshes(scene)
	assert(scene.get_child_count()==2,"Panel and inset materials should each merge")
	var actual := 0
	var faces := PackedVector3Array()
	for child in scene.get_children():
		actual += child.mesh.get_faces().size()/3
		for vertex in child.mesh.get_faces():
			faces.append(child.transform*vertex)
	assert(actual==count,"Merging must retain beveled insets and rectangular infill")
	for x in [-1.35,-0.45,0.45,1.35]:
		assert(ray_hits(faces,Vector3(x,0.38,1)),"Red lower motifs must not become holes")
	for x in [-0.9,0.9]:
		assert(ray_hits(faces,Vector3(x,0.85,1)),"Upper rectangular infill must remain solid")
	assert(not ray_hits(faces,Vector3(0,1.2,1)),"Do not fill space above the railing")
	print("PASS: merged balcony lower motifs and upper rectangular panels remain solid")
	quit()

func ray_hits(faces: PackedVector3Array, origin: Vector3) -> bool:
	for i in range(0,faces.size(),3):
		if Geometry3D.ray_intersects_triangle(origin,Vector3.FORWARD,faces[i],faces[i+1],faces[i+2]) != null:
			return true
	return false
