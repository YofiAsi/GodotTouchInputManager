class_name InputEventScreenCancel
extends InputEventAction
## Emitted when an in-progress gesture is interrupted (e.g. the OS cancels the touch).

var raw_gesture: RawGesture
var event: InputEvent


func _init(_raw_gesture: RawGesture = null, _event: InputEvent = null) -> void:
	raw_gesture = _raw_gesture
	event = _event


func _to_string() -> String:
	return "gesture canceled"
