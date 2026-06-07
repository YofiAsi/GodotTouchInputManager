class_name InputEventMultiScreenLongPress
extends InputEventAction
## Two or more fingers held in place past the long-press threshold.

var position: Vector2 ## Centroid of the finger press positions.
var positions: Array ## Per-finger press positions (Vector2).
var fingers: int


func _init(_positions: Array = []) -> void:
	positions = _positions
	fingers = _positions.size()
	position = GestureUtil.centroid(_positions) if fingers > 0 else Vector2.ZERO
	pressed = true


func _to_string() -> String:
	return "InputEventMultiScreenLongPress: position=%s|fingers=%d" % [position, fingers]
