extends RefCounted
## Two adjacent display panels on three posts; dimensions are proportional.

var host
var parent: Node3D
var origin: Vector3
var frame: Basis

func box(size: Vector3, at: Vector3, material: Material, title: String, solid := false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node: MeshInstance3D = host.mesh_node(parent,mesh,material,title)
	node.transform = Transform3D(frame,origin+frame*at)
	node.set_meta("walk_collision",solid)

func build(builder, target: Node3D, point: Vector2, axis: Vector2, profile: Dictionary, terrain) -> void:
	host = builder
	parent = target
	origin = Vector3(point.x,terrain.elevation(point.x,point.y),point.y)
	frame = Basis(Vector3(-axis.y,0,axis.x),Vector3.UP,Vector3(-axis.x,0,-axis.y))
	var posts: StandardMaterial3D = host.material("EDA noticeboard brown frame",Color("665047"))
	var trim: StandardMaterial3D = host.material("EDA noticeboard pale frame",Color("b4b7ab"))
	var panel: StandardMaterial3D = host.material("EDA noticeboard panel",Color("b8bcb3"))
	for material in [posts,trim,panel]:
		material.cull_mode = BaseMaterial3D.CULL_BACK
		material.albedo_texture = null
		material.roughness = 0.7
	var width := float(profile.width_m)
	var height := float(profile.height_m)
	for x in [-width*0.5,0.0,width*0.5]:
		var foot := origin+frame*Vector3(x,0,0)
		var bottom: float = terrain.elevation(foot.x,foot.z)-origin.y
		box(Vector3(0.13,height-bottom,0.14),Vector3(x,(height+bottom)*0.5,0),posts,"NoticeboardPost",true)
	box(Vector3(width,0.10,0.12),Vector3(0,0.43,0),posts,"NoticeboardLowerBrace")
	box(Vector3(width,0.09,0.12),Vector3(0,height-0.20,0),posts,"NoticeboardHeaderBrace")
	box(Vector3(float(profile.top_bar_width_m),0.055,0.20),Vector3(0,height,0),trim,"NoticeboardTopBar")
	var panel_width := width*0.5-0.20
	var panel_height := float(profile.panel_height_m)
	var panel_y := float(profile.panel_bottom_m)+panel_height*0.5
	for side in [-1.0,1.0]:
		var x: float = side*width*0.25
		box(Vector3(panel_width,panel_height,0.08),Vector3(x,panel_y,0),panel,"NoticeboardPanel",true)
		for edge in [-1.0,1.0]:
			box(Vector3(0.055,panel_height+0.055,0.11),Vector3(x+edge*panel_width*0.5,panel_y,0),trim,"NoticeboardPanelSide")
			box(Vector3(panel_width,0.055,0.11),Vector3(x,panel_y+edge*panel_height*0.5,0),trim,"NoticeboardPanelRail")
