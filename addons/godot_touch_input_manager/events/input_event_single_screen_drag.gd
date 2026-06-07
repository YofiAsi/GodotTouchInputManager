class_name InputEventSingleScreenDrag
extends InputEventAction
## A single finger dragging across the screen.

var position: Vector2
var relative: Vector2
var raw_gesture: RawGesture


func _init(_raw_gesture: RawGesture = null) -> void:
	raw_gesture = _raw_gesture
	if raw_gesture:
		var drag: RawGesture.Drag = raw_gesture.drags.values()[0]
		position = drag.position
		relative = drag.relative


func _to_string() -> String:
	return "position=%s|relative=%s" % [position, relative]
