extends SceneTree
## Pure polygon coverage regression for the existing shell/road tessellator.

const Tessellator = preload("res://tools/build_roads.gd")
const EPSILON := 0.002
var failures: Array[String] = []

func _initialize() -> void:
	var outer := PackedVector2Array([Vector2(0,0),Vector2(20,0),Vector2(20,16),Vector2(0,16)])
	var holes: Array[PackedVector2Array] = [rectangle(Vector2(5,6),Vector2(4,6),0.32),rectangle(Vector2(14,9),Vector2(3,4),-0.45)]
	check_case("two independently rotated atria",outer,holes,284.0)
	var reverse_outer := outer.duplicate()
	reverse_outer.reverse()
	var reverse_holes: Array[PackedVector2Array] = []
	for hole in holes:
		var reversed := hole.duplicate()
		reversed.reverse()
		reverse_holes.append(reversed)
	check_case("input winding normalization",reverse_outer,reverse_holes,284.0)
	var concave := PackedVector2Array([Vector2(0,0),Vector2(20,0),Vector2(20,8),Vector2(12,8),Vector2(12,16),Vector2(0,16)])
	var concave_holes: Array[PackedVector2Array] = [holes[0],rectangle(Vector2(16,4),Vector2(3,4),-0.2)]
	check_case("concave exterior retained",concave,concave_holes,220.0)
	for angle in [0.001,0.47,PI/2,2.14]:
		var rotated_holes: Array[PackedVector2Array] = []
		for hole in holes: rotated_holes.append(transform_ring(hole,angle,Vector2(105,-61)))
		check_case("rotated and translated "+str(angle),transform_ring(outer,angle,Vector2(105,-61)),rotated_holes,284.0)
	if failures.is_empty(): print("ATRIUM TESSELLATION PASS: 7 cases, area, coverage, empty holes, and nonoverlap")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func rectangle(center: Vector2, size: Vector2, angle: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		result.append(center+(corner*size/2).rotated(angle))
	return result

func transform_ring(ring: PackedVector2Array, angle: float, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in ring: result.append(p.rotated(angle)+offset)
	return result

func area(ring: PackedVector2Array) -> float:
	var sum := 0.0
	for i in range(1,ring.size()-1): sum += (ring[i]-ring[0]).cross(ring[i+1]-ring[0])/2.0
	return absf(sum)

func normalized(ring: PackedVector2Array) -> PackedVector2Array:
	var result := ring.duplicate()
	if Geometry2D.is_polygon_clockwise(result): result.reverse()
	return result

func verify(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func check_case(label: String, outer: PackedVector2Array, holes: Array[PackedVector2Array], expected: float) -> void:
	var rings: Array[PackedVector2Array] = [normalized(outer)]
	var cutouts: Array[PackedVector2Array] = []
	for hole in holes: cutouts.append(normalized(hole))
	var pieces: Array[PackedVector2Array] = Tessellator.new().tessellate(rings,cutouts)
	var total := 0.0
	for i in pieces.size():
		var polygon := pieces[i]
		var size := area(polygon)
		verify(size>0,label+": degenerate strip")
		total += size
		for hole in cutouts:
			var overlap := 0.0
			for intersection in Geometry2D.intersect_polygons(polygon,hole): overlap += area(intersection)
			verify(overlap<EPSILON,label+": roof face fills an atrium")
		for j in range(i):
			var overlap := 0.0
			for intersection in Geometry2D.intersect_polygons(polygon,pieces[j]): overlap += area(intersection)
			verify(overlap<EPSILON,label+": overlapping roof strips")
	verify(absf(total-expected)<EPSILON,label+": area mismatch "+str(total))
	# Independent interior probes catch lost concave wings and unintended fills.
	var bounds := Rect2(outer[0],Vector2.ZERO)
	for p in outer: bounds=bounds.expand(p)
	var all_rings: Array[PackedVector2Array] = rings+cutouts+pieces
	for x in 41:
		for y in 33:
			var point := bounds.position+bounds.size*Vector2((x+0.371)/41.0,(y+0.619)/33.0)
			if near_boundary(point,all_rings): continue
			var wanted := Geometry2D.is_point_in_polygon(point,outer)
			for hole in holes:
				if Geometry2D.is_point_in_polygon(point,hole): wanted=false
			var found := 0
			for piece in pieces:
				if Geometry2D.is_point_in_polygon(point,piece): found+=1
			verify(found==(1 if wanted else 0),label+": coverage mismatch at "+str(point))

func near_boundary(point: Vector2, rings: Array[PackedVector2Array]) -> bool:
	for ring in rings:
		for i in ring.size():
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,ring[i],ring[(i+1)%ring.size()]))<0.002: return true
	return false
