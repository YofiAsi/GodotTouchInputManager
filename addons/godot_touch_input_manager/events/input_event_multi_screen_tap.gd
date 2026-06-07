class_name InputEventMultiScreenTap
extends InputEventAction
## A simultaneous tap with two or more fingers.

var position: Vector2
var positions: Array
var fingers: int
var raw_gesture: RawGesture


func _init(_raw_gesture: RawGesture = null) -> void:
	raw_gesture = _raw_gesture
	if raw_gesture:
		fingers = raw_gesture.size()
		position = raw_gesture.centroid("presses", "position")
		positions = raw_gesture.get_property_array("presses", "position")


func _to_string() -> String:
	return "position=%s|fingers=%d" % [position, fingers]
