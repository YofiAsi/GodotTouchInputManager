class_name InputEventMultiScreenLongPress
extends InputEventAction
## Two or more fingers held in place past the long-press threshold.

var position: Vector2
var fingers: int
var raw_gesture: RawGesture


func _init(_raw_gesture: RawGesture = null) -> void:
	raw_gesture = _raw_gesture
	if raw_gesture:
		fingers = raw_gesture.size()
		position = raw_gesture.centroid("presses", "position")


func _to_string() -> String:
	return "position=%s|fingers=%d" % [position, fingers]
