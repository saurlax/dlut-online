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
  var x:float=float(p.origin_xz[0])+(v.x-(282.00051+86.92)/2)*scale
  # The rear face follows the letter-face normal: their top angle is 90 degrees.
  # Both feet lie on the soil, so the ground segment is the hypotenuse.
  return Vector3(x,base+0.055+(height*sin(angle) if top else 0.0),Profile.curb_z(x,p)-.12-height*cos(angle)-(0.0 if top else height*sin(angle)*tan(angle)))
 var at:=Vector2(p.garden_center_xz[0],p.garden_center_xz[1])+(v-Vector2(37.15,36.1))*float(p.garden_diameter_m)/50.31
 return Vector3(at.x,Profile.garden_height(terrain,at)+(float(p.hedge_height_m) if top else 0.0),at.y)
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
func level(st:SurfaceTool,ring:PackedVector2Array,height:float)->void:
 for i in range(1,ring.size()-1):tri(st,Vector3(ring[0].x,height,ring[0].y),Vector3(ring[i].x,height,ring[i].y),Vector3(ring[i+1].x,height,ring[i+1].y),Vector3.UP)
func build(builder)->void:
 host=builder;p=Profile.load_profile()
 terrain=preload("res://tools/build_terrain.gd").new();terrain.load_campus("eda")
 base=Profile.lower_height(terrain,p)
 group=Node3D.new();group.name="XiangPlaza";host.scene.add_child(group);group.owner=host.scene
 group.set_meta("static_collision_group",true);group.set_meta("dimensions_are_approximate",true)
 var stone:StandardMaterial3D=host.material("Xiang plaza pale granite",Color("d4d1c8"))
 stone.albedo_texture=load("res://assets/textures/buildings/mineral_render_albedo.png")
 var upper:=Profile.upper_height(terrain,p)
 var start:=Profile.upper_z(p)
 var front:float=p.origin_xz[1]
 var left:float=p.side_ranges[0][0];var right:float=p.side_ranges[1][1]
 var walk:=SurfaceTool.new();walk.begin(Mesh.PRIMITIVE_TRIANGLES)
 var deck:=SurfaceTool.new();deck.begin(Mesh.PRIMITIVE_TRIANGLES)
 level(deck,Profile.rectangle(p.upper_left_x,p.back_z,p.upper_right_x,p.upper_wing_front_z),upper)
 level(deck,Profile.rectangle(left,p.upper_wing_front_z,right,start),upper)
 build_paving(float(p.upper_left_x),float(p.upper_right_x),float(p.back_z),float(p.upper_wing_front_z),upper)
 build_paving(left,right,float(p.upper_wing_front_z),start,upper)
 # Close the outer back and side walls all the way below the original ground.
 var perimeter:=PackedVector2Array([Vector2(p.upper_left_x,p.back_z),Vector2(p.upper_right_x,p.back_z),Vector2(p.upper_right_x,p.upper_wing_front_z),Vector2(right,p.upper_wing_front_z),Vector2(right,start),Vector2(left,start),Vector2(left,p.upper_wing_front_z),Vector2(p.upper_left_x,p.upper_wing_front_z)])
 for i in perimeter.size():
  var a:Vector2=perimeter[i];var b:Vector2=perimeter[(i+1)%perimeter.size()]
  if is_equal_approx(a.y,start) and is_equal_approx(b.y,start):continue
  var edge:=b-a
  quad(deck,Vector3(a.x,upper,a.y),Vector3(b.x,upper,b.y),Vector3(b.x,terrain.elevation(b.x,b.y)-.2,b.y),Vector3(a.x,terrain.elevation(a.x,a.y)-.2,a.y),Vector3(edge.y,0,-edge.x))
 # The old ground crossfall can be higher than the lowest tread at the sides.
 for x:float in [left,right]:
  for i in int(p.risers):
   var za:float=front-(i+1)*float(p.going_m)
   var zb:float=front-i*float(p.going_m)
   var tread:float=base+(i+1)*float(p.rise_m)
   var count:int=ceili((zb-za)/.2)
   for j in count:
    var a:float=lerpf(za,zb,float(j)/count);var b:float=lerpf(za,zb,float(j+1)/count)
    var ah:float=maxf(tread,terrain.elevation(x,a)+.02)
    var bh:float=maxf(tread,terrain.elevation(x,b)+.02)
    for normal:Vector3 in [Vector3.LEFT if x==left else Vector3.RIGHT]:
     quad(deck,Vector3(x,ah,a),Vector3(x,bh,b),Vector3(x,base-.4,b),Vector3(x,base-.4,a),normal)
 save(deck,stone,"LevelUpperPlaza",true)
 for side:Array in p.side_ranges:
  var middle:float=(side[0]+side[1])/2.0
  for i in int(p.risers):
   var height:float=(i+1)*float(p.rise_m)
   var step:MeshInstance3D=host.box(group,Vector3(middle,base+(height-.4)/2,front-(i+0.5)*float(p.going_m)),Vector3(side[1]-side[0],height+.4,float(p.going_m)),stone,"StairTread")
   step.set_meta("walk_collision",false)
  quad(walk,Vector3(side[0],upper,start),Vector3(side[1],upper,start),Vector3(side[1],base,front),Vector3(side[0],base,front),Vector3.UP)
 save(walk,host.material("Xiang stair walk collision",Color.WHITE),"StairWalkCollision",true).visible=false
 var turf:=SurfaceTool.new();turf.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rim:=SurfaceTool.new();rim.begin(Mesh.PRIMITIVE_TRIANGLES)
 var x0:float=p.side_ranges[0][1];var x1:float=p.side_ranges[1][0]
 var w:float=p.frame_width_m
 var outer:=Profile.rectangle(x0,start,x1,front)
 var inner:=Profile.rectangle(x0+w,start+w,x1-w,front-w)
 for i in 4:
  var j: int=(i+1)%4
  var a:Vector2=outer[i];var b:Vector2=outer[j];var c:Vector2=inner[j];var d:Vector2=inner[i]
  quad(rim,garden_point(a),garden_point(b),garden_point(c),garden_point(d),Vector3.UP)
  var edge:=b-a
  quad(rim,garden_point(a),garden_point(b),Vector3(b.x,terrain.elevation(b.x,b.y)-.3,b.y),Vector3(a.x,terrain.elevation(a.x,a.y)-.3,a.y),Vector3(edge.y,0,-edge.x))
 quad(turf,garden_point(inner[0]),garden_point(inner[1]),garden_point(inner[2]),garden_point(inner[3]),Vector3.UP)
 save(rim,stone,"FlushPlanterFrame",true)
 save(turf,host.material("Xiang raised garden turf",Color("526c32")),"RaisedGarden",true)
 var bed:Array=p.letter_bed
 var bed_ring:=Profile.name_bed(p)
 var apron:=SurfaceTool.new();apron.begin(Mesh.PRIMITIVE_TRIANGLES)
 var tess=preload("res://tools/build_roads.gd").new()
 var approach_outline:=Profile.front_polygon(left,right,front,p)
 for patch:PackedVector2Array in tess.tessellate([approach_outline],[bed_ring]):
  level(apron,patch,base)
 save(apron,preload("res://assets/roads/red_brick_path.tres"),"RaisedRedWalks",true)
 var curb_st:=SurfaceTool.new();curb_st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for boundary:PackedVector2Array in [approach_outline,bed_ring]:
  for i in boundary.size():
   var a:Vector2=boundary[i];var b:Vector2=boundary[(i+1)%boundary.size()]
   if boundary!=bed_ring and is_equal_approx(a.y,front) and is_equal_approx(b.y,front):continue
   var count:int=maxi(1,ceili(a.distance_to(b)/.25))
   var normal:=Vector3((b-a).y,0,-(b-a).x)
   for j in count:
    var u:Vector2=a.lerp(b,float(j)/count);var v:Vector2=a.lerp(b,float(j+1)/count)
    if boundary!=bed_ring and u.y>front+.1 and v.y>front+.1 and (u.x+v.x)/2>float(bed[0]) and (u.x+v.x)/2<float(bed[2]):continue
    if boundary==bed_ring:
     var offset:=Vector2(normal.x,normal.z).normalized()*.003
     u+=offset;v+=offset
    var top:float=base+.055 if boundary==bed_ring else base
    var low_u:float=terrain.elevation(u.x,u.y)-.15
    var low_v:float=terrain.elevation(v.x,v.y)-.15
    for n:Vector3 in [normal]:
     quad(curb_st,Vector3(u.x,top,u.y),Vector3(v.x,top,v.y),Vector3(v.x,low_v,v.y),Vector3(u.x,low_u,u.y),n)
 save(curb_st,stone,"RaisedWalkCurb",true)
 var lawn:=SurfaceTool.new();lawn.begin(Mesh.PRIMITIVE_TRIANGLES)
 for patch:PackedVector2Array in tess.tessellate([bed_ring]):level(lawn,patch,base+.055)
 save(lawn,host.material("Xiang raised garden turf",Color("526c32")),"SchoolNameGrassBed",true)
 var hedge:StandardMaterial3D=host.material("Xiang clipped live hedge",Color("668528"));hedge.roughness=.98
 var identity:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/xiang_identity.json"))
 extrude(identity.emblem,false,hedge);extrude(identity.letters,true,stone)
func garden_point(at:Vector2)->Vector3:
 return Vector3(at.x,Profile.garden_height(terrain,at),at.y)

func build_paving(left:float,right:float,back:float,front:float,height:float)->void:
 var tiles:=SurfaceTool.new();tiles.begin(Mesh.PRIMITIVE_TRIANGLES)
 level(tiles,Profile.rectangle(left,back,right,front),height+.002)
 save(tiles,preload("res://assets/roads/stone_paving.tres"),"UpperPlazaStoneTiles",false)
 var lines:=SurfaceTool.new();lines.begin(Mesh.PRIMITIVE_TRIANGLES)
 for axis in 2:
  var begin:float=left if axis==0 else back
  var end:float=right if axis==0 else front
  var at:float=begin+.3
  while at<end-.1:
   for offset:float in [-.14,.14]:
    var lo:float=clampf(at+offset-.035,begin,end)
    var hi:float=clampf(at+offset+.035,begin,end)
    level(lines,Profile.rectangle(lo,back,hi,front) if axis==0 else Profile.rectangle(left,lo,right,hi),height+.006)
   at+=4.0
 save(lines,host.material("Xiang plaza double-line stone inlay",Color("697874")),"UpperPlazaGrid",false)
