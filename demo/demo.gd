extends Control
## Minimal visualizer for the five GodotTouchInputManager gestures.
##
## Connects to every GestureManager signal, shows a running log, and draws a
## marker at the latest gesture position. Works with real touch and, on desktop,
## with "Emulate Touch From Mouse" (single-finger gestures only).

const MAX_LINES := 14

@onready var _log: Label = %Log
@onready var _title: Label = %Title

var _lines: PackedStringArray = []
var _marker_position := Vector2.ZERO
var _marker_visible := false


func _ready() -> void:
	_title.text = (
		"GodotTouchInputManager demo\n"
		+ "Touch: tap, long-press, swipe (1 finger) — tap / long-press (2+ fingers).\n"
		+ "Desktop (Emulate Touch From Mouse): click = tap, hold = long-press,\n"
		+ "flick = swipe. Multi-finger gestures need a real device."
	)
	GestureManager.single_tap.connect(_on_gesture.bind(&"single_tap"))
	GestureManager.single_long_press.connect(_on_gesture.bind(&"single_long_press"))
	GestureManager.swipe_up.connect(_on_gesture.bind(&"swipe_up"))
	GestureManager.swipe_down.connect(_on_gesture.bind(&"swipe_down"))
	GestureManager.swipe_left.connect(_on_gesture.bind(&"swipe_left"))
	GestureManager.swipe_right.connect(_on_gesture.bind(&"swipe_right"))
	GestureManager.multi_tap.connect(_on_gesture.bind(&"multi_tap"))
	GestureManager.multi_long_press.connect(_on_gesture.bind(&"multi_long_press"))


func _on_gesture(event: InputEvent, gesture_name: StringName) -> void:
	_push_line("%s  →  %s" % [gesture_name, event])
	var gesture_position: Variant = event.get("position")
	if gesture_position != null:
		_marker_position = gesture_position
		_marker_visible = true
		queue_redraw()


func _push_line(line: String) -> void:
	_lines.append(line)
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	_log.text = "\n".join(_lines)


func _draw() -> void:
	if _marker_visible:
		draw_circle(_marker_position, 24.0, Color(0.2, 0.8, 1.0, 0.5))
		draw_circle(_marker_position, 6.0, Color.WHITE)
