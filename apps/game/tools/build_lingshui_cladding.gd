extends RefCounted

# Photo-registered wall finishes; leave each explicitly modeled window clear.
func build(builder, group: Node3D, p: Vector2, q: Vector2, outward: Vector2, face: Dictionary) -> void:
 var length := p.distance_to(q)
 var direction := (q-p).normalized()
 var rotation := -atan2(direction.y,direction.x)
 var openings: Array[Rect2] = []
 for row in face.rows:
  for i in int(row.count):
   var fraction := lerpf(float(row.get("from",0.0)),float(row.get("to",1.0)),(i+0.5)/int(row.count))
   openings.append(Rect2(fraction*length-float(row.width)/2-0.06,float(row.bottom)-0.06,float(row.width)+0.12,float(row.height)+0.12))
 for finish in face.get("cladding",[]):
  var region := Rect2(float(finish.from)*length,float(finish.bottom),(float(finish.to)-float(finish.from))*length,float(finish.top)-float(finish.bottom))
  var pieces: Array[Rect2] = [region]
  for opening in openings:
   var remaining: Array[Rect2] = []
   for piece in pieces:
    var cut := piece.intersection(opening)
    if not cut.has_area():
     remaining.append(piece)
     continue
    for candidate in [Rect2(piece.position,Vector2(piece.size.x,cut.position.y-piece.position.y)),Rect2(Vector2(piece.position.x,cut.end.y),Vector2(piece.size.x,piece.end.y-cut.end.y)),Rect2(Vector2(piece.position.x,cut.position.y),Vector2(cut.position.x-piece.position.x,cut.size.y)),Rect2(Vector2(cut.end.x,cut.position.y),Vector2(piece.end.x-cut.end.x,cut.size.y))]:
     if candidate.has_area():
      remaining.append(candidate)
   pieces = remaining
  var material: Material = builder.material("Photo wall finish "+str(finish.color),Color(str(finish.color)))
  if finish.get("finish","") == "small_tiles":
   material = preload("res://tools/build_lingshui_tile_material.gd").new().build(builder,str(finish.color))
  elif finish.get("finish","") == "smooth":
   var smooth: StandardMaterial3D = builder.material("Photo smooth wall "+str(finish.color),Color(str(finish.color)))
   smooth.albedo_texture = null
   material = smooth
  for piece in pieces:
   var middle := piece.get_center()
   var pos := p+direction*middle.x+outward*0.025
   var node: MeshInstance3D = builder.box(group,Vector3(pos.x,middle.y,pos.y),Vector3(piece.size.x,piece.size.y,0.03),material,"PhotoWallFinish")
   if finish.get("finish","") == "small_tiles":
    preload("res://tools/build_lingshui_tile_material.gd").new().map_piece(node,middle)
   node.rotation.y = rotation
