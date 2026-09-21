extends SceneTree
const Collision=preload("res://scripts/shared/campus_collision.gd")
const Movement=preload("res://scripts/shared/movement.gd")
var failed:=false
func check(ok:bool,message:String)->void:
 if not ok:failed=true;push_error(message)
func _initialize():run.call_deferred()
func run()->void:
 var terrain=preload("res://tools/build_terrain.gd").new();terrain.load_campus("eda")
 var p:Dictionary=preload("res://tools/eda_xiang_plaza_profile.gd").load_profile()
 var base:float=terrain.elevation(p.origin_xz[0],p.origin_xz[1])+0.02
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
   for mesh in plaza.get_children():
    if not mesh is MeshInstance3D:continue
    if mesh.material_override.resource_name=="Xiang clipped live hedge":hedges+=1;check(not mesh.get_meta("walk_collision",false),"Fine hedge has unwanted trimesh collision")
    if mesh.material_override.resource_name=="Xiang plaza pale granite" and mesh.get_meta("walk_collision",false):letters+=1
    if not mesh.visible:continue
    var faces:PackedVector3Array=mesh.mesh.get_faces()
    for i in range(0,faces.size(),3):
     var a:Vector3=mesh.transform*faces[i];var b:Vector3=mesh.transform*faces[i+1];var c:Vector3=mesh.transform*faces[i+2]
     if a.z>=start-0.01 and a.z<=342.01 and maxf(a.x,maxf(b.x,c.x))<=-125 and absf(a.z-b.z)<0.001 and absf(b.z-c.z)<0.001 and absf(a.y-b.y)+absf(b.y-c.y)>0.1:riser_faces+=1
   check(hedges==1 and letters>0,"Missing traced emblem or stone name")
   check(riser_faces>=16,"Visible stair risers replaced by a ramp")
  await physics_frame;await physics_frame
  var space:=world.get_world_3d().direct_space_state
  for z in [324.0,333.0,336.0]:
   var garden_y:float=base-0.02+0.32+0.96*(342.0-z)/22.0
   var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-118.5,upper+2,z),Vector3(-118.5,base-1,z)))
   check(not hit.is_empty() and absf(hit.position.y-garden_y)<0.005,"Raised garden collision differs from visible turf")
  for side:Array in p.side_ranges:
   var x:float=(side[0]+side[1])/2
   var foot:float=terrain.elevation(x,p.origin_xz[1])+0.02
   for i in 17:
    var z:=lerpf(float(p.origin_xz[1])-0.01,start+0.01,i/16.0)
    var expected:=lerpf(foot,upper,(float(p.origin_xz[1])-z)/(float(p.origin_xz[1])-start))
    var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,upper+2,z),Vector3(x,foot-2,z)))
    check(not hit.is_empty() and absf(hit.position.y-expected)<0.015,"Stair collision gap or old slope remains")
   for reverse in [false,true]:
    var from_z:float=343.0 if not reverse else start-0.5
    var to_z:float=start-0.5 if not reverse else 343.0
    var actor:=CharacterBody3D.new();Movement.setup(actor);world.add_child(actor)
    actor.position=Vector3(x,(foot if not reverse else upper)+0.12,from_z)
    for i in 30:await physics_frame;Movement.step(actor,Vector2.ZERO,false,false,1.0/60,actor.position)
    var reached:=false
    for i in 400:
     await physics_frame
     if absf(actor.position.z-to_z)<0.1:reached=true;break
     Movement.step(actor,Vector2(0,signf(to_z-actor.position.z)*0.5),false,false,1.0/60,actor.position)
    check(reached and absf(actor.position.y-(upper if not reverse else foot))<0.2,"Stair ascent/descent blocked: "+str(actor.position))
    actor.queue_free();await physics_frame
  print("XIANG PLAZA CHECK server=",server," stair floors, bidirectional walking, traced stone and hedge")
  viewport.queue_free();await process_frame
 quit(1 if failed else 0)
