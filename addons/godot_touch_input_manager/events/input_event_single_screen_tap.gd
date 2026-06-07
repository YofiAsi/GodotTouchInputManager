class_name InputEventSingleScreenTap
extends InputEventAction
## A quick single-finger tap (press and release within the tap thresholds).

var position: Vector2


func _init(_position: Vector2 = Vector2.ZERO) -> void:
	position = _position
	pressed = true


func _to_string() -> String:
	return "InputEventSingleScreenTap: position=%s" % position
