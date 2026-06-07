class_name InputEventSingleScreenTouch
extends InputEventAction
## A single finger touching down or lifting off.

var position: Vector2
var canceled: bool
var raw_gesture: RawGesture


func _init(_raw_gesture: RawGesture = null) -> void:
	raw_gesture = _raw_gesture
	if raw_gesture:
		pressed = raw_gesture.releases.is_empty()
		if pressed:
			position = raw_gesture.presses.values()[0].position
		else:
			position = raw_gesture.releases.values()[0].position
		canceled = raw_gesture.size() > 1


func _to_string() -> String:
	return "position=%s|pressed=%s|canceled=%s" % [position, pressed, canceled]
