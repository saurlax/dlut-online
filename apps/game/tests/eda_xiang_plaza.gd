extends SceneTree
const Profile=preload("res://tools/eda_xiang_plaza_profile.gd")
const Collision=preload("res://scripts/shared/campus_collision.gd")
const Movement=preload("res://scripts/shared/movement.gd")
var failed:=false
func check(ok:bool,message:String)->void:
 if not ok:failed=true;push_error(message)
func _initialize():run.call_deferred()
func run()->void:
 var terrain=preload("res://tools/build_terrain.gd").new();terrain.load_campus("eda")
 var p:Dictionary=preload("res://tools/eda_xiang_plaza_profile.gd").load_profile()
 var base:float=preload("res://tools/eda_xiang_plaza_profile.gd").lower_height(terrain,p)
 var front:float=p.origin_xz[1]
 var upper:float=base+float(p.risers)*float(p.rise_m)
 var start:float=p.origin_xz[1]-float(p.risers)*float(p.going_m)
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
 for server in [false,true]:
  var viewport:=SubViewport.new();viewport.own_world_3d=true;root.add_child(viewport)
  var world:=Node3D.new();viewport.add_child(world)
  if server:world.add_child(load("res://scenes/server/eda.scn").instantiate())
  else:
   var model:Node3D=load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
   world.add_child(model);world.add_child(load("res://assets/campuses/eda/models/terrain.tscn").instantiate())
   Collision.build(world,model,manifest,"eda")
   var plaza:Node3D=model.get_node("XiangPlaza")
   var hedges:=0;var letters:=0;var riser_faces:=0
   var paving_grid:=false
   for child in plaza.get_children():
    if child is MeshInstance3D and child.material_override.resource_name=="Xiang plaza double-line stone inlay":paving_grid=true
   check(model.has_node("LakeRoadHedges") and model.get_node("LakeRoadHedges").get_meta("hedge_sections",0)>300,"Continuous lake-road hedges are missing")
   var border_profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/mapping/lakeside-environment.json"))
   check(is_equal_approx(float(p.border_depth_m),float(border_profile.hedge_depth_m)),"Name bed depth differs from the lake hedge band")
   var hedge_instances:=0
   for cell in model.get_node("LakeRoadHedges/HedgeFoliage").get_children():
    if cell is MultiMeshInstance3D:hedge_instances+=cell.multimesh.instance_count
   check(hedge_instances>300,"Saved lake hedge instances are missing")
   check(paving_grid,"Upper plaza photo grid paving is missing")
   for mesh in plaza.get_children():
    if not mesh is MeshInstance3D:continue
    if mesh.material_override.resource_name=="Xiang clipped live hedge":hedges+=1;check(not mesh.get_meta("walk_collision",false),"Fine hedge has unwanted trimesh collision")
    if mesh.material_override.resource_name=="Xiang plaza pale granite" and mesh.get_meta("walk_collision",false):letters+=1
    if mesh.material_override.resource_name=="Xiang clipped live hedge":
     var positions:PackedVector3Array=mesh.mesh.get_faces()
     for v:Vector3 in positions:
      var expected:float=base+float(p.planter_raise_m)+(front-v.z)/(front-start)*(upper-base)
      check(absf(v.y-expected)<0.003 or absf(v.y-expected-float(p.hedge_height_m))<0.003,"Emblem departs from stair incline")
    if not mesh.visible:continue
    var faces:PackedVector3Array=mesh.mesh.get_faces()
    for vertex:Vector3 in faces:
     check(vertex.z<=Profile.curb_z(vertex.x,p)+.006,"Plaza projects beyond the curved lake-facing road edge")
    for i in range(0,faces.size(),3):
     var a:Vector3=mesh.transform*faces[i];var b:Vector3=mesh.transform*faces[i+1];var c:Vector3=mesh.transform*faces[i+2]
     if a.z>=start-0.01 and a.z<=front+.01 and maxf(a.x,maxf(b.x,c.x))<=-125 and absf(a.z-b.z)<0.001 and absf(b.z-c.z)<0.001 and absf(a.y-b.y)+absf(b.y-c.y)>0.1:riser_faces+=1
   # Inspect saved stone vertices, including the back feet, rather than the generator's mapping function.
   var stone_points:Dictionary={};var letter_tops:Array[Vector3]=[]
   for child in plaza.get_children():
    if not child is MeshInstance3D or child.material_override.resource_name!="Xiang plaza pale granite" or not child.get_meta("walk_collision",false):continue
    for v:Vector3 in child.mesh.get_faces():
     stone_points[Vector3i(roundi(v.x*500),roundi(v.y*500),roundi(v.z*500))]=true
     if v.x>float(p.letter_bed[0])+.1 and v.x<float(p.letter_bed[2])-.1 and v.z>front+.15 and v.y>base+.06:letter_tops.append(v)
   check(letter_tops.size()>50,"Missing inclined letter stone vertices")
   for top:Vector3 in letter_tops:
    var h:float=top.y-base-.055
    var foot:=Vector3(top.x,base+.055,top.z-h*tan(deg_to_rad(float(p.letter_inclination_deg))))
    var found:=false
    var key:=Vector3i(roundi(foot.x*500),roundi(foot.y*500),roundi(foot.z*500))
    for dz in [-1,0,1]:
     if stone_points.has(key+Vector3i(0,0,dz)):found=true
    check(found,"Stone back is vertically extruded; ground hypotenuse is missing")
    check(foot.z>=Profile.curb_z(foot.x,p)-float(p.border_depth_m)-.002,"Stone back foot escapes the grass bed")
   check(hedges==1 and letters>0,"Missing traced emblem or stone name")
   check(riser_faces>=20,"Visible stair risers replaced by a ramp")
  await physics_frame;await physics_frame
  var space:=world.get_world_3d().direct_space_state
  # Sample across the actual promenade/T-wing seam and the entrance/hedge kerb.
  for x:float in [-145.04,-144.96,-93.04,-92.96]:
   var z:float=308.5 if x< -120 else 306.5
   var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,upper+2,z),Vector3(x,base-2,z)))
   check(not hit.is_empty() and absf(hit.position.y-upper)<.06,"Lake promenade and plaza have a step or gap")
  for x:float in [-134.05,-133.95,-103.05,-102.95]:
   var z:float=Profile.curb_z(x,p)-float(p.border_depth_m)-.5
   var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,upper+2,z),Vector3(x,base-2,z)))
   check(not hit.is_empty() and absf(hit.position.y-base)<.025,"Entrance and adjoining red walk kerbs have different levels")
  # The saved road mesh, not just an equal-height floor, must remain red across the plaza frontage.
  var path_samples:=0
  for road:Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads:
   if int(road.osm_way_id)!=1076344125:continue
   for i in range(road.points.size()-1):
    var a:=Vector2(road.points[i][0],road.points[i][1]);var b:=Vector2(road.points[i+1][0],road.points[i+1][1])
    var normal:Vector2=(b-a).normalized().orthogonal()
    for j in 12:
     var at:Vector2=a.lerp(b,(j+.5)/12)
     if at.x< -144 or at.x> -94 or at.y<300:continue
     for offset:float in [-.8,0,.8]:
      var sample:Vector2=at+normal*offset
      var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(sample.x,upper+2,sample.y),Vector3(sample.x,base-2,sample.y)))
      check(not hit.is_empty() and absf(hit.position.y-terrain.elevation(sample.x,sample.y)-.02)<.012,"Promenade has a gap or plaza-height obstacle")
      if not server and not hit.is_empty():
       var mesh=hit.collider.get_parent()
       check(mesh is MeshInstance3D and mesh.material_override.resource_name=="Photo red path","Plaza paving replaced the continuous red promenade")
      path_samples+=1
  check(path_samples>60,"Too few samples across the promenade frontage")
  for x in [-124.9,-112.1]:
   for z:float in [Profile.curb_z(x,p)-.08,Profile.curb_z(x,p)-float(p.border_depth_m)+.08]:
    var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,upper+1,z),Vector3(x,base-1,z)))
    check(not hit.is_empty() and absf(hit.position.y-base-.055)<.005,"Curved name bed has a gap or old pavement overlap")
  check(int(p.risers)==10,"Photo-confirmed stairs must have ten risers")
  check(float(p.letter_bed[0])==float(p.side_ranges[0][1]) and float(p.letter_bed[2])==float(p.side_ranges[1][0]),"Name bed and emblem bed widths differ")
  for at:Vector2 in [Vector2(-129,front+1),Vector2(-118.5,front+1),Vector2(-108,front+1),Vector2(-133.8,front+2),Vector2(-125.2,front+2),Vector2(-111.8,front+2),Vector2(-103.2,front+2)]:
   var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,upper+1,at.y),Vector3(at.x,base-1,at.y)))
   check(not hit.is_empty() and absf(hit.position.y-base)<.005,"Red sidewalk is not level or full stair width")
  check(base-terrain.elevation(-134,Profile.curb_z(-134,p))>=.15,"Sidewalk must be raised above the adjoining road")
  for z in [328.0,330.0,333.0,337.0]:
   var garden_y:float=base+float(p.planter_raise_m)+(front-z)/(front-start)*(upper-base)
   var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-118.5,upper+2,z),Vector3(-118.5,base-1,z)))
   check(not hit.is_empty() and absf(hit.position.y-garden_y)<0.005,"Raised garden collision differs from visible turf")
  for x in [-132.0,-122.0,-105.0]:
   for z in [314.0,316.0,320.0,326.0]:
    var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,upper+2,z),Vector3(x,base-2,z)))
    check(not hit.is_empty() and absf(hit.position.y-upper)<0.005,"Upper plaza is sloped or missing")
  for z in [329.0,333.0,337.0]:
   var frame_y:float=base+float(p.planter_raise_m)+(front-z)/(front-start)*(upper-base)
   for x in [-124.9,-112.1]:
    var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,upper+2,z),Vector3(x,base-2,z)))
    check(not hit.is_empty() and absf(hit.position.y-frame_y)<0.005,"Stone frame is not flush with the inclined lawn")
  for side:Array in p.side_ranges:
   var x:float=(side[0]+side[1])/2
   var foot:float=base
   for i in 17:
    var z:=lerpf(float(p.origin_xz[1])-0.01,start+0.01,i/16.0)
    var expected:=lerpf(foot,upper,(float(p.origin_xz[1])-z)/(float(p.origin_xz[1])-start))
    var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,upper+2,z),Vector3(x,foot-2,z)))
    check(not hit.is_empty() and absf(hit.position.y-expected)<0.015,"Stair collision gap or old slope remains")
   for reverse in [false,true]:
    var from_z:float=front+1 if not reverse else start-0.5
    var to_z:float=start-0.5 if not reverse else front+1
    var actor:=CharacterBody3D.new();Movement.setup(actor);world.add_child(actor)
    actor.position=Vector3(x,(foot if not reverse else upper)+0.12,from_z)
    for i in 30:await physics_frame;Movement.step(actor,Vector2.ZERO,false,false,1.0/60,actor.position)
    var reached:=false
    for i in 700:
     await physics_frame
     if absf(actor.position.z-to_z)<0.1:reached=true;break
     Movement.step(actor,Vector2(0,signf(to_z-actor.position.z)*0.5),false,false,1.0/60,actor.position)
    check(reached and absf(actor.position.y-(upper if not reverse else foot))<0.2,"Stair ascent/descent blocked: "+str(actor.position))
    actor.queue_free();await physics_frame
  print("XIANG PLAZA CHECK server=",server," stair floors, bidirectional walking, traced stone and hedge")
  viewport.queue_free();await process_frame
 quit(1 if failed else 0)
