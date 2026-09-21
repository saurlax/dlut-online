extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")
const CASES := [["77931",0.69],["77933",0.28],["77935",-1.0],["77937",0.4],["77938",0.58],["77941",-1.0]]
var facade_path
var base := 0.0

func mapped(p: Vector3) -> Vector3:
	return (facade_path.mapped(p) if facade_path != null else p)+Vector3.UP*base

func _initialize() -> void: run.call_deferred()

func hit(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, expected: Vector3, label: String) -> void:
	var result := space.intersect_ray(PhysicsRayQueryParameters3D.create(mapped(from),mapped(to)))
	assert(not result.is_empty(),label+" missing collision")
	assert(result.position.distance_to(mapped(expected))<0.06,label+" wrong surface: "+str(result.position))

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/buildings/residence_facades.json"))
	var bases: Dictionary = {}
	var reference: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	for c in CASES: bases[c[0]] = reference.get_node("Feature_"+c[0]).position.y
	reference.free()
	for server in [false,true]:
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		root.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		if server:
			world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(model)
			for c in CASES:
				var group := model.get_node("Feature_"+c[0])
				# Residence four includes ground grilles/entry materials; four and five each add one numeral material.
				assert(group.get_child_count()<=(16 if c[0]=="77937" else 11 if c[0]=="77938" else 10 if c[0] in ["77931","77933","77935"] else 9),"Keep material batching per residence: "+str(c[0]))
				var expected_edges: Dictionary = {"77931":[2,1,0],"77933":[2,1,3],"77935":[1,2],"77937":[4,1,2],"77938":[1,3,4],"77941":[1,2,3]}
				assert(group.get_meta("photo_edges")==expected_edges[c[0]],"Photo facade moved off registered OSM walls")
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for c in CASES:
			var feature: Dictionary
			for f in manifest.features:
				if f.id == c[0]: feature = f
			var points := PackedVector2Array()
			for p in feature.points: points.append(Vector2(p[0],p[1]))
			var registration: Dictionary = profiles[c[0]].osm_registration
			assert(feature.osm_id==registration.osm_id and int(feature.osm_version)==int(registration.osm_version))
			base = bases[c[0]]
			facade_path = null
			var a := points[int(registration.edge)]
			var b := points[(int(registration.edge)+1)%points.size()]
			if registration.get("reverse_edge",false):
				var old_a := a
				a = b
				b = old_a
			var axis := (b-a).normalized()
			var out := Vector2(axis.y,-axis.x)
			if Geometry2D.is_point_in_polygon((a+b)*0.5+out,points): out = -out
			if registration.has("facade_vertices"):
				facade_path = preload("res://tools/residence_facade_path.gd").new()
				facade_path.configure(points,registration.facade_vertices)
				a = facade_path.origin
				axis = facade_path.axis
				out = facade_path.outward
				b = a+axis*facade_path.length
			var normal := Vector3(out.x,0,out.y)
			var p := a.lerp(b,0.07)
			var wall := Vector3(p.x,5,p.y)
			hit(space,wall+normal*2,wall-normal*2,wall,c[0]+" closed shell")
			p = a.lerp(b,0.4)-out*2
			var lower: bool = c[0] in ["77937","77938"]
			var roof := Vector3(p.x,20.05 if lower else 23.2,p.y)
			hit(space,roof+Vector3.UP*3,roof-Vector3.UP*3,roof,c[0]+" roof")
			p = a.lerp(b,0.43)+out*0.7
			var gallery := Vector3(p.x,16.19 if lower else 19.34,p.y)
			if c[0]=="77941":
				assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(mapped(gallery+Vector3.UP*0.8),mapped(gallery-Vector3.UP*0.8))).is_empty(),"Do not copy an unverified gallery to residence six")
			else:
				hit(space,gallery+Vector3.UP*0.8,gallery-Vector3.UP*0.8,gallery,c[0]+" gallery slab")
			if c[0] in ["77931","77933"]:
				for fraction in [0.25,0.43,0.75]:
					p = a.lerp(b,fraction)
					var enclosure := Vector3(p.x,21.0,p.y)
					hit(space,enclosure+normal*2,enclosure-normal,enclosure+normal*0.91,c[0]+" continuous gallery glazing")
				var outer_fraction := 0.96 if c[0]=="77931" else 0.04
				p = a.lerp(b,outer_fraction)+out*0.9
				var outer_eave := Vector3(p.x,23.21,p.y)
				hit(space,outer_eave+Vector3.UP*2,outer_eave-Vector3.UP*2,outer_eave,c[0]+" outer end eave")
			if c[0]=="77937":
				var eave_tip := a.distance_to(b)*0.18-0.25
				var eave_join := a.distance_to(b)*(0.18+0.64*0.2)
				p = a+axis*((eave_tip+eave_join)/2)+out*1.0
				var eave_top := 19.95+0.4+0.11*sqrt(1+pow(0.8/(eave_join-eave_tip),2))
				var eave := Vector3(p.x,eave_top,p.y)
				hit(space,eave+Vector3.UP*2,eave-Vector3.UP*2,eave,"Fourth residence raised eave")
				# Trace against the new enclosure itself, not the retained wall behind it.
				for sample in [[0.43,17.5,0.91],[0.42,8.3,1.23],[0.42,11.4,1.23]]:
					p = a.lerp(b,float(sample[0]))
					var enclosure := Vector3(p.x,float(sample[1]),p.y)
					hit(space,enclosure+normal*3,enclosure-normal,enclosure+normal*float(sample[2]),"Fourth residence sealed glazing")
			if c[0]=="77938":
				var tip := a.distance_to(b)*0.82+0.25
				var join := a.distance_to(b)*(0.82-0.64*0.2)
				p = a+axis*((tip+join)/2)+out*1.0
				var top := 19.95+0.4+0.11*sqrt(1+pow(0.8/(tip-join),2))
				var eave := Vector3(p.x,top,p.y)
				hit(space,eave+Vector3.UP*2,eave-Vector3.UP*2,eave,"Fifth residence raised eave")
			if c[0]=="77935":
				for bay in 7:
					var fraction := 0.14+0.72*(bay+0.5)/7
					var at := a.lerp(b,fraction)-out*1.5
					var floor_at := Vector3(at.x,0.03,at.y)
					hit(space,floor_at+Vector3.UP,floor_at-Vector3.UP,floor_at,"Third arcade floor")
					var ceiling_at := Vector3(at.x,3.5,at.y)
					hit(space,ceiling_at-Vector3.UP,ceiling_at+Vector3.UP,ceiling_at,"Third arcade soffit")
					var rear := Vector3(at.x,1.5,at.y)-normal*1.5
					hit(space,rear+normal,rear-normal,rear,"Third arcade closed rear")
					var capsule := CapsuleShape3D.new()
					capsule.radius=0.3
					capsule.height=1.8
					var query := PhysicsShapeQueryParameters3D.new()
					query.shape=capsule
					query.transform.origin=mapped(Vector3(at.x,1.05,at.y))
					assert(space.intersect_shape(query).is_empty(),"Third arcade walking clearance")
				p = a.lerp(b,0.8875)
				var recessed_wall := Vector3(p.x,5.1,p.y)
				hit(space,recessed_wall+normal*1.5,recessed_wall-normal*1.5,recessed_wall-normal*0.8,"Third residence recessed gallery wall")
				var slab := Vector3(p.x,6.84,p.y)-normal*0.4
				hit(space,slab+Vector3.UP*0.5,slab-Vector3.UP*0.5,slab,"Third residence recessed gallery slab")
			if c[1]>0:
				p = a.lerp(b,c[1])+axis*a.distance_to(b)*0.025+out*0.7
				for y in ([6.8,9.95,13.1] if lower else [9.95,13.1,16.25]):
					var slab := Vector3(p.x,y,p.y)
					hit(space,slab+Vector3.UP*0.7,slab-Vector3.UP*0.7,slab,c[0]+" balcony slab")
			if c[0]=="77937":
				facade_path = preload("res://tools/residence_facade_path.gd").new()
				facade_path.configure(points,[1,2,3])
				var court_length: float = facade_path.length
				for fraction in [0.5,0.869,0.871,0.98]:
					var station: float = court_length*fraction
					var center_y := 19.95+0.8*maxf(0,station-court_length*0.87)/(court_length*0.13+0.8)
					var at: Vector2 = facade_path.origin+facade_path.axis*station+facade_path.outward*1.8
					for direction in [-1.0,1.0]:
						var surface := Vector3(at.x,center_y+direction*0.11,at.y)
						hit(space,surface+Vector3.UP*direction*0.5,surface-Vector3.UP*direction*0.2,surface,"Fourth courtyard eave top/underside")
		print("RESIDENCES PHYSICS PASS: server=",server," six registered facade chains, roofs, galleries, eaves, enclosures and balcony slabs")
		world.free()
		viewport.free()
	print("PASS: six batched photo facades; client/server closed shells, roofs, galleries and balcony slabs")
	quit()
