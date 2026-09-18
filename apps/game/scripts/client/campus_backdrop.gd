@tool
extends Node3D
## Camera-only shots of existing photo-supported facades; no gameplay or physics.

const Graphics = preload("res://scripts/client/graphics_settings.gd")
const CAMPUS_DATA := "res://assets/campuses/lingshui/data/campus.json"
# Landmark ID, stand-off distance and lateral travel. Facade comes from its registration.
# Positions come from current OSM geometry, never the former map coordinates.
const SHOT_LANDMARKS := [
	["77386", 100.0, 36.0],
	["77447", 100.0, 36.0],
	["77357", 110.0, 36.0],
]
const SHOT_DURATION := 14.0
const FADE_DURATION := 0.8
var shots: Array = []
var shot_index := 0
var elapsed := 0.0

func _ready() -> void:
	if not Engine.is_editor_hint():
		$WorldEnvironment.environment = $WorldEnvironment.environment.duplicate(true)
		add_to_group(Graphics.GROUP)
		apply_graphics_settings()
	shots.clear()
	var campus: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CAMPUS_DATA))
	for landmark in SHOT_LANDMARKS:
		for feature in campus.features:
			if feature.id != landmark[0] or int(feature.get("part", 0)) != 0: continue
			var outline := PackedVector2Array()
			for p in feature.points: outline.append(Vector2(p[0], p[1]))
			var edge: int = feature.facade.get("primary_edge", feature.facade.edges[0])
			var a := outline[edge]
			var b := outline[(edge + 1) % outline.size()]
			var tangent := (b - a).normalized()
			var outward := Vector2(-tangent.y, tangent.x)
			var center := (a + b) * 0.5
			if Geometry2D.is_point_in_polygon(center + outward * 0.1, outline):
				outward = -outward
			var node: Node3D = $CampusModel.get_node("Feature_" + feature.id + "_0")
			var target_height := float(feature.height) * 0.48
			var target := Vector3(center.x, target_height, center.y)
			var near := center + outward * float(landmark[1])
			var start := near - tangent * float(landmark[2]) * 0.5
			var finish := near + tangent * float(landmark[2]) * 0.5
			shots.append([node.to_global(Vector3(start.x, target_height, start.y)),
				node.to_global(Vector3(finish.x, target_height + 2.0, finish.y)), node.to_global(target)])
			break
	assert(shots.size() == SHOT_LANDMARKS.size(), "Missing opening-camera landmark geometry")
	set_shot(0)

func set_shot(index: int) -> void:
	shot_index = posmod(index, shots.size())
	elapsed = 0.0
	_update_camera()

func advance(delta: float) -> void:
	elapsed += delta
	while elapsed >= SHOT_DURATION:
		elapsed -= SHOT_DURATION
		shot_index = (shot_index + 1) % shots.size()
	_update_camera()

func fade_alpha() -> float:
	return 1.0 - smoothstep(0.0, FADE_DURATION, minf(elapsed, SHOT_DURATION - elapsed))

func _update_camera() -> void:
	if not is_node_ready(): return
	var shot: Array = shots[shot_index]
	var progress: float = smoothstep(0.0, 1.0, elapsed / SHOT_DURATION)
	var start: Vector3 = shot[0]
	$Camera.look_at_from_position(start.lerp(shot[1], progress), shot[2], Vector3.UP)

func apply_graphics_settings() -> void:
	Graphics.apply_viewport(get_viewport())
	Graphics.apply_environment($WorldEnvironment.environment, $Sun)
