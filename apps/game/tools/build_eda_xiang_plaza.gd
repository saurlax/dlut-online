extends RefCounted
const Profile=preload("res://tools/eda_xiang_plaza_profile.gd")
var host
var group:Node3D
var terrain
var p:Dictionary
var base:float
func tri(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,normal:Vector3)->void:
 if (c-a).cross(b-a).length_squared()<0.0000000001:return
 var points:=[a,b,c]
 if (c-a).cross(b-a).dot(normal)<0:points.reverse()
 for v:Vector3 in points:
  st.set_uv(Vector2(v.x,v.y+v.z)*0.5);st.add_vertex(v)
func quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3,n:Vector3)->void:
 tri(st,a,b,c,n);tri(st,a,c,d,n)
func save(st:SurfaceTool,mat:Material,label:String,solid:bool)->MeshInstance3D:
 st.index();st.generate_normals();st.generate_tangents()
 var node:MeshInstance3D=host.mesh_node(group,st.commit(),mat,label)
 node.set_meta("walk_collision",solid)
 return node
func rings(values:Array)->Array[PackedVector2Array]:
 var result:Array[PackedVector2Array]=[]
 for r:Array in values:
  var ring:=PackedVector2Array()
  for v:Array in r:ring.append(Vector2(v[0],v[1]))
  result.append(ring)
 return result
func mapped(v:Vector2,letters:bool,top:bool)->Vector3:
 if letters:
  var scale:float=float(p.letter_width_m)/(282.00051-86.92)
  var height:float=(48.3418-v.y)*scale
  var angle:=deg_to_rad(float(p.letter_inclination_deg))
  return Vector3(float(p.origin_xz[0])+(v.x-(282.00051+86.92)/2)*scale,base+0.055+(height*sin(angle) if top else 0.0),float(p.letters_front_z)-height*cos(angle)-(0.0 if top else height*sin(angle)*tan(angle)))
 var at:=Vector2(p.garden_center_xz[0],p.garden_center_xz[1])+(v-Vector2(37.15,36.1))*float(p.garden_diameter_m)/50.31
 return Vector3(at.x,Profile.garden_height(terrain,at)+(0.62 if top else 0.015),at.y)
func extrude(values:Array,letters:bool,mat:Material)->void:
 var contours:=rings(values)
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var tess=preload("res://tools/build_roads.gd").new()
 var normal:=Vector3(0,cos(deg_to_rad(float(p.letter_inclination_deg))),sin(deg_to_rad(float(p.letter_inclination_deg)))) if letters else Vector3.UP
 for patch:PackedVector2Array in tess.tessellate(contours):
  quad(st,mapped(patch[0],letters,true),mapped(patch[1],letters,true),mapped(patch[2],letters,true),mapped(patch[3],letters,true),normal)
  quad(st,mapped(patch[0],letters,false),mapped(patch[1],letters,false),mapped(patch[2],letters,false),mapped(patch[3],letters,false),Vector3.DOWN)
 for ring:PackedVector2Array in contours:
  for i in ring.size():
   var a:=mapped(ring[i],letters,true);var b:=mapped(ring[(i+1)%ring.size()],letters,true)
   var edge:=b-a;var out:=Vector3(edge.z,0,-edge.x)
   quad(st,a,b,mapped(ring[(i+1)%ring.size()],letters,false),mapped(ring[i],letters,false),out)
 save(st,mat,"SchoolNameStone" if letters else "OfficialEmblemHedge",letters)
func build(builder)->void:
 host=builder;p=Profile.load_profile()
 terrain=preload("res://tools/build_terrain.gd").new();terrain.load_campus("eda")
 base=terrain.elevation(p.origin_xz[0],p.origin_xz[1])+0.02
 group=Node3D.new();group.name="XiangPlaza";host.scene.add_child(group);group.owner=host.scene
 group.set_meta("static_collision_group",true);group.set_meta("dimensions_are_approximate",true)
 var stone:StandardMaterial3D=host.material("Xiang plaza pale granite",Color("d4d1c8"))
 stone.albedo_texture=load("res://assets/textures/buildings/mineral_render_albedo.png")
 var upper:float=base+float(p.risers)*float(p.rise_m)
 var walk:=SurfaceTool.new();walk.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side:Array in p.side_ranges:
  var middle:float=(side[0]+side[1])/2.0
  var front:float=p.origin_xz[1]
  var foot:float=terrain.elevation(middle,front)+0.02
  var rise:float=(upper-foot)/float(p.risers)
  for i in int(p.risers):
   var height:float=(i+1)*rise
   var step:MeshInstance3D=host.box(group,Vector3(middle,foot+height/2,front-(i+0.5)*float(p.going_m)),Vector3(side[1]-side[0],height,float(p.going_m)),stone,"StairTread")
   step.set_meta("walk_collision",false)
  var start:float=front-float(p.risers)*float(p.going_m)
  quad(walk,Vector3(side[0],upper,start),Vector3(side[1],upper,start),Vector3(side[1],foot,front),Vector3(side[0],foot,front),Vector3.UP)
  var deck:MeshInstance3D=host.box(group,Vector3(middle,(upper+base-0.3)/2,(start+float(p.back_z))/2),Vector3(side[1]-side[0],upper-base+0.3,start-float(p.back_z)),stone,"UpperLanding")
  deck.set_meta("walk_collision",true)
  # Tie the upper landing into the existing rear paving without a vertical gap.
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var rear:float=terrain.elevation(middle,307)+0.02
  quad(st,Vector3(side[0],rear,307),Vector3(side[1],rear,307),Vector3(side[1],upper,p.back_z),Vector3(side[0],upper,p.back_z),Vector3.UP)
  save(st,stone,"RearLanding",true)
 save(walk,host.material("Xiang stair walk collision",Color.WHITE),"StairWalkCollision",true).visible=false
 var earth:=SurfaceTool.new();earth.begin(Mesh.PRIMITIVE_TRIANGLES)
 for z in range(320,342):
  for x in range(-125,-112):
   var a:=Vector2(x,z);var b:=a+Vector2.RIGHT;var c:=a+Vector2.ONE;var d:=a+Vector2.DOWN
   quad(earth,Vector3(a.x,Profile.garden_height(terrain,a),a.y),Vector3(b.x,Profile.garden_height(terrain,b),b.y),Vector3(c.x,Profile.garden_height(terrain,c),c.y),Vector3(d.x,Profile.garden_height(terrain,d),d.y),Vector3.UP)
 save(earth,host.material("Xiang raised garden turf",Color("526c32")),"RaisedGarden",true)
 var wall:MeshInstance3D=host.box(group,Vector3(-118.5,base+0.14,342.02),Vector3(13,0.28,0.22),stone,"GardenFrontRetainingStone")
 wall.set_meta("walk_collision",true)
 var letter_lawn:MeshInstance3D=host.box(group,Vector3(-118.5,base-0.095,343.85),Vector3(17,0.3,3.3),host.material("Xiang raised garden turf",Color("526c32")),"SchoolNameGrassBed")
 letter_lawn.set_meta("walk_collision",true)
 var curb:MeshInstance3D=host.box(group,Vector3(-118.5,base-0.035,345.5),Vector3(17,0.18,0.16),stone,"SchoolNameFrontCurb")
 curb.set_meta("walk_collision",true)
 var hedge:StandardMaterial3D=host.material("Xiang clipped live hedge",Color("668528"))
 hedge.roughness=0.98
 var identity:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/xiang_identity.json"))
 extrude(identity.emblem,false,hedge)
 extrude(identity.letters,true,stone)
