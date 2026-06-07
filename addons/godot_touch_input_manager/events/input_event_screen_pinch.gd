class_name InputEventScreenPinch
extends InputEventAction
## Two fingers moving toward or away from each other (zoom).

var position: Vector2
var relative: float
var distance: float
var fingers: int
var raw_gesture: RawGesture


func _init(_raw_gesture: RawGesture = null, event: InputEventScreenDrag = null) -> void:
	raw_gesture = _raw_gesture
	if raw_gesture:
		fingers = raw_gesture.drags.size()
		position = raw_gesture.centroid("drags", "position")

		distance = 0.0
		for drag in raw_gesture.drags.values():
			distance += (drag.position - position).length()

		var centroid_relative_position: Vector2 = event.position - position
		relative = (centroid_relative_position + event.relative).length() - centroid_relative_position.length()


func _to_string() -> String:
	return "position=%s|relative=%s|distance=%s|fingers=%d" % [position, relative, distance, fingers]
