extends "res://tests/nonbuilding_reference_geometry.gd"
## Bath and fifth canteen share one source compound; the duplicate must not block the south road.
func verify_reference(world: Node3D) -> bool:
	var member: Node3D = world.get_node("Feature_83981_0")
	var owner: Node3D = world.get_node("Feature_77492_0")
	var shared: Dictionary = member.get_meta("shared_geometry",{})
	if member.get_child_count()!=0 or shared.get("id","")!="77492" or int(shared.get("part",-1))!=0:
		push_error("Bath reference still generates an independent legacy volume")
		return false
	if owner.get_meta("shared_official_ids",[])!=["77492","83981"] or owner.get_child_count()==0:
		push_error("Shared canteen/bath owner geometry or identity missing")
		return false
	return true

func walk_limits() -> Vector2:
	return Vector2(-230,-210)

func road_z(x: float) -> float:
	# OSM 544369566 v1 first segment, unchanged centerline and width.
	return 0.4341+(-201.3293-x)*8.7053/39.0128
