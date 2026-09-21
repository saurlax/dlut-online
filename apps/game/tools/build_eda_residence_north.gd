extends RefCounted
## Additional bounded exterior on its own registered wall chain.
func build(facade, points:PackedVector2Array, p:Dictionary)->void:
 facade.facade_path=preload("res://tools/residence_facade_path.gd").new()
 facade.facade_path.configure(points,p.vertices)
 facade.origin=facade.facade_path.origin
 facade.axis=facade.facade_path.axis
 facade.outward=facade.facade_path.outward
 var length:float=facade.facade_path.length
 var first:float=p.span[0]*length
 var last:float=p.span[1]*length
 var pitch:float=(last-first)/int(p.columns)
 for y in p.centers_y:
  for col in int(p.columns):
   var x:float=first+(col+.5)*pitch
   facade.window(x,float(y),pitch*.77,2.15,true)
   facade.panel(x,float(y)-1.25,pitch*.77,.42,.07,.10,facade.accent)
   facade.panel(x+pitch*.40,float(y)-.9,pitch*.17,1.05,.08,.12,facade.accent)
  facade.panel((first+last)/2,float(y)-1.52,last-first,.14,.18,.1,facade.frame)
 for col in p.ground_columns:
  facade.window(first+(float(col)+.5)*pitch,1.7,pitch*.70,1.65)
 for y in [1.7,4.8,7.95,11.1,14.25,17.4]:
  facade.window(float(p.east_terminal_fraction)*length,y,1.8,1.65)
 for y in [1.7,4.8,7.95,11.1,14.25]:
  facade.window(float(p.west_terminal_fraction)*length,y,2.2,1.65)
 for y in p.centers_y:
  var x:float=float(p.east_narrow_fraction)*length
  facade.window(x,float(y),1.45,2.15)
  facade.railing(x,float(y)-1.0,1.5,.28,false)
 var start:float=p.gallery_span[0]*length
 var finish:float=p.gallery_span[1]*length
 var width:float=finish-start
 var center:float=p.gallery_center_y
 var height:float=p.gallery_height
 facade.panel((start+finish)/2,center,width,height,.08,.08,facade.glass)
 for i in int(p.gallery_panes)+1:
  facade.panel(start+width*i/int(p.gallery_panes),center,.055,height+.08,.12,.16,facade.frame)
 for y in [center-height/2,center+height*.25,center+height/2]:
  facade.panel((start+finish)/2,y,width,.06,.12,.16,facade.frame)
 facade.panel(length*.56,float(p.gallery_slab_y),length*.88,.22,.60,.22,facade.frame)
 # The railing may continue across the visible end terrace; rear wall stays intact.
 facade.railing(length*.565,float(p.gallery_slab_y)+.15,length*.87,.48,false)
 facade.panel(length*.51,19.95,length*.98,.22,1.15,.43,facade.frame)
