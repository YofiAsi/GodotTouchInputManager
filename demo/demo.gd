extends Control
## Minimal gesture visualizer for GodotTouchInputManager.
##
## Listens to every GestureManager signal via `any_gesture` and shows a running
## log plus a marker at the latest gesture position. Works with real touch and
## with "Emulate Touch From Mouse" / the desktop emulation key bindings.

const MAX_LINES := 14

@onready var _log: Label = %Log
@onready var _title: Label = %Title

var _lines: PackedStringArray = []
var _marker_position := Vector2.ZERO
var _marker_visible := false


func _ready() -> void:
	_title.text = "GodotTouchInputManager demo — touch / drag / swipe / pinch / twist"
	GestureManager.any_gesture.connect(_on_any_gesture)


func _on_any_gesture(gesture_name: StringName, event: InputEvent) -> void:
	# Skip the high-frequency raw stream to keep the log readable.
	if gesture_name == &"raw_gesture":
		return

	_push_line("%s  →  %s" % [gesture_name, event])

	if gesture_name == &"cancel":
		_marker_visible = false
		queue_redraw()
		return

	# `position` is read dynamically because InputEvent has no such property; the
	# concrete gesture subclasses do.
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
