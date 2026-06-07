class_name InputEventSingleScreenSwipe
extends InputEventAction
## A fast single-finger flick across the screen.

var position: Vector2
var relative: Vector2
var raw_gesture: RawGesture


func _init(_raw_gesture: RawGesture = null) -> void:
	raw_gesture = _raw_gesture
	if raw_gesture:
		# Read by insertion order rather than by key 0: the first finger of a
		# gesture is not guaranteed to have index 0 (it can be reused/recycled).
		position = raw_gesture.presses.values()[0].position
		relative = raw_gesture.releases.values()[0].position - position


func _to_string() -> String:
	return "position=%s|relative=%s" % [position, relative]
