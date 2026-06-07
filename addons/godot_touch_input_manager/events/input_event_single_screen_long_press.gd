class_name InputEventSingleScreenLongPress
extends InputEventAction
## A single finger held in place past the long-press threshold.

var position: Vector2
var raw_gesture: RawGesture


func _init(_raw_gesture: RawGesture = null) -> void:
	raw_gesture = _raw_gesture
	if raw_gesture and not raw_gesture.presses.is_empty():
		position = raw_gesture.presses.values()[0].position


func _to_string() -> String:
	return "position=%s" % position
