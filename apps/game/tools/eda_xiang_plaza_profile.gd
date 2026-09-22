extends RefCounted
static func load_profile() -> Dictionary:
 return JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/xiang_plaza.json"))
static func lower_height(terrain,p:Dictionary)->float:
 # Anchor the level plaza to the existing lake promenade, not the highest roadside corner.
 return terrain.shore_elevation(float(p.origin_xz[0]),float(p.back_z))+.02-float(p.risers)*float(p.rise_m)
static func upper_height(terrain,p:Dictionary)->float:
 return lower_height(terrain,p)+float(p.risers)*float(p.rise_m)
static func upper_z(p:Dictionary)->float:
 return float(p.origin_xz[1])-float(p.risers)*float(p.going_m)
static func rectangle(x0:float,z0:float,x1:float,z1:float)->PackedVector2Array:
 return PackedVector2Array([Vector2(x0,z0),Vector2(x1,z0),Vector2(x1,z1),Vector2(x0,z1)])
static func masks() -> Array[PackedVector2Array]:
 var p:=load_profile()
 return [front_polygon(p.side_ranges[0][0],p.side_ranges[1][1],p.upper_wing_front_z,p),upper_polygon(p)]
static func garden_height(terrain, at:Vector2) -> float:
 var p:=load_profile()
 return lower_height(terrain,p)+float(p.planter_raise_m)+clampf((float(p.origin_xz[1])-at.y)/(float(p.origin_xz[1])-upper_z(p)),0,1)*float(p.risers)*float(p.rise_m)

static func curb_z(x:float,p:Dictionary)->float:
 var points:Array=p.front_road_points
 for i in range(points.size()-1):
  var a:=Vector2(points[i][0],points[i][1]);var b:=Vector2(points[i+1][0],points[i+1][1])
  if x<=b.x:
   var before:Vector2=Vector2(points[maxi(0,i-1)][0],points[maxi(0,i-1)][1])
   var after:Vector2=Vector2(points[mini(points.size()-1,i+2)][0],points[mini(points.size()-1,i+2)][1])
   var t:=clampf((x-a.x)/(b.x-a.x),0,1)
   var ma:float=(b.y-before.y)/(b.x-before.x);var mb:float=(after.y-a.y)/(after.x-a.x)
   var center:float=(2*t*t*t-3*t*t+1)*a.y+(t*t*t-2*t*t+t)*(b.x-a.x)*ma+(-2*t*t*t+3*t*t)*b.y+(t*t*t-t*t)*(b.x-a.x)*mb
   var slope:float=lerpf(ma,mb,t)
   return center-float(p.road_half_width_m)*sqrt(1+slope*slope)-.05
 return float(points[-1][1])-float(p.road_half_width_m)-.05
static func front_polygon(left:float,right:float,back:float,p:Dictionary)->PackedVector2Array:
 var ring:=PackedVector2Array([Vector2(left,back),Vector2(right,back)])
 var count:int=ceili((right-left)/.35)
 for i in range(count+1):
  var x:=lerpf(right,left,float(i)/count);ring.append(Vector2(x,curb_z(x,p)))
 return ring
static func name_bed(p:Dictionary)->PackedVector2Array:
 var left:float=p.letter_bed[0];var right:float=p.letter_bed[2]
 var ring:=PackedVector2Array();var count:int=ceili((right-left)/.35)
 for i in range(count+1):
  var x:=lerpf(left,right,float(i)/count);ring.append(Vector2(x,curb_z(x,p)-float(p.border_depth_m)))
 for i in range(count+1):
  var x:=lerpf(right,left,float(i)/count);ring.append(Vector2(x,curb_z(x,p)))
 return ring

static func ground_height(at:Vector2,original:float,base:float,p:Dictionary)->float:
 # One local grade feeds paving, soil, plant roots and both collision worlds.
 if at.x<float(p.upper_left_x)-8 or at.x>float(p.upper_right_x)+8 or at.y<303 or at.y>359:return original
 var wing:float=1.0-smoothstep(float(p.upper_wing_front_z),float(p.upper_wing_front_z)+3,at.y)
 var left:float=lerpf(float(p.side_ranges[0][0])-1.2,float(p.upper_left_x),wing)
 var right:float=lerpf(float(p.side_ranges[1][1])+1.2,float(p.upper_right_x),wing)
 var distance:float=maxf(left-at.x,at.x-right)
 var weight:float=(1.0-smoothstep(0,8,distance))*smoothstep(303,float(p.back_z),at.y)*(1.0-smoothstep(351,359,at.y))
 var fraction:float=clampf((at.y-upper_z(p))/(float(p.origin_xz[1])-upper_z(p)),0,1)
 var target:float=lerpf(base+float(p.risers)*float(p.rise_m)-.02,base-.18,fraction)
 return lerpf(original,target,weight)

static func promenade_polygons()->Array[PackedVector2Array]:
 var roads:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads
 for road:Dictionary in roads:
  if int(road.osm_way_id)==1076344125:
   # Keep the same two-metre ribbon and 12 cm edging as the red-path generator.
   return preload("res://scripts/shared/road_geometry.gd").polygons([road],.12)
 assert(false,"Missing registered lake promenade")
 return []

static func upper_polygon(p:Dictionary)->PackedVector2Array:
 # The plaza ends at the landward promenade edge; the red ribbon crosses its entire frontage.
 var ribbons:=promenade_polygons()
 var cuts:Array[float]=[float(p.upper_left_x),float(p.upper_right_x)]
 for ring:PackedVector2Array in ribbons:
  for v:Vector2 in ring:
   if v.x>float(p.upper_left_x) and v.x<float(p.upper_right_x) and not cuts.has(v.x):cuts.append(v.x)
 cuts.sort()
 var outline:=PackedVector2Array()
 for x:float in cuts:
  var south:float=-INF
  for ring:PackedVector2Array in ribbons:
   for i in ring.size():
    var a:Vector2=ring[i];var b:Vector2=ring[(i+1)%ring.size()]
    if x<minf(a.x,b.x)-.0001 or x>maxf(a.x,b.x)+.0001:continue
    if absf(a.x-b.x)<.00001:south=maxf(south,maxf(a.y,b.y))
    else:south=maxf(south,lerpf(a.y,b.y,clampf((x-a.x)/(b.x-a.x),0,1)))
  assert(is_finite(south),"Plaza edge must meet the registered promenade")
  outline.append(Vector2(x,south))
 outline.append(Vector2(p.upper_right_x,p.upper_wing_front_z))
 outline.append(Vector2(p.upper_left_x,p.upper_wing_front_z))
 return outline
