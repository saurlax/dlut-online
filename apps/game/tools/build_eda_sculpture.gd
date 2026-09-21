extends RefCounted
## Approximate observed silhouette; the map node anchors position, not dimensions.
var surface: SurfaceTool

func triangle(a: Vector3,b: Vector3,c: Vector3,out: Vector3) -> void:
	if (c-a).cross(b-a).dot(out)<0:
		var swap:=b;b=c;c=swap
	for p in [a,b,c]: surface.add_vertex(p)

func loft(stations: Array[Vector4],depths: Array[float],closed:=false) -> void:
	var rings: Array[PackedVector3Array]=[]
	for i in stations.size():
		var p:=Vector3(stations[i].x,stations[i].y,stations[i].z)
		var before:=stations[maxi(0,i-1)]
		var after:=stations[mini(stations.size()-1,i+1)]
		var tangent:=Vector3(after.x-before.x,after.y-before.y,after.z-before.z).normalized()
		var across:=Vector3(-tangent.y,tangent.x,0).normalized()
		var ring:=PackedVector3Array()
		for j in 12:
			var angle:=TAU*j/12
			ring.append(p+across*cos(angle)*stations[i].w+Vector3.BACK*sin(angle)*depths[i])
		rings.append(ring)
	for i in rings.size()-1:
		var center:=Vector3(stations[i].x,stations[i].y,stations[i].z)
		for j in 12:
			var k:=(j+1)%12
			var out:=(rings[i][j]+rings[i][k])/2-center
			triangle(rings[i][j],rings[i][k],rings[i+1][k],out)
			triangle(rings[i][j],rings[i+1][k],rings[i+1][j],out)
	if closed: return
	for i in [0,rings.size()-1]:
		var center:=Vector3(stations[i].x,stations[i].y,stations[i].z)
		var adjacent:=stations[1 if i==0 else i-1]
		var out:=center-Vector3(adjacent.x,adjacent.y,adjacent.z)
		for j in 12: triangle(center,rings[i][j],rings[i][(j+1)%12],out)

func build(host) -> void:
	var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/sculpture.json"))
	var frame:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../../references/shared/mapping/osm-world-frame.json"))
	var origin:Array=frame.campuses.eda.origin_lon_lat
	var at:=Vector2((float(profile.lon_lat[0])-float(origin[0]))*111320*cos(deg_to_rad(float(origin[1]))),(float(origin[1])-float(profile.lon_lat[1]))*111320)
	var terrain:=preload("res://tools/build_terrain.gd").new();terrain.load_campus("eda")
	var group:=Node3D.new();group.name="XiangSculpture";host.scene.add_child(group);group.owner=host.scene
	var plaza=preload("res://tools/eda_xiang_plaza_profile.gd")
	group.position=Vector3(at.x,plaza.upper_height(terrain,plaza.load_profile()),at.y)
	group.set_meta("osm_id",profile.osm_id);group.set_meta("dimensions_are_approximate",true)
	var stone:StandardMaterial3D=host.material("Xiang sculpture pale stone",Color("aeb1ab"))
	stone.albedo_texture=load("res://assets/textures/buildings/mineral_render_albedo.png")
	var base:MeshInstance3D=host.box(group,Vector3(0,0.12,0),Vector3(3.2,0.24,2.0),stone,"SculpturePlinth")
	base.set_meta("walk_collision",true)
	var pedestal:=CylinderMesh.new();pedestal.top_radius=0.38;pedestal.bottom_radius=0.8;pedestal.height=0.6;pedestal.radial_segments=4
	var support:MeshInstance3D=host.mesh_node(group,pedestal,stone,"SculpturePedestal");support.position.y=0.54;support.rotation.y=PI/4;support.set_meta("walk_collision",true)
	var steel:StandardMaterial3D=host.material("Xiang polished steel",Color("aab5bb"))
	steel.albedo_texture=null;steel.metallic=0.92;steel.roughness=0.24;steel.cull_mode=BaseMaterial3D.CULL_BACK
	surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring:Array[Vector4]=[];var depths:Array[float]=[]
	for i in 65:
		var t:=float(i)/64
		var angle:float=deg_to_rad(50.0+290.0*t)
		var taper:=1.0-smoothstep(0.73,1.0,t)
		ring.append(Vector4(0.65*cos(angle),1.57+0.76*sin(angle),0.08*sin(angle*2),0.012+(0.12+0.06*sin(PI*t))*taper))
		depths.append(0.008+0.132*taper)
	loft(ring,depths)
	var wing:Array[Vector4]=[];depths=[]
	for i in 49:
		var t:=float(i)/48
		var p:=Vector2(0.35,2.24).bezier_interpolate(Vector2(-1.2,2.7),Vector2(-2.7,4.8),Vector2(-3.1,6.6),t)
		wing.append(Vector4(p.x,p.y,-0.08*sin(PI*t),0.32*pow(1-t,1.4)+0.006))
		depths.append(0.24*(1-t)+0.006)
	loft(wing,depths)
	var outline:=PackedVector2Array([Vector2(0.42,2.3),Vector2(-0.25,2.9),Vector2(0.10,3.45),Vector2(-0.2,4.6),Vector2(0.65,4.05),Vector2(2.1,3.95),Vector2(0.8,3.8),Vector2(0.5,3.1)])
	var triangles:=Geometry2D.triangulate_polygon(outline)
	for i in range(0,triangles.size(),3):
		for side in [-1.0,1.0]:
			var v:Array[Vector3]=[]
			for j in 3:
				var p:=outline[triangles[i+j]];v.append(Vector3(p.x,p.y,side*0.12))
			triangle(v[0],v[1],v[2],Vector3.BACK*side)
	for i in outline.size():
		var a:=outline[i];var b:=outline[(i+1)%outline.size()];var direction:=b-a
		var out:=Vector3(direction.y,-direction.x,0)*(-1 if Geometry2D.is_polygon_clockwise(outline) else 1)
		triangle(Vector3(a.x,a.y,-0.12),Vector3(b.x,b.y,-0.12),Vector3(b.x,b.y,0.12),out)
		triangle(Vector3(a.x,a.y,-0.12),Vector3(b.x,b.y,0.12),Vector3(a.x,a.y,0.12),out)
	surface.index();surface.generate_normals()
	var sculpture:MeshInstance3D=host.mesh_node(group,surface.commit(),steel,"SculptureMetal")
	sculpture.set_meta("walk_collision",true)

	# Existing shared collision reads top-level meshes and registered feature groups.
	# Keep this node as the identity anchor and bake its transform into root meshes.
	for child in group.get_children():
		child.transform=group.transform*child.transform
		group.remove_child(child)
		host.scene.add_child(child)
		child.owner=host.scene
