extends RefCounted
class_name ManagerAnimationPlayer
## 独立样片播放控制器：动画已离线制作，运行时只选择帧并应用记录的位移。

const DATA_PATH: String = "res://assets/tavern/manager_authored/manager_animation.json"
var data: Dictionary = {}
var clip: String = "idle"
var elapsed: float = 0.0
var position_x: float = 0.0
var facing: int = 1
var held: bool = false
var requested_direction: int = 0
var requested_held: bool = false


func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) as Dictionary


func request_motion(direction: int, with_cup: bool) -> void:
	requested_direction = clampi(direction, -1, 1)
	requested_held = with_cup
	if clip == "idle":
		held = requested_held
		if requested_direction != 0:
			facing = requested_direction
			clip = "start"
			elapsed = 0.0


func advance(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	var remaining: float = delta
	while remaining > 0.0000001:
		var duration: float = float(current_clip()["duration"])
		var step: float = minf(remaining, duration - elapsed)
		var before: float = root_at(elapsed)
		elapsed = minf(duration, elapsed + step)
		position_x += facing * (root_at(elapsed) - before)
		remaining -= step
		if elapsed >= duration - 0.0000001:
			_finish_clip()


func _finish_clip() -> void:
	elapsed = 0.0
	match clip:
		"idle":
			held = requested_held
			if requested_direction != 0:
				facing = requested_direction
				clip = "start"
		"start":
			clip = "walk" if requested_direction == facing and requested_held == held else "stop"
		"walk":
			if requested_direction != facing or requested_held != held:
				clip = "stop"
		"stop":
			clip = "idle"
			held = requested_held
			if requested_direction != 0:
				facing = requested_direction
				clip = "start"


func clip_key() -> String:
	return clip + ("_cup" if held else "")


func current_clip() -> Dictionary:
	return data["clips"][clip_key()] as Dictionary


func frame_number() -> int:
	var entry: Dictionary = current_clip()
	var count: int = int(entry["count"])
	var intervals: int = count if bool(entry["loop"]) else count - 1
	return mini(count - 1, floori(elapsed / float(entry["duration"]) * intervals + 0.000001))


func source_rect() -> Rect2:
	var entry: Dictionary = current_clip()
	var index: int = int(entry["first_frame"]) + frame_number()
	var columns: int = int(data["atlas_columns"])
	var cell: Vector2 = Vector2(float(data["cell"][0]), float(data["cell"][1]))
	return Rect2(Vector2(index % columns, index / columns) * cell, cell)


func root_at(time: float) -> float:
	var entry: Dictionary = current_clip()
	var frames: Array = entry["frames"] as Array
	var intervals: int = frames.size() if bool(entry["loop"]) else frames.size() - 1
	var progress: float = clampf(time / float(entry["duration"]), 0.0, 1.0) * intervals
	var lower: int = mini(floori(progress), frames.size() - 1)
	var upper: int = lower + 1
	var a: float = float(frames[lower]["root_x"])
	var b: float = float(entry["root_end"]) if upper >= frames.size() else float(frames[upper]["root_x"])
	return lerpf(a, b, progress - lower)
