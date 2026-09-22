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
      var center:Vector2=(u+v)/2+normal*side*(float(road.width)/2+float(plaza.border_depth_m)/2)
      if blocked(center,int(road.osm_way_id)):continue
      var edge0:Vector2=normal*side*float(road.width)/2
      var edge1:Vector2=normal*side*(float(road.width)/2+float(plaza.border_depth_m))
      helper.quad(soil,point(u+edge0,.17),point(v+edge0,.17),point(v+edge1,.17),point(u+edge1,.17),Vector3.UP)
      for offset:Vector2 in [edge0,normal*side*(float(road.width)/2+float(plaza.border_depth_m)+3.0)]:
       for n:Vector3 in [Vector3(normal.x*side,0,normal.y*side)]:
        helper.quad(curb,point(u+offset,.18),point(v+offset,.18),point(v+offset,-.12),point(u+offset,-.12),n)
      var scale:=Vector3(1.85/bounds.size.x,.72/bounds.size.y,(float(plaza.border_depth_m)-.15)/bounds.size.z)
      var basis:=Basis(Vector3.UP,-atan2(axis.y,axis.x)).scaled(scale)
      var origin:=point(center,.17)-basis*Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
      var transform:=Transform3D(basis,origin)
      placements.append(transform)
      count+=1
 # Raised median shares one reviewed polygon with asphalt subtraction and verification.
 var median:=preload("res://tools/eda_lake_road_profile.gd").median(profile)
 var median_rings:Array[PackedVector2Array]=[median]
 var road_builder=preload("res://tools/build_roads.gd").new()
 var rim:MeshInstance3D=road_builder.emit(host,median_rings,.10,host.material("South median stone rim",Color("c5c4b6")))
 terrain.fit_road(rim);host.scene.remove_child(rim);group.add_child(rim);rim.owner=host.scene;rim.set_meta("road_surface",false)
 rim.set_meta("raised_lake_sidewalk",true)
 var inset:Array[PackedVector2Array]=Geometry2D.offset_polygon(median,-.16)
 var turf:MeshInstance3D=road_builder.emit(host,inset,.102,host.material("South median planted ground",Color("647047")))
 terrain.fit_road(turf);host.scene.remove_child(turf);group.add_child(turf);turf.owner=host.scene;turf.set_meta("road_surface",false)
 turf.set_meta("raised_lake_sidewalk",true)
 for i in median.size():
  var a:Vector2=median[i];var b:Vector2=median[(i+1)%median.size()]
  var normal:Vector2=(b-a).normalized().orthogonal()
  helper.quad(curb,point(a,.18),point(b,.18),point(b,-.12),point(a,-.12),Vector3(normal.x,0,normal.y))
 # Low trimmed planting fits inside the median, never across its rounded nose.
 for z in range(int(profile.south_median.nose_z[0])+4,int(profile.south_median.nose_z[1])-3,2):
  var crossings:=median_span(median,float(z))
  var next_span:=median_span(median,float(z)+1.0)
  if crossings.size()!=2 or next_span.size()!=2:continue
  var center:=Vector2((crossings[0]+crossings[1])*.5,z)
  var axis:=Vector2((next_span[0]+next_span[1])*.5-center.x,1.0).normalized()
  # Orient rows along the curved approach so their corners stay inside the curb.
  var width:float=(crossings[1]-crossings[0])*axis.y-.55
  var basis:=Basis(Vector3.UP,atan2(axis.x,axis.y)).scaled(Vector3(width/bounds.size.x,.62/bounds.size.y,(2.0/axis.y+.15)/bounds.size.z))
  var at:=point(center,.182)-basis*Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
  placements.append(Transform3D(basis,at));count+=1
 # Only the grass-facing T perimeter is planted; leave the lake promenade and stair mouths open.
 var borders:Array=[
  [Vector2(plaza.upper_left_x-.55,plaza.back_z+3.0),Vector2(plaza.upper_left_x-.55,plaza.upper_wing_front_z+.55)],
  [Vector2(plaza.upper_left_x-.55,plaza.upper_wing_front_z+.55),Vector2(plaza.side_ranges[0][0]-.65,plaza.upper_wing_front_z+.55)],
  [Vector2(plaza.side_ranges[0][0]-.65,plaza.upper_wing_front_z+.55),Vector2(plaza.side_ranges[0][0]-.65,plaza.origin_xz[1]-.7)],
  [Vector2(plaza.upper_right_x+.55,plaza.back_z+3.0),Vector2(plaza.upper_right_x+.55,plaza.upper_wing_front_z+.55)],
  [Vector2(plaza.upper_right_x+.55,plaza.upper_wing_front_z+.55),Vector2(plaza.side_ranges[1][1]+.65,plaza.upper_wing_front_z+.55)],
  [Vector2(plaza.side_ranges[1][1]+.65,plaza.upper_wing_front_z+.55),Vector2(plaza.side_ranges[1][1]+.65,plaza.origin_xz[1]-.7)]]
 for border:Array in borders:
  var a:Vector2=border[0];var b:Vector2=border[1];var axis:Vector2=(b-a).normalized()
  var steps:int=ceili(a.distance_to(b)/.9)
  for i in steps:
   var center:Vector2=a.lerp(b,(i+.5)/steps)
   var basis:=Basis(Vector3.UP,-atan2(axis.y,axis.x)).scaled(Vector3(1.02/bounds.size.x,.65/bounds.size.y,1.0/bounds.size.z))
   var origin:=point(center,.02)-basis*Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
   placements.append(Transform3D(basis,origin));count+=1
 var foliage_path:="res://assets/campuses/eda/models/lake_hedges.tscn"
 save_foliage(placements,mesh,foliage_path)
 var foliage:Node3D=ResourceLoader.load(foliage_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate();foliage.name="HedgeFoliage"
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

func median_span(ring:PackedVector2Array,z:float)->Array[float]:
 var crossings:Array[float]=[]
 for i in ring.size():
  var a:Vector2=ring[i];var b:Vector2=ring[(i+1)%ring.size()]
  if (a.y<=z and b.y>z) or (b.y<=z and a.y>z):crossings.append(lerpf(a.x,b.x,(z-a.y)/(b.y-a.y)))
 crossings.sort()
 return crossings
