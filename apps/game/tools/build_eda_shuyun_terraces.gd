extends RefCounted
## Photo-visible library forecourt, semicircular planted terrace and stairs.
var host
var terrain
var group:Node3D
var profile:Dictionary
var center:Vector2
var rear:Vector2
var along:Vector2
var walls:SurfaceTool
var helper=preload("res://tools/build_eda_xiang_plaza.gd").new()

func build(builder)->void:
 host=builder
 var old=host.scene.get_node_or_null("ShuyunTerraces")
 if old!=null:host.scene.remove_child(old);old.free()
 profile=JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/mapping/shuyun-terraces.json"))
 center=Vector2(profile.center_xz[0],profile.center_xz[1])
 rear=Vector2(profile.rear_axis_xz[0],profile.rear_axis_xz[1])
 along=Vector2(profile.side_axis_xz[0],profile.side_axis_xz[1])
 terrain=preload("res://tools/build_terrain.gd").new();terrain.load_campus("eda")
 group=Node3D.new();group.name="ShuyunTerraces";host.scene.add_child(group);group.owner=host.scene
 group.set_meta("static_collision_group",true)
 group.set_meta("source_profile","references/eda/mapping/shuyun-terraces.json")
 walls=SurfaceTool.new();walls.begin(Mesh.PRIMITIVE_TRIANGLES)
 var finish=preload("res://tools/eda_surface_details.gd").new()
 var paving:Material=finish.ground_material("Shuyun raised rose grid",Color("c4b3af"),9)
 var stone:Material=finish.ground_material("Shuyun terrace stair stone",Color("beb8ad"),1)
 var top:float=profile.upper_offset_m
 var lower:float=profile.plaza_offset_m
 var arc:=rear_arc(1.0)
 surface(arc,top,paving,"LibraryRaisedTerrace")
 var court:=ring(profile.forecourt_xz)
 surface(court,top,paving,"LibraryRaisedForecourt")
 perimeter(court,top,.02)
 # Front half-round platform protrudes into the lower square.
 var radius:float=profile.front_stage_radius_m
 var stage:=front_arc(radius)
 surface(stage,top,paving,"SemicircularStage")
 for i in int(profile.front_risers):
  var near:=front_arc(radius+i*float(profile.tread_m))
  var far:=front_arc(radius+(i+1)*float(profile.tread_m))
  var height:float=top-(i+1)*float(profile.rise_m)
  band(near,far,height+.003,stone,"FrontStair%d"%i)
  wall_chain(near,height+float(profile.rise_m),height)
 # The separate side flight is visible beside the semicircular planting.
 var axis:=rear.normalized()
 var side:=along.normalized()
 var landing:=center+along*.77
 for i in int(profile.side_risers):
  var a:Vector2=landing-axis*(i*float(profile.tread_m))
  var b:Vector2=landing-axis*((i+1)*float(profile.tread_m))
  var height:float=top-(i+1)*float(profile.rise_m)
  surface(PackedVector2Array([a-side*1.8,a+side*1.8,b+side*1.8,b-side*1.8]),height+.003,stone,"SideStair%d"%i)
  wall_chain(PackedVector2Array([a-side*1.8,a+side*1.8]),height+float(profile.rise_m),height)
  wall_chain(PackedVector2Array([a-side*1.8,b-side*1.8]),height,lower)
  wall_chain(PackedVector2Array([a+side*1.8,b+side*1.8]),height,lower)
 # Raised curved planter: stone rim and soil are separate surfaces.
 var outer:=rear_arc(1.02)
 var inner:=rear_arc(float(profile.planter_inner_scale))
 var rim_y:float=top+float(profile.planter_rim_raise_m)
 var soil_y:float=top+float(profile.planter_soil_raise_m)
 band(outer,rear_arc(1.00),rim_y,stone,"PlanterOuterCoping")
 band(rear_arc(float(profile.planter_inner_scale)+.018),inner,rim_y,stone,"PlanterInnerCoping")
 band(rear_arc(1.00),rear_arc(float(profile.planter_inner_scale)+.018),soil_y,host.material("Shuyun planter soil",Color("514c35")),"PlanterSoil")
 wall_chain(outer,rim_y,.02);wall_chain(inner,rim_y,top)
 for index in [0,outer.size()-1]:
  wall_chain(PackedVector2Array([outer[index],inner[index]]),rim_y,top)
 # Seal the terrace front except the curved and side stair mouths.
 var edge_a:Vector2=center-along
 var edge_b:Vector2=center+along
 wall_chain(PackedVector2Array([edge_a,center-side*radius]),top,lower)
 wall_chain(PackedVector2Array([center+side*radius,landing-side*1.8]),top,lower)
 wall_chain(PackedVector2Array([landing+side*1.8,edge_b]),top,lower)
 walls.index();walls.generate_normals()
 host.mesh_node(group,walls.commit(),host.material("Shuyun terrace retaining stone",Color("ada89c")),"RetainingStone").set_meta("walk_collision",true)
 planting(soil_y)
 group.set_meta("front_risers",profile.front_risers);group.set_meta("side_risers",profile.side_risers)

