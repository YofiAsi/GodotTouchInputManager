class_name InputEventSingleScreenLongPress
extends InputEventAction
## A single finger held in place past the long-press threshold.

var position: Vector2


func _init(_position: Vector2 = Vector2.ZERO) -> void:
	position = _position
	pressed = true


func _to_string() -> String:
	return "InputEventSingleScreenLongPress: position=%s" % position
