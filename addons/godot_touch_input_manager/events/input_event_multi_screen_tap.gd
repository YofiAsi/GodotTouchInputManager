class_name InputEventMultiScreenTap
extends InputEventAction
## A short press in which two or more fingers were involved.

var position: Vector2 ## Centroid of the finger press positions.
var positions: Array ## Per-finger press positions (Vector2).
var fingers: int


func _init(_positions: Array = []) -> void:
	positions = _positions
	fingers = _positions.size()
	position = GestureUtil.centroid(_positions) if fingers > 0 else Vector2.ZERO
	pressed = true


func _to_string() -> String:
	return "InputEventMultiScreenTap: position=%s|fingers=%d" % [position, fingers]
