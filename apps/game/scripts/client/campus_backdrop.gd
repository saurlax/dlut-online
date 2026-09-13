@tool
extends Node3D
## Camera-only shots of existing photo-supported facades; no gameplay or physics.

const SHOT_DURATION := 14.0
const FADE_DURATION := 0.8
const SHOTS := [
	[Vector3(75, 12, 65), Vector3(112, 14, 58), Vector3(85, 12, -45)],
	[Vector3(110, 12, 245), Vector3(73, 14, 239), Vector3(88, 12, 140)],
	[Vector3(-1020, 14, -535), Vector3(-1010, 16, -500), Vector3(-865, 14, -512)],
]
var shot_index := 0
var elapsed := 0.0

func _ready() -> void:
	set_shot(0)

func set_shot(index: int) -> void:
	shot_index = posmod(index, SHOTS.size())
	elapsed = 0.0
	_update_camera()

func advance(delta: float) -> void:
	elapsed += delta
	while elapsed >= SHOT_DURATION:
		elapsed -= SHOT_DURATION
		shot_index = (shot_index + 1) % SHOTS.size()
	_update_camera()

func fade_alpha() -> float:
	return 1.0 - smoothstep(0.0, FADE_DURATION, minf(elapsed, SHOT_DURATION - elapsed))

func _update_camera() -> void:
	if not is_node_ready(): return
	var shot: Array = SHOTS[shot_index]
	var progress: float = smoothstep(0.0, 1.0, elapsed / SHOT_DURATION)
	var start: Vector3 = shot[0]
	$Camera.look_at_from_position(start.lerp(shot[1], progress), shot[2], Vector3.UP)
