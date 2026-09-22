extends RefCounted
## Three visible perimeter risers; dimensions are photo proportions, not a survey.
func build(host)->void:
 var plaza:Node3D=host.scene.get_node("Feature_2304850")
 if plaza.has_meta("shuyun_steps"):return
 var terrain=preload("res://tools/build_terrain.gd").new();terrain.load_campus("eda")
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/mapping/shuyun-steps.json"))
 var points:Array=[]
 for feature:Dictionary in host.manifest.features:
  if str(feature.id)=="2304850":points=feature.points
 assert(not points.is_empty())
 # Existing terrain-fitted plaza is 0.18 m above grade. Match its surface to the third tread.
 for child in plaza.get_children():
  if child is MeshInstance3D:child.position.y+=float(data.rise_m)*3.0-.18
 var group:=Node3D.new();group.name="ShuyunSteps";host.scene.add_child(group);group.owner=host.scene;group.set_meta("static_collision_group",true)
 var geometry=preload("res://tools/build_roads.gd").new()
 var helper=preload("res://tools/build_eda_xiang_plaza.gd").new()
 var sides:=SurfaceTool.new();sides.begin(Mesh.PRIMITIVE_TRIANGLES)
 var path:Dictionary={"points":points,"width":0.0}
 var selection:Dictionary={"from_vertex":int(data.from_vertex),"to_vertex":int(data.to_vertex)}
 var profile=preload("res://tools/eda_lake_road_profile.gd")
 for level in range(3):
  var near:PackedVector2Array=profile.offset_points(path,selection,level*float(data.tread_m),1)
  var far:PackedVector2Array=profile.offset_points(path,selection,(level+1)*float(data.tread_m),1)
  var height:float=(3-level)*float(data.rise_m)
  var rings:Array[PackedVector2Array]=[]
  for i in range(near.size()-1):
   var ring:=PackedVector2Array([near[i],near[i+1],far[i+1],far[i]])
   if Geometry2D.is_polygon_clockwise(ring):ring.reverse()
   rings.append(ring)
   var a:=Vector3(far[i].x,terrain.elevation(far[i].x,far[i].y)+height,far[i].y)
   var b:=Vector3(far[i+1].x,terrain.elevation(far[i+1].x,far[i+1].y)+height,far[i+1].y)
   var normal:=Vector3(far[i].x-near[i].x,0,far[i].y-near[i].y).normalized()
   helper.quad(sides,a,b,b-Vector3.UP*float(data.rise_m),a-Vector3.UP*float(data.rise_m),normal)
  var tread:MeshInstance3D=geometry.emit(host,rings,height-.08,preload("res://tools/eda_surface_details.gd").new().ground_material("Shuyun pale stone steps",Color("c5bdb2"),1))
  terrain.fit_road(tread);host.scene.remove_child(tread);group.add_child(tread);tread.owner=host.scene
  tread.set_meta("road_surface",false);tread.set_meta("walk_collision",true);tread.set_meta("step_level",3-level)
 sides.index();sides.generate_normals()
 host.mesh_node(group,sides.commit(),host.material("Shuyun step risers",Color("ada79e")),"Risers").set_meta("walk_collision",true)
 plaza.set_meta("shuyun_steps",3);group.set_meta("riser_count",3)
