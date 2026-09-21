extends RefCounted

const RADIUS := 0.75
const CORNERS := [0,2]
const SEGMENTS := 8

static func arc(ring: PackedVector2Array, corner: int) -> PackedVector2Array:
	var vertex := ring[corner]
	var before := (ring[posmod(corner-1,ring.size())]-vertex).normalized()
	var after := (ring[(corner+1)%ring.size()]-vertex).normalized()
	var angle := acos(clampf(before.dot(after),-1.0,1.0))
	var tangent := RADIUS/tan(angle*0.5)
	assert(tangent<vertex.distance_to(ring[posmod(corner-1,ring.size())])*0.25)
	assert(tangent<vertex.distance_to(ring[(corner+1)%ring.size()])*0.25)
	var center := vertex+(before+after).normalized()*RADIUS/sin(angle*0.5)
	var first := vertex+before*tangent-center
	var last := vertex+after*tangent-center
	var sweep := atan2(first.cross(last),first.dot(last))
	var points := PackedVector2Array()
	for i in SEGMENTS+1:
		points.append(center+first.rotated(sweep*i/SEGMENTS))
	return points

static func rounded(ring: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for corner in ring.size():
		if corner in CORNERS:
			result.append_array(arc(ring,corner))
		else:
			result.append(ring[corner])
	return result
