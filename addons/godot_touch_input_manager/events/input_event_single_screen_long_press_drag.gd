class_name InputEventSingleScreenLongPressDrag
extends InputEventAction
## A single-finger long press that can then drag and release — a press-drag-release
## lifecycle for radial / contextual menus. Emitted via GestureManager.long_press_drag.
##
## Phases:
##   BEGIN   — long press recognized; open the menu at [member position].
##   UPDATE  — finger moved while still held; [member current] is the live position.
##   END     — finger lifted; commit the choice under [member current].
##   CANCEL  — gesture aborted (touch canceled); dismiss without selecting.

enum Phase { BEGIN, UPDATE, END, CANCEL }

var phase: Phase
var position: Vector2  ## Origin: where the long press began (constant for the whole lifecycle).
var current: Vector2   ## Live finger position (== position at BEGIN).
var relative: Vector2  ## current - position (total offset from the origin).


func _init(_phase := Phase.BEGIN, _position := Vector2.ZERO, _current := Vector2.ZERO) -> void:
	phase = _phase
	position = _position
	current = _current
	relative = _current - _position
	pressed = phase == Phase.BEGIN or phase == Phase.UPDATE  # END/CANCEL are "release"


func _to_string() -> String:
	return "InputEventSingleScreenLongPressDrag: phase=%s|position=%s|current=%s|relative=%s" % [
		Phase.keys()[phase], position, current, relative
	]
