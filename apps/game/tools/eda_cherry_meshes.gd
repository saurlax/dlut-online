extends RefCounted
## Small five-petal blossom clusters, separate from the large upright magnolia cups.
## Tree dimensions and flower density are visual approximations.
var generator
var lod := 0

func build(source, variant: int, detail: int) -> ArrayMesh:
	generator=source
	lod=detail
	generator.detail=detail
	generator.rng.seed=27092026+variant*7919
	generator.wood=SurfaceTool.new()
	generator.wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	generator.foliage=SurfaceTool.new()
	generator.foliage.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height:=4.8+variant*0.3
	var lean:=Vector3(0.12*(variant-1),0,0.09)
	var previous:=Vector3.ZERO
	for i in 7:
		var t:=float(i+1)/7
		var point:=Vector3.UP*height*0.29*t+lean*t*t
		generator.twig(previous,point,lerpf(0.18,0.12,float(i)/7),lerpf(0.18,0.12,t),true)
		previous=point
	var fork:=previous
	var scaffolds: Array[Vector3]=[]
	for arm in 4:
		var angle:=arm*TAU/4+variant*0.27
		var end:=fork+Vector3(cos(angle),0,sin(angle))*0.92+Vector3.UP*height*0.42
		generator.twig(fork,fork.lerp(end,0.85),0.095,0.025)
		scaffolds.append(end)
	for i in 12:
		var t:=float(i)/12
		var arm:=i%4
		var level:=floori(float(i)/4)
		var angle: float=arm*TAU/4+variant*0.27+(level-1)*0.35+generator.rng.randf_range(-0.15,0.15)
		var outward:=Vector3(cos(angle),0,sin(angle))
		var root:=fork.lerp(scaffolds[arm],0.3+level*0.275)
		var radius: float=(1.8+variant*0.10)*sin((t*0.65+0.2)*PI)*generator.rng.randf_range(0.9,1.1)
		var shoulder:=root+outward*radius*0.5+Vector3.UP*0.48
		var end:=root+outward*radius+Vector3.UP*0.85
		generator.twig(root,shoulder,lerpf(0.07,0.04,t),0.033)
		generator.twig(shoulder,end,0.033,0.007)
		for j in 7:
			var attach:=shoulder.lerp(end,0.15+float(j)*0.12)
			var side:=outward.rotated(Vector3.UP,(-1.0 if j%2 else 1.0)*generator.rng.randf_range(0.55,1.15))
			var tip: Vector3=attach+side*generator.rng.randf_range(0.5,0.95)+Vector3.UP*generator.rng.randf_range(0.2,0.5)
			generator.twig(attach,tip,0.012,0.002)
			for k in 3:
				var at:=attach.lerp(tip,0.18+float(k)*0.38)
				cluster(at,side,variant*1000+i*28+j*4+k)
	var mesh:=ArrayMesh.new()
	generator.wood.index()
	generator.wood.generate_tangents()
	generator.wood.set_material(load("res://assets/campuses/eda/materials/cherry_bark.tres"))
	generator.wood.commit(mesh,Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	generator.foliage.index()
	generator.foliage.generate_tangents()
	generator.foliage.set_material(load("res://assets/campuses/eda/materials/cherry_blossoms.tres"))

	# Millimetre-scale filaments need full vertex precision within the whole-tree bounds.
	generator.foliage.commit(mesh,0 if lod==0 else Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	mesh.set_meta("kind","cherry")
	mesh.set_meta("variant",variant)
	mesh.set_meta("lod",lod)
	mesh.set_meta("flower_geometry","five notched pale petals in short-stalked clusters")
	if lod==0:
		mesh.set_meta("flower_center_extra_triangles",30)
		mesh.set_meta("flower_center_stamens",7)
	return mesh

func cluster(at: Vector3, branch: Vector3, seed_value: int) -> void:
	var phase:=float(seed_value)*2.399963
	for i in 7:
		if (lod==0 and i in [2,4]) or (lod==1 and i not in [1,5]): continue
		var angle:=phase+i*2.399963
		var direction:=Vector3(cos(angle),sin(angle*1.7)*0.6,sin(angle)).normalized()
		var end:=at+direction*(0.075+0.045*sin(float(i)*1.6+phase))
		if lod==0 and i==3: generator.twig(at,end,0.0017,0.0007)
		var normal: Vector3=(direction+Vector3.UP*0.18+branch*0.1).normalized()
		var radius: float=(0.030+0.006*sin(phase+float(i)*1.3))*(1.8 if lod==1 else 1.0)
		var pink:=Color("f4e2e7").lerp(Color("fff8f1"),(sin(angle*1.3)+1.0)*0.5)
		flower(end,normal,radius,pink,angle)

func flower(at: Vector3, normal: Vector3, radius: float, color: Color, phase: float) -> void:
	var x:=normal.cross(Vector3.UP).normalized()
	if x.length_squared()<0.1: x=normal.cross(Vector3.RIGHT).normalized()
	var y:=normal.cross(x).normalized()
	# Five lobes have a shallow notch at their outer tip, not a pointed leaf shape.
	var outline:=PackedVector2Array([Vector2(0,0.1),Vector2(-0.48,0.55),Vector2(-0.35,0.96),Vector2(0,0.86),Vector2(0.35,0.96),Vector2(0.48,0.55)])
	if lod==1: outline=PackedVector2Array([Vector2(0,0.1),Vector2(-0.48,0.55),Vector2(0,0.96),Vector2(0.48,0.55)])
	for petal in 5:
		var angle:=phase+petal*TAU/5
		var along:=x*cos(angle)+y*sin(angle)
		var across:=normal.cross(along)
		# Triangulate the outline from its inner tip: 4 triangles per close petal,
		# 2 per distant petal. Keep five petals in both LODs.
		for j in range(1,outline.size()-1):
			var coords: Array[Vector2]=[outline[0],outline[j],outline[j+1]]
			var points: Array[Vector3]=[]
			for uv in coords:
				points.append(at+(across*uv.x+along*uv.y)*radius+normal*radius*0.12*sin(uv.y*PI))
			if (points[2]-points[0]).cross(points[1]-points[0]).dot(normal)<0:
				points.reverse()
				coords.reverse()
			generator.triangle(generator.foliage,points[0],points[1],points[2],color,coords[0]+Vector2(0.5,0),coords[1]+Vector2(0.5,0),coords[2]+Vector2(0.5,0))
		if petal==0 and lod==1:
			var center:=at+normal*radius*0.08
			generator.triangle(generator.foliage,center+x*radius*0.12,center+(-x*0.5+y*0.866)*radius*0.12,center+(-x*0.5-y*0.866)*radius*0.12,Color("ac9762"))
	if lod==0: flower_center(at,normal,x,y,radius,phase)

func flower_center(at: Vector3, normal: Vector3, x: Vector3, y: Vector3, radius: float, phase: float) -> void:
	# A shallow pale cup closes the petal roots above the five back sepals.
	var center:=at+normal*radius*0.04
	for i in 5:
		var angle:=phase+i*TAU/5
		var next:=phase+(i+1)*TAU/5
		var a:=at+(x*cos(angle)+y*sin(angle))*radius*0.26+normal*radius*0.11
		var b:=at+(x*cos(next)+y*sin(next))*radius*0.26+normal*radius*0.11
		generator.triangle(generator.foliage,center,b,a,Color("efdde1"))
	# Seven fine filaments/anthers plus sepals and the replacement cup add 30 faces.
	for i in 7:
		var angle:=phase+i*TAU/7
		var radial:=x*cos(angle)+y*sin(angle)
		var across:=normal.cross(radial)
		var root:=at+radial*radius*0.055+normal*radius*0.07
		var tip:=root+radial*radius*(0.19+0.025*(i%3))+normal*radius*(0.28+0.045*(i%4))
		var half_width:=radius*(0.009+0.0015*(i%3))
		var a:=root-across*half_width
		var b:=root+across*half_width
		var c:=tip+across*half_width*0.7
		var d:=tip-across*half_width*0.7
		# The existing blossom material is double-sided; keep a consistent front winding.
		if (c-a).cross(b-a).dot(normal)<0:
			generator.triangle(generator.foliage,a,c,b,Color("eee5cb"))
			generator.triangle(generator.foliage,a,d,c,Color("eee5cb"))
		else:
			generator.triangle(generator.foliage,a,b,c,Color("eee5cb"))
			generator.triangle(generator.foliage,a,c,d,Color("eee5cb"))
		var size:=radius*(0.025+0.0075*(i%3))
		var head_a:=tip+radial*size
		var head_b:=tip+(-radial*0.5+across*0.866)*size
		var head_c:=tip+(-radial*0.5-across*0.866)*size
		if (head_c-head_a).cross(head_b-head_a).dot(normal)<0:
			generator.triangle(generator.foliage,head_a,head_c,head_b,Color("a88947"))
		else:
			generator.triangle(generator.foliage,head_a,head_b,head_c,Color("a88947"))
	for i in 5:
		var angle:=phase+(i+0.5)*TAU/5
		var radial:=x*cos(angle)+y*sin(angle)
		var across:=normal.cross(radial)
		var base:=at-normal*radius*0.09
		var a:=base+radial*radius*0.08-across*radius*0.07
		var b:=base+radial*radius*0.08+across*radius*0.07
		var c:=at+radial*radius*0.32-normal*radius*0.025
		var tint:=Color("925257").lerp(Color("72805a"),float(i%3)*0.25)
		if (c-a).cross(b-a).dot(-normal)<0:
			generator.triangle(generator.foliage,a,c,b,tint)
		else:
			generator.triangle(generator.foliage,a,b,c,tint)
