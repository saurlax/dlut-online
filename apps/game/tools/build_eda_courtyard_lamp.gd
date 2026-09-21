extends RefCounted
## Single ring-head courtyard fixture. Meter dimensions are proportional estimates.
## The caller supplies placement; this helper creates no light or collision nodes.

var host
var parent: Node3D
var base: Vector3

func node(mesh: Mesh, material: Material, at: Vector3, title: String) -> MeshInstance3D:
	var result: MeshInstance3D=host.mesh_node(parent,mesh,material,title)
	result.position=base+at
	result.set_meta("walk_collision",false)
	return result

func cylinder(radius_bottom: float, radius_top: float, height: float, at: Vector3, material: Material, title: String, segments:=24) -> MeshInstance3D:
	var mesh:=CylinderMesh.new()
	mesh.bottom_radius=radius_bottom
	mesh.top_radius=radius_top
	mesh.height=height
	mesh.radial_segments=segments
	mesh.rings=1
	return node(mesh,material,at,title)

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	if (c-a).cross(b-a).dot(outward)<0:
		var swap:=b
		b=c
		c=swap
	for vertex in [a,b,c]:st.add_vertex(vertex)

func annulus(inner: float, outer: float, bottom: float, top: float, material: Material, title: String) -> void:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 48:
		var a:=TAU*i/48
		var b:=TAU*(i+1)/48
		var ra:=Vector3(cos(a),0,sin(a))
		var rb:=Vector3(cos(b),0,sin(b))
		var radial:Vector3=(ra+rb).normalized()
		for face in 4:
			var corners:Array[Vector3]
			var outward:Vector3
			if face==0:
				corners=[ra*inner+Vector3.UP*top,rb*inner+Vector3.UP*top,rb*outer+Vector3.UP*top,ra*outer+Vector3.UP*top]
				outward=Vector3.UP
			elif face==1:
				corners=[ra*inner+Vector3.UP*bottom,rb*inner+Vector3.UP*bottom,rb*outer+Vector3.UP*bottom,ra*outer+Vector3.UP*bottom]
				outward=Vector3.DOWN
			else:
				var radius:=outer if face==2 else inner
				corners=[ra*radius+Vector3.UP*bottom,rb*radius+Vector3.UP*bottom,rb*radius+Vector3.UP*top,ra*radius+Vector3.UP*top]
				outward=radial if face==2 else -radial
			st.set_smooth_group(-1 if face<2 else face)
			triangle(st,corners[0],corners[1],corners[2],outward)
			triangle(st,corners[0],corners[2],corners[3],outward)
	st.generate_normals()
	st.index()
	node(st.commit(),material,Vector3.ZERO,title)

func build(builder, target: Node3D, position: Vector3) -> void:
	host=builder
	parent=target
	base=position
	var metal:StandardMaterial3D=host.material("EDA courtyard lamp metal",Color("838d8d"))
	metal.albedo_texture=null
	metal.metallic=0.55
	metal.roughness=0.4
	var rim:StandardMaterial3D=host.material("EDA courtyard lamp rim",Color("535d59"))
	rim.albedo_texture=null
	rim.metallic=0.4
	rim.roughness=0.45
	var diffuser:StandardMaterial3D=host.material("EDA courtyard lamp diffuser",Color("e7e4d7"))
	diffuser.albedo_texture=null
	diffuser.roughness=0.6
	for material in [metal,rim,diffuser]:material.cull_mode=BaseMaterial3D.CULL_BACK
	# No emission: existing scene lighting controls day/night appearance.
	cylinder(0.14,0.14,0.025,Vector3(0,0.0125,0),metal,"CourtyardLampFoot")
	cylinder(0.087,0.080,0.50,Vector3(0,0.275,0),metal,"CourtyardLampSleeve")
	cylinder(0.080,0.060,0.06,Vector3(0,0.555,0),metal,"CourtyardLampShoulder")
	cylinder(0.085,0.085,0.018,Vector3(0,0.526,0),metal,"CourtyardLampSleeveBand")
	cylinder(0.062,0.044,3.15,Vector3(0,1.60,0),metal,"CourtyardLampPole")
	cylinder(0.055,0.055,0.16,Vector3(0,3.16,0),metal,"CourtyardLampCollar")
	annulus(0.34,0.46,3.54,3.60,rim,"CourtyardLampRing")
	annulus(0.355,0.447,3.529,3.541,diffuser,"CourtyardLampLens")
	for i in 3:
		var angle:=TAU*i/3
		var radial:=Vector3(cos(angle),0,sin(angle))
		var tangent:=Vector3(-sin(angle),0,cos(angle))
		var a:=radial*0.045+Vector3.UP*3.14
		var b:=radial*0.403+Vector3.UP*3.55
		var axis:Vector3=(b-a).normalized()
		var mesh:=BoxMesh.new()
		mesh.size=Vector3(0.032,a.distance_to(b),0.025)
		var brace:=node(mesh,metal,(a+b)/2,"CourtyardLampBrace")
		brace.basis=Basis(tangent,axis,tangent.cross(axis))
		var strap_mesh:=BoxMesh.new()
		strap_mesh.size=Vector3(0.032,0.13,0.012)
		var strap:=node(strap_mesh,metal,radial*0.056+Vector3.UP*3.13,"CourtyardLampStrap")
		strap.basis=Basis(tangent,Vector3.UP,tangent.cross(Vector3.UP))
		for y in [3.095,3.16]:
			var bolt:=cylinder(0.007,0.007,0.009,radial*0.067+Vector3.UP*y,rim,"CourtyardLampBolt",8)
			bolt.basis=Basis(tangent,radial,tangent.cross(radial))
