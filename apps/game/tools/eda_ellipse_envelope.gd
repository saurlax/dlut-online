extends "res://tools/eda_registered_curve.gd"

var center := Vector2.ZERO
var radii := Vector2.ONE
var rotation := 0.0
var source_vertices := PackedInt32Array()
var source_rings: Dictionary = {}

func configure(points: PackedVector2Array, profile: Dictionary, upper_envelope = null) -> void:
	super.configure(points,profile,upper_envelope)
	center=Vector2(profile.ellipse.center_xz[0],profile.ellipse.center_xz[1])
	radii=Vector2(profile.ellipse.radii_m[0],profile.ellipse.radii_m[1])
	rotation=float(profile.ellipse.rotation_rad)
	source_vertices=PackedInt32Array(profile.ellipse.source_vertices)

func ray_crossings(direction: Vector2, polygon: PackedVector2Array) -> Array[float]:
	var hits: Array[float]=[]
	for i in polygon.size():
		var a:=polygon[i]-center
		var line:=polygon[(i+1)%polygon.size()]-polygon[i]
		var divisor:=direction.cross(line)
		if absf(divisor)<0.000001: continue
		var distance:=a.cross(line)/divisor
		var along:=a.cross(direction)/divisor
		if distance>0.00001 and along>=0.0 and along<1.0: hits.append(distance)
	hits.sort()
	return hits

func target_radius(direction: Vector2, y: float) -> float:
	var outset:=0.0
	if envelope!=null:
		outset=float(envelope.profile.top_outset)*clampf((y-float(envelope.profile.start_y))/(float(envelope.profile.top_y)-float(envelope.profile.start_y)),0,1)
	var axes:=radii+Vector2.ONE*outset
	var local:=direction.rotated(-rotation)/axes
	var radius:=1.0/local.length()
	return radius

func evaluate_shift(at: Vector3) -> Vector3:
	var relative:=Vector2(at.x,at.z)-center
	var distance:=relative.length()
	if distance<0.0001: return Vector3.ZERO
	var direction:=relative/distance
	if not source_rings.has(at.y):
		var ring:=PackedVector2Array()
		for i in source_vertices: ring.append(control(i,at.y))
		source_rings[at.y]=ring
	var source:PackedVector2Array=source_rings[at.y]
	var hits:=ray_crossings(direction,source)
	if hits.is_empty(): return Vector3.ZERO
	var radius:float=hits[0]
	var delta:=target_radius(direction,at.y)-radius
	# Interior caps use the same radial map as walls. Adjacent ornaments retain
	# their offset; the field fades outside the building instead of moving wings.
	var weight:=minf(1.0,distance/radius)
	if distance>radius+2.5:
		weight=1.0-smoothstep(2.5,2.5+maxf(2.0,absf(delta)*2.0),distance-radius)
	var shift:=direction*delta*weight
	return Vector3(shift.x,0,shift.y)
