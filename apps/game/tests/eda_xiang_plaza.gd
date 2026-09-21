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
   check(hedges==1 and letters>0,"Missing traced emblem or stone name")
   check(riser_faces>=20,"Visible stair risers replaced by a ramp")
  await physics_frame;await physics_frame
  var space:=world.get_world_3d().direct_space_state
  for sample in [{"a":Vector3(-135,upper-.1,325),"b":Vector3(-133,upper-.1,325)}, {"a":Vector3(-102,upper-.1,325),"b":Vector3(-104,upper-.1,325)}, {"a":Vector3(-120,upper-.1,306),"b":Vector3(-120,upper-.1,308)}]:
   var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(sample.a,sample.b))
   check(not hit.is_empty(),"Upper plaza back or outer side is open")
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
   for z in [308.0,312.0,320.0,326.0]:
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
