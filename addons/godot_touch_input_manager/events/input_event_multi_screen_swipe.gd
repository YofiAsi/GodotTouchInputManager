class_name InputEventMultiScreenSwipe
extends InputEventAction
## A fast flick with two or more fingers moving together.

var position: Vector2
var relative: Vector2
var fingers: int
var raw_gesture: RawGesture


func _init(_raw_gesture: RawGesture = null) -> void:
	raw_gesture = _raw_gesture
	if raw_gesture:
		fingers = raw_gesture.size()
		position = raw_gesture.centroid("presses", "position")
		relative = raw_gesture.centroid("releases", "position") - position


func _to_string() -> String:
	return "position=%s|relative=%s|fingers=%d" % [position, relative, fingers]
