extends RefCounted
## Shared roadside bands keep paving, planting exclusions and curbs on the same side.
static func bands(roads:Array, selections:Array, inner:float, outer:float)->Array[PackedVector2Array]:
	var result:Array[PackedVector2Array]=[]
	for selection:Dictionary in selections:
		for road:Dictionary in roads:
			if int(road.osm_way_id)!=int(selection.osm_way_id):continue
			for side:int in selection.sides:
				var low:=offset_points(road,selection,float(road.width)/2+inner,side)
				var high:=offset_points(road,selection,float(road.width)/2+outer,side)
				for i in range(low.size()-1):
					var ring:=PackedVector2Array([low[i],low[i+1],high[i+1],high[i]])
					if Geometry2D.is_polygon_clockwise(ring):ring.reverse()
					result.append(ring)
	return result

static func offset_points(road:Dictionary, selection:Dictionary, offset:float, side:int)->PackedVector2Array:
	var result:=PackedVector2Array()
	for i in range(int(selection.from_vertex),int(selection.to_vertex)+1):
		var at:=Vector2(road.points[i][0],road.points[i][1])
		var before:=Vector2(road.points[maxi(0,i-1)][0],road.points[maxi(0,i-1)][1])
		var after:=Vector2(road.points[mini(road.points.size()-1,i+1)][0],road.points[mini(road.points.size()-1,i+1)][1])
		var incoming:Vector2=(at-before).normalized() if i>0 else (after-at).normalized()
		var outgoing:Vector2=(after-at).normalized() if i<road.points.size()-1 else incoming
		var normal:Vector2=(incoming.orthogonal()+outgoing.orthogonal()).normalized()
		result.append(at+normal*offset*side/maxf(.5,normal.dot(incoming.orthogonal())))
	return result

static func median(profile:Dictionary)->PackedVector2Array:
	var ring:=PackedVector2Array()
	for p:Array in profile.south_median.points:ring.append(Vector2(p[0],p[1]))
	if Geometry2D.is_polygon_clockwise(ring):ring.reverse()
	return ring

static func rounded(points:PackedVector2Array, radius:float=2.0)->PackedVector2Array:
	var result:=PackedVector2Array([points[0]])
	for i in range(1,points.size()-1):
		var at:=points[i]
		var distance:=minf(radius,minf(at.distance_to(points[i-1]),at.distance_to(points[i+1]))*.3)
		var a:=at.move_toward(points[i-1],distance)
		var b:=at.move_toward(points[i+1],distance)
		for j in range(9):
			var t:=float(j)/8
			result.append(a.lerp(at,t).lerp(at.lerp(b,t),t))
	result.append(points[-1])
	return result
