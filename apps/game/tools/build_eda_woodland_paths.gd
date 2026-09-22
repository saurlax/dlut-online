extends RefCounted
## Separate slabs, with planted ground visible between them; no continuous asphalt strip.
func build(host, segments:Array, masks:Array[PackedVector2Array])->void:
 masks=masks.duplicate()
 var roads:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/osm_roads.json")).roads
 # Reserve the carriageway, planted separator and raised red sidewalk.
 var vehicles:Array=roads.filter(func(r):return str(r.highway) not in ["footway","path","steps","cycleway"])
 masks.append_array(preload("res://scripts/shared/road_geometry.gd").polygons(vehicles,6.0))
 # Stone paths stop at the three-step toe, not on the square or its treads.
 for feature:Dictionary in host.manifest.features:
  if str(feature.id)!="2304850":continue
  var square:=PackedVector2Array()
  for at:Array in feature.points:square.append(Vector2(at[0],at[1]))
  masks.append_array(Geometry2D.offset_polygon(square,1.36))
 var builder=preload("res://tools/build_roads.gd").new()
 var finish=preload("res://tools/eda_surface_details.gd").new()
 var grass:MeshInstance3D=builder.emit(host,preload("res://scripts/shared/road_geometry.gd").polygons(segments),-.07,grass_material(),masks)
 grass.set_meta("woodland_grass",true)
 var stones:Array[PackedVector2Array]=[]
 for segment:Dictionary in segments:
  var a:=Vector2(segment.points[0][0],segment.points[0][1])
  var b:=Vector2(segment.points[1][0],segment.points[1][1])
  var axis:Vector2=(b-a).normalized()
  var side:=axis.orthogonal()
  var count:int=maxi(1,floori(a.distance_to(b)/.85))
  for i in count:
   var center:Vector2=a.lerp(b,(i+.5)/count)+side*sin(i*2.1+a.x)*.08
   var half_length:float=.24+.035*sin(i*1.7)
   var half_width:float=.48+.055*cos(i*2.3)
   var ring:=PackedVector2Array([center-axis*half_length-side*half_width,center+axis*half_length-side*half_width,center+axis*half_length+side*half_width,center-axis*half_length+side*half_width])
   if Geometry2D.is_polygon_clockwise(ring):ring.reverse()
   stones.append(ring)
 var slabs:MeshInstance3D=builder.emit(host,stones,-.045,finish.ground_material("EDA woodland individual stone slabs",Color("b4afa0"),1),masks)
 slabs.set_meta("woodland_stepping_stones",true)
 slabs.set_meta("slab_count",stones.size())

static func grass_material()->ShaderMaterial:
 var mat:=ShaderMaterial.new()
 mat.resource_name="EDA woodland grass gaps"
 mat.shader=preload("res://assets/vegetation/lawn.gdshader")
 mat.set_shader_parameter("procedural_path_tint",true)
 return mat
