extends Control
## Visualizer for the GodotTouchInputManager gestures.
##
## Connects to every GestureManager signal, shows a running log, draws a marker at
## the latest gesture position, and demonstrates the long_press_drag lifecycle with
## a real press-drag-release radial menu. Works with real touch and, on desktop,
## with "Emulate Touch From Mouse" (single-finger gestures only).

const MAX_LINES := 14

## Radial menu geometry.
const MENU_RADIUS := 120.0 ## Distance from center to each option label.
const MENU_DEAD_ZONE := 36.0 ## Release/hover inside this radius selects nothing.
const MENU_OPTIONS: PackedStringArray = ["Cut", "Copy", "Paste", "Delete", "Share", "Rename"]

@onready var _log: Label = %Log
@onready var _title: Label = %Title

var _lines: PackedStringArray = []
var _marker_position := Vector2.ZERO
var _marker_visible := false

# Radial menu state, driven by the long_press_drag lifecycle.
var _menu_open := false
var _menu_center := Vector2.ZERO
var _menu_highlight := -1

# Drawing happens on a top-most overlay so it renders above the opaque background
# and the log panel (a parent Control's own _draw is painted under its children).
var _overlay: Control


func _ready() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay) # added last -> drawn on top of every sibling
	_overlay.draw.connect(_draw_overlay)

	_title.text = (
		"GodotTouchInputManager demo\n"
		+ "Touch: tap, swipe (1 finger) — tap / long-press (2+ fingers).\n"
		+ "Long-press one finger to open a radial menu, drag to an option, release to pick.\n"
		+ "Desktop (Emulate Touch From Mouse): click = tap, hold = menu, flick = swipe."
	)
	GestureManager.single_tap.connect(_on_gesture.bind(&"single_tap"))
	GestureManager.long_press_drag.connect(_on_long_press_drag)
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
		_overlay.queue_redraw()


func _on_long_press_drag(event: InputEventSingleScreenLongPressDrag) -> void:
	match event.phase:
		InputEventSingleScreenLongPressDrag.Phase.BEGIN:
			_menu_open = true
			_menu_center = event.position
			_menu_highlight = -1
			_push_line("long_press_drag  →  BEGIN @ %s" % event.position)
		InputEventSingleScreenLongPressDrag.Phase.UPDATE:
			_menu_highlight = _option_at(event.relative)
		InputEventSingleScreenLongPressDrag.Phase.END:
			if _menu_highlight >= 0:
				_push_line("long_press_drag  →  selected '%s'" % MENU_OPTIONS[_menu_highlight])
			else:
				_push_line("long_press_drag  →  END (no selection)")
			_menu_open = false
		InputEventSingleScreenLongPressDrag.Phase.CANCEL:
			_push_line("long_press_drag  →  CANCEL")
			_menu_open = false
	_overlay.queue_redraw()


## Maps an offset from the menu center to an option index, or -1 inside the dead zone.
func _option_at(offset: Vector2) -> int:
	if offset.length() < MENU_DEAD_ZONE:
		return -1
	var count := MENU_OPTIONS.size()
	var slice := TAU / count
	# angle() is in [-PI, PI]; shift by half a slice so each option is centered on its angle.
	var index := int(floor((offset.angle() + slice * 0.5) / slice))
	return ((index % count) + count) % count


func _push_line(line: String) -> void:
	_lines.append(line)
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	_log.text = "\n".join(_lines)


func _draw_overlay() -> void:
	if _marker_visible and not _menu_open:
		_overlay.draw_circle(_marker_position, 24.0, Color(0.2, 0.8, 1.0, 0.5))
		_overlay.draw_circle(_marker_position, 6.0, Color.WHITE)
	if _menu_open:
		_draw_radial_menu()


func _draw_radial_menu() -> void:
	var font := ThemeDB.fallback_font
	var font_size := ThemeDB.fallback_font_size
	var count := MENU_OPTIONS.size()
	var slice := TAU / count

	_overlay.draw_circle(_menu_center, MENU_DEAD_ZONE, Color(1, 1, 1, 0.08))
	_overlay.draw_circle(_menu_center, 5.0, Color.WHITE)

	for i in count:
		var angle := slice * i
		var spot := _menu_center + Vector2.RIGHT.rotated(angle) * MENU_RADIUS
		var highlighted := i == _menu_highlight
		var radius := 40.0 if highlighted else 32.0
		var fill := Color(0.2, 0.8, 1.0, 0.85) if highlighted else Color(0.15, 0.18, 0.22, 0.85)
		_overlay.draw_circle(spot, radius, fill)

		var text := MENU_OPTIONS[i]
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := spot - text_size * 0.5 + Vector2(0, font_size * 0.35)
		_overlay.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
