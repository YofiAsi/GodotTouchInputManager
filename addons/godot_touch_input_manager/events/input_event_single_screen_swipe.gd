class_name InputEventSingleScreenSwipe
extends InputEventAction
## A fast single-finger flick. Carries both a discrete [member direction] and the
## raw press-to-release vector [member relative].

enum Direction { UP, DOWN, LEFT, RIGHT }

var position: Vector2 ## Where the swipe started.
var relative: Vector2 ## Raw vector from press to release.
var direction: Direction


func _init(_position: Vector2 = Vector2.ZERO, _relative: Vector2 = Vector2.ZERO) -> void:
	position = _position
	relative = _relative
	direction = _direction_of(_relative)
	pressed = true


## Classifies a vector into one of the four cardinal directions by its dominant
## axis. Screen Y grows downward, so a negative Y is "up".
static func _direction_of(vector: Vector2) -> Direction:
	if absf(vector.x) >= absf(vector.y):
		return Direction.RIGHT if vector.x >= 0.0 else Direction.LEFT
	return Direction.DOWN if vector.y >= 0.0 else Direction.UP


func _to_string() -> String:
	return "InputEventSingleScreenSwipe: position=%s|relative=%s|direction=%s" % [
		position, relative, Direction.keys()[direction]
	]
