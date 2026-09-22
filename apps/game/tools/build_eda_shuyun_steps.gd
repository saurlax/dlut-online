extends RefCounted
## Three visible perimeter risers; dimensions are photo proportions, not a survey.
func build(host)->void:
 var plaza:Node3D=host.scene.get_node("Feature_2304850")
 if plaza.get_meta("shuyun_sunken",false):return
 var old=host.scene.get_node_or_null("ShuyunSteps")
 if old!=null:host.scene.remove_child(old);old.free()
 var terrain=preload("res://tools/build_terrain.gd").new();terrain.load_campus("eda")
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/mapping/shuyun-steps.json"))
 var points:Array=[]
 for feature:Dictionary in host.manifest.features:
  if str(feature.id)=="2304850":points=feature.points
 assert(not points.is_empty())
 # Lower the plaza below the surrounding grass; migrate the earlier raised model once.
 var previous_height:float=.45 if plaza.has_meta("shuyun_steps") else .18
 for child in plaza.get_children():
  if child is MeshInstance3D:child.position.y+=-float(data.rise_m)*3.0-previous_height
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
  var height:float=-(3-level)*float(data.rise_m)
  var rings:Array[PackedVector2Array]=[]
  for i in range(near.size()-1):
   var ring:=PackedVector2Array([near[i],near[i+1],far[i+1],far[i]])
   if Geometry2D.is_polygon_clockwise(ring):ring.reverse()
   rings.append(ring)
   var a:=Vector3(far[i].x,terrain.elevation(far[i].x,far[i].y)+height,far[i].y)
   var b:=Vector3(far[i+1].x,terrain.elevation(far[i+1].x,far[i+1].y)+height,far[i+1].y)
   var normal:=Vector3(far[i].x-near[i].x,0,far[i].y-near[i].y).normalized()
   helper.quad(sides,a,b,b+Vector3.UP*float(data.rise_m),a+Vector3.UP*float(data.rise_m),-normal)
  var tread:MeshInstance3D=geometry.emit(host,rings,height-.08,preload("res://tools/eda_surface_details.gd").new().ground_material("Shuyun pale stone steps",Color("c5bdb2"),1))
  terrain.fit_road(tread);host.scene.remove_child(tread);group.add_child(tread);tread.owner=host.scene
  tread.set_meta("road_surface",false);tread.set_meta("walk_collision",true);tread.set_meta("step_level",3-level)
 # Seal unstepped edges vertically; no extra staircases are inferred.
 for i in points.size():
  if i>=int(data.from_vertex) and i<int(data.to_vertex):continue
  var a:=Vector3(points[i][0],terrain.elevation(points[i][0],points[i][1]),points[i][1])
  var j:int=(i+1)%points.size()
  var b:=Vector3(points[j][0],terrain.elevation(points[j][0],points[j][1]),points[j][1])
  var n:=Vector3(-(b-a).z,0,(b-a).x).normalized()
  helper.quad(sides,a,b,b-Vector3.UP*.45,a-Vector3.UP*.45,n)
 sides.index();sides.generate_normals()
 host.mesh_node(group,sides.commit(),host.material("Shuyun step risers",Color("ada79e")),"Risers").set_meta("walk_collision",true)
 plaza.set_meta("shuyun_sunken",true);plaza.set_meta("shuyun_steps",3);group.set_meta("riser_count",3)

static func terrain_masks()->Array[PackedVector2Array]:
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/mapping/shuyun-steps.json"))
 var points:Array=[]
 for feature:Dictionary in manifest.features:
  if str(feature.id)=="2304850":points=feature.points
 var square:=PackedVector2Array()
 for at:Array in points:square.append(Vector2(at[0],at[1]))
 var result:Array[PackedVector2Array]=[square]
 var edge:Dictionary={"from_vertex":int(data.from_vertex),"to_vertex":int(data.to_vertex)}
 var outer:PackedVector2Array=preload("res://tools/eda_lake_road_profile.gd").offset_points({"points":points},edge,float(data.tread_m)*3.0,1)
 for i in range(outer.size()-1):
  var k:int=i+int(data.from_vertex)
  var band:=PackedVector2Array([square[k],square[k+1],outer[i+1],outer[i]])
  if Geometry2D.is_polygon_clockwise(band):band.reverse()
  result.append(band)
 return result
