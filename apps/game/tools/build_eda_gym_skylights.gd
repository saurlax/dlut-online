extends RefCounted

const START := -260.5
const END := -256.0
const SPACING := 51.0/7.0

func panel(facade, a: float, b: float, z0: float, z1: float, material: Material) -> void:
	facade.quad(Vector3(a,facade.roof_y(a),z0),Vector3(b,facade.roof_y(b),z0),Vector3(b,facade.roof_y(b),z1),Vector3(a,facade.roof_y(a),z1),material)
	facade.quad(Vector3(a,facade.roof_y(a)-0.45,z1),Vector3(b,facade.roof_y(b)-0.45,z1),Vector3(b,facade.roof_y(b)-0.45,z0),Vector3(a,facade.roof_y(a)-0.45,z0),material)

func segment(facade, a: float, b: float, material: Material) -> void:
	if b<=START or a>=END:
		panel(facade,a,b,-90,-12,material)
		return
	var xs: Array[float] = [a,b]
	for x in [START,END]:
		if x>a and x<b: xs.append(x)
	xs.sort()
	var zs: Array[float] = [-90,-12]
	for i in 7:
		zs.append(-75.5+i*SPACING+0.65)
		zs.append(-75.5+(i+1)*SPACING-0.65)
	zs.sort()
	for ix in xs.size()-1:
		for iz in zs.size()-1:
			var x := (xs[ix]+xs[ix+1])/2
			var z := (zs[iz]+zs[iz+1])/2
			var in_slot := false
			for slot in 7:
				if x>START and x<END and z> -75.5+slot*SPACING+0.65 and z< -75.5+(slot+1)*SPACING-0.65: in_slot=true
			if not in_slot: panel(facade,xs[ix],xs[ix+1],zs[iz],zs[iz+1],material)

func dividers(facade, material: Material) -> void:
	var finish: StandardMaterial3D = material.duplicate()
	finish.resource_name = "EDA gym eave dividers"
	finish.cull_mode = BaseMaterial3D.CULL_BACK
	for slot in 7:
		var z0 := -75.5+slot*SPACING+0.65
		var z1 := -75.5+(slot+1)*SPACING-0.65
		# Approximate five open depth cells within each of the seven main bays.
		# Slender decorative members follow the roof; they add no walk collision.
		for divider in range(1,5):
			var x := lerpf(START,END,float(divider)/5.0)
			facade.box(Vector3(x,facade.roof_y(x)-0.14,(z0+z1)/2),Vector3(0.12,0.18,z1-z0),finish)

func reveals(facade, material: Material) -> void:
	for slot in 7:
		var z0 := -75.5+slot*SPACING+0.65
		var z1 := -75.5+(slot+1)*SPACING-0.65
		var ring := PackedVector2Array([Vector2(START,z0),Vector2(END,z0),Vector2(END,z1),Vector2(START,z1)])
		var center := Vector2((START+END)/2,(z0+z1)/2)
		for i in 4:
			var a := ring[i]
			var b := ring[(i+1)%4]
			var vertices: Array[Vector3] = [Vector3(a.x,facade.roof_y(a.x),a.y),Vector3(b.x,facade.roof_y(b.x),b.y),Vector3(b.x,facade.roof_y(b.x)-0.45,b.y),Vector3(a.x,facade.roof_y(a.x)-0.45,a.y)]
			var inward := center-(a+b)/2
			if -(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).dot(Vector3(inward.x,0,inward.y))<0: vertices.reverse()
			facade.quad(vertices[0],vertices[1],vertices[2],vertices[3],material)