func ring(values:Array)->PackedVector2Array:
 var result:=PackedVector2Array()
 for p:Array in values:result.append(Vector2(p[0],p[1]))
 return result

func rear_arc(scale:float)->PackedVector2Array:
 var result:=PackedVector2Array()
 for i in range(65):
  var angle:float=-PI*.5+PI*i/64.0
  result.append(center+(rear*cos(angle)+along*sin(angle))*scale)
 return result

func front_arc(radius:float)->PackedVector2Array:
 var result:=PackedVector2Array()
 for i in range(49):
  var angle:float=PI*.5+PI*i/48.0
  result.append(center+(rear.normalized()*cos(angle)+along.normalized()*sin(angle))*radius)
 return result

func position(at:Vector2,height:float)->Vector3:
 return Vector3(at.x,terrain.elevation(at.x,at.y)+height,at.y)

func surface(outline:PackedVector2Array,height:float,mat:Material,label:String)->void:
 if Geometry2D.is_polygon_clockwise(outline):outline.reverse()
 var rings:Array[PackedVector2Array]=[outline]
 var mesh:MeshInstance3D=preload("res://tools/build_roads.gd").new().emit(host,rings,height-.08,mat)
 terrain.fit_road(mesh);host.scene.remove_child(mesh);group.add_child(mesh);mesh.owner=host.scene;mesh.name=label
 mesh.set_meta("road_surface",false);mesh.set_meta("walk_collision",true)

func band(a:PackedVector2Array,b:PackedVector2Array,height:float,mat:Material,label:String)->void:
 var outline:=a.duplicate();var reverse:=b.duplicate();reverse.reverse();outline.append_array(reverse)
 surface(outline,height,mat,label)

func wall_chain(points:PackedVector2Array,top:float,bottom:float)->void:
 for i in range(points.size()-1):
  var a:=position(points[i],top);var b:=position(points[i+1],top)
  var n:=Vector3(-(b-a).z,0,(b-a).x).normalized()
  helper.quad(walls,a,b,position(points[i+1],bottom),position(points[i],bottom),n)

func perimeter(points:PackedVector2Array,top:float,bottom:float)->void:
 var closed:=points.duplicate();closed.append(points[0]);wall_chain(closed,top,bottom)

func planting(soil_y:float)->void:
 var hedges:Array[Transform3D]=[]
 var trees:Array[Transform3D]=[]
 var shrubs:Array[Transform3D]=[]
 var tree:Mesh=load("res://assets/campuses/eda/models/vegetation/juniper_0_0.res")
 var shrub:Mesh=load("res://assets/campuses/eda/models/vegetation/broadleaf_0_1.res")
 for i in range(81):
  var angle:float=-PI*.5+PI*(i+.5)/81.0
  var at:Vector2=center+(rear*cos(angle)+along*sin(angle))*.973
  hedges.append(plant_transform(tree,at,soil_y,2.6,1.8,float(i)*.13))
 var grove:=ring(profile.woodland_xz)
 surface(grove,.02,preload("res://tools/build_eda_woodland_paths.gd").grass_material(),"WoodlandGrass")
 var random:=RandomNumberGenerator.new();random.seed=2304850
 for z in range(416,447,4):
  for x in range(38,73,4):
   var at:=Vector2(x+random.randf_range(-.7,.7),z+random.randf_range(-.7,.7))
   if not Geometry2D.is_point_in_polygon(at,grove):continue
   trees.append(plant_transform(tree,at,.025,random.randf_range(5.0,7.5),random.randf_range(2.5,3.5),random.randf()*TAU))
   if trees.size()%3==0:shrubs.append(plant_transform(shrub,at+Vector2(1,1),.025,2.0,2.2,random.randf()*TAU))
 instances(tree,hedges,"SemicircularPlanterHedge")
 instances(tree,trees,"LibraryWoodland")
 instances(shrub,shrubs,"WoodlandUnderstory")
 group.set_meta("woodland_trees",trees.size())

func plant_transform(mesh:Mesh,at:Vector2,ground:float,height:float,width:float,rotation:float)->Transform3D:
 var bounds:=mesh.get_aabb()
 var basis:=Basis(Vector3.UP,rotation).scaled(Vector3(width/bounds.size.x,height/bounds.size.y,width/bounds.size.z))
 return Transform3D(basis,position(at,ground)-basis*Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z))

func instances(mesh:Mesh,transforms:Array[Transform3D],label:String)->void:
 # Bake by material so headless generation retains every foliage transform.
 # Dummy rendering does not serialize MultiMesh instance buffers.
 var merged:=ArrayMesh.new()
 for surface_index in mesh.get_surface_count():
  var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  for transform:Transform3D in transforms:tool.append_from(mesh,surface_index,transform)
  tool.set_material(mesh.surface_get_material(surface_index));tool.commit(merged)
 var node:=MeshInstance3D.new();node.name=label;node.mesh=merged;group.add_child(node);node.owner=host.scene
