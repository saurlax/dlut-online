extends RefCounted
const Profile=preload("res://tools/eda_xiang_plaza_profile.gd")
var terrain
var all_roads:Array
var plaza:Dictionary
func build(host)->void:
 terrain=preload("res://tools/build_terrain.gd").new();terrain.load_campus("eda")
 all_roads=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads
 plaza=Profile.load_profile()
 var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/mapping/lakeside-environment.json"))
 var group:=Node3D.new();group.name="LakeRoadHedges";host.scene.add_child(group);group.owner=host.scene
 group.set_meta("static_collision_group",true)
 var mesh:Mesh=load("res://assets/campuses/eda/models/vegetation/hedge_0_1.res")
 var bounds:=mesh.get_aabb()
 var placements:Array[Transform3D]=[]
 var soil:=SurfaceTool.new();soil.begin(Mesh.PRIMITIVE_TRIANGLES)
 var curb:=SurfaceTool.new();curb.begin(Mesh.PRIMITIVE_TRIANGLES)
 var helper=preload("res://tools/build_eda_xiang_plaza.gd").new()
 var count:=0
 for selection:Dictionary in profile.hedge_roads:
  for road:Dictionary in all_roads:
   if int(road.osm_way_id)!=int(selection.osm_way_id):continue
   for i in range(int(selection.from_vertex),int(selection.to_vertex)):
    var a:=Vector2(road.points[i][0],road.points[i][1]);var b:=Vector2(road.points[i+1][0],road.points[i+1][1])
    var axis:Vector2=(b-a).normalized();var normal:=axis.orthogonal()
    var steps:int=maxi(1,ceili(a.distance_to(b)/1.6))
    for side:int in selection.sides:
     for j in steps:
      var u:Vector2=a.lerp(b,float(j)/steps);var v:Vector2=a.lerp(b,float(j+1)/steps)
      var center:Vector2=(u+v)/2+normal*side*(float(road.width)/2+1.0)
      if blocked(center,int(road.osm_way_id)):continue
      var edge0:Vector2=normal*side*float(road.width)/2
      var edge1:Vector2=normal*side*(float(road.width)/2+2.0)
      helper.quad(soil,point(u+edge0,.17),point(v+edge0,.17),point(v+edge1,.17),point(u+edge1,.17),Vector3.UP)
      for offset:Vector2 in [edge0,normal*side*(float(road.width)/2+5.0)]:
       for n:Vector3 in [Vector3(normal.x*side,0,normal.y*side)]:
        helper.quad(curb,point(u+offset,.18),point(v+offset,.18),point(v+offset,-.12),point(u+offset,-.12),n)
      var scale:=Vector3(1.85/bounds.size.x,.72/bounds.size.y,1.85/bounds.size.z)
      var basis:=Basis(Vector3.UP,-atan2(axis.y,axis.x)).scaled(scale)
      var origin:=point(center,.17)-basis*Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
      var transform:=Transform3D(basis,origin)
      placements.append(transform)
      count+=1
 var foliage_path:="res://assets/campuses/eda/models/lake_hedges.tscn"
 save_foliage(placements,mesh,foliage_path)
 var foliage:Node3D=load(foliage_path).instantiate();foliage.name="HedgeFoliage"
 group.add_child(foliage);foliage.owner=host.scene
 soil.index();soil.generate_normals()
 host.mesh_node(group,soil.commit(),host.material("Lake hedge planting soil",Color("434b31")),"HedgeSoil").set_meta("walk_collision",true)
 curb.index();curb.generate_normals()
 host.mesh_node(group,curb.commit(),host.material("Lake raised sidewalk curb",Color("c5c4b6")),"ContinuousCurb").set_meta("walk_collision",true)
 group.set_meta("hedge_sections",count)
 print("LAKE HEDGES: ",count," sections, clear plaza entrances and road crossings")
func point(at:Vector2,lift:float)->Vector3:
 return Vector3(at.x,terrain.elevation(at.x,at.y)+lift,at.y)
func blocked(at:Vector2,own_id:int)->bool:
 # The hedge strip becomes the full red entrance at both stair widths.
 if at.x>=float(plaza.side_ranges[0][0])-0.5 and at.x<=float(plaza.side_ranges[1][1])+0.5 and at.y>float(plaza.origin_xz[1])-1 and at.y<350:return true
 for road:Dictionary in all_roads:
  if int(road.osm_way_id)==own_id:continue
  for i in range(road.points.size()-1):
   var a:=Vector2(road.points[i][0],road.points[i][1]);var b:=Vector2(road.points[i+1][0],road.points[i+1][1])
   if at.distance_to(Geometry2D.get_closest_point_to_segment(at,a,b))<float(road.width)/2+1.3:return true
 return false

func save_foliage(transforms:Array[Transform3D],mesh:Mesh,path:String)->void:
 # Explicit serialized buffers also work with the offline dummy renderer.
 var cells:Dictionary={}
 for transform:Transform3D in transforms:
  var cell:=Vector2i(floori(transform.origin.x/32),floori(transform.origin.z/32))
  if not cells.has(cell):cells[cell]=[]
  cells[cell].append(transform)
 var resources:Array[String]=['[ext_resource type="ArrayMesh" path="res://assets/campuses/eda/models/vegetation/hedge_0_1.res" id="Mesh"]']
 var nodes:Array[String]=['[node name="LakeHedgeFoliage" type="Node3D"]']
 var index:=0
 for cell:Vector2i in cells:
  var origin:=Vector3(cell.x*32,0,cell.y*32)
  var buffer:=PackedFloat32Array();var bounds:=AABB()
  for transform:Transform3D in cells[cell]:
   transform.origin-=origin
   var box:AABB=transform*mesh.get_aabb()
   bounds=box if buffer.is_empty() else bounds.merge(box)
   var b:=transform.basis;var at:=transform.origin
   buffer.append_array(PackedFloat32Array([b.x.x,b.y.x,b.z.x,at.x,b.x.y,b.y.y,b.z.y,at.y,b.x.z,b.y.z,b.z.z,at.z]))
  var key:="Cell%d"%index;index+=1
  resources.append('[sub_resource type="MultiMesh" id="%s"]\ntransform_format = 1\ncustom_aabb = %s\ninstance_count = %d\nmesh = ExtResource("Mesh")\nbuffer = %s'%[key,var_to_str(bounds.grow(.1)),cells[cell].size(),var_to_str(buffer)])
  nodes.append('[node name="%s" type="MultiMeshInstance3D" parent="."]\nposition = %s\nmultimesh = SubResource("%s")\nvisibility_range_end = 360.0'%[key,var_to_str(origin),key])
 var file:=FileAccess.open(path,FileAccess.WRITE)
 file.store_string('[gd_scene load_steps=%d format=3]\n\n'%(resources.size()+1)+"\n\n".join(resources)+"\n\n"+"\n\n".join(nodes)+"\n")
