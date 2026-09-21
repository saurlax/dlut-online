extends RefCounted

## Visible round cladding columns on the registered east window bays.
static func column_material(builder) -> StandardMaterial3D:
	var material: StandardMaterial3D=builder.material("Library east column metal",Color("b9c0c1"))
	material.albedo_texture=null
	material.metallic=0.55
	material.roughness=0.34
	return material

func build(facade, first: Vector2, last: Vector2, outward: Vector2, profile: Dictionary) -> void:
	var column_profile: Dictionary=profile.east_round_columns
	var bottom: float=column_profile.bottom
	var top: float=column_profile.top
	var radius: float=column_profile.radius
	var material: StandardMaterial3D=column_material(facade.builder)
	for division in range(1,int(profile.columns)):
		var center:=first.lerp(last,float(division)/int(profile.columns))+outward*float(column_profile.outset)
		var mesh:=CylinderMesh.new()
		mesh.top_radius=radius
		mesh.bottom_radius=radius
		mesh.height=top-bottom
		mesh.radial_segments=24
		mesh.rings=1
		var node:MeshInstance3D=facade.builder.mesh_node(facade.group,mesh,material,"LibraryEastRoundColumn")
		node.position=Vector3(center.x,(bottom+top)/2,center.y)
		node.set_meta("walk_collision",false)
