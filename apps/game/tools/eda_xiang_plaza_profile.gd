extends RefCounted
static func load_profile() -> Dictionary:
 return JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/xiang_plaza.json"))
static func masks() -> Array[PackedVector2Array]:
 var p:=load_profile()
 var result:Array[PackedVector2Array]=[]
 for side:Array in p.side_ranges:
  result.append(PackedVector2Array([Vector2(side[0],p.back_z),Vector2(side[1],p.back_z),Vector2(side[1],p.origin_xz[1]),Vector2(side[0],p.origin_xz[1])]))
 result.append(PackedVector2Array([Vector2(-127,342.2),Vector2(-110,342.2),Vector2(-110,345.5),Vector2(-127,345.5)]))
 return result
static func garden_height(terrain, at:Vector2) -> float:
 var base:float=terrain.elevation(-118.5,342)
 return base+0.32+0.96*clampf((342.0-at.y)/22.0,0,1)
