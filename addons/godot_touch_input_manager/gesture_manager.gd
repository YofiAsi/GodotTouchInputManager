extends Node
## Touch gesture recognizer (autoload singleton "GestureManager").
##
## Recognizes gestures from native touch input and republishes each as a
## custom [InputEventAction] subclass (via [method Input.parse_input_event]) and
## as a signal:
##   single_tap,
##   long_press_drag (a single-finger press-drag-release lifecycle: BEGIN/UPDATE/END/CANCEL),
##   swipe_up / swipe_down / swipe_left / swipe_right,
##   multi_tap, multi_long_press.
##
## Intended to be autoloaded; access it globally as `GestureManager`.

const _DEFAULT_SETTINGS := preload("default_gesture_settings.tres")
const _SETTINGS_PATH_SETTING := "godot_touch_input_manager/settings_path"

signal single_tap(event: InputEventSingleScreenTap)
signal long_press_drag(event: InputEventSingleScreenLongPressDrag)
signal swipe_up(event: InputEventSingleScreenSwipe)
signal swipe_down(event: InputEventSingleScreenSwipe)
signal swipe_left(event: InputEventSingleScreenSwipe)
signal swipe_right(event: InputEventSingleScreenSwipe)
signal multi_tap(event: InputEventMultiScreenTap)
signal multi_long_press(event: InputEventMultiScreenLongPress)

## Per-finger record for the gesture session in progress.
class _Finger:
	var start: Vector2
	var last: Vector2
	var down_time: float
	var up_time: float = -1.0
	var down: bool = true

## Active configuration. Defaults to the bundled resource (or the one named by
## the `godot_touch_input_manager/settings_path` project setting). Reassignable
## at runtime.
var settings: GestureSettings

# Gesture session state. A session spans from the first finger touching down
# until the last finger lifts off.
var _fingers: Dictionary = {} # int index -> _Finger
var _active_count: int = 0
var _peak_fingers: int = 0
var _session_start_time: float = 0.0
var _long_press_fired: bool = false

# Single-finger long-press-drag lifecycle (BEGIN once long press fires, then
# UPDATE per drag, then END on release or CANCEL on abort).
var _lpd_active: bool = false
var _lpd_index: int = -1 # the finger driving the drag
var _lpd_origin: Vector2

var _long_press_timer := Timer.new()


func _ready() -> void:
	_load_settings()
	process_mode = (
		Node.PROCESS_MODE_ALWAYS if settings.process_when_paused else Node.PROCESS_MODE_INHERIT
	)
	_long_press_timer.one_shot = true
	_long_press_timer.timeout.connect(_on_long_press_timeout)
	add_child(_long_press_timer)


func _load_settings() -> void:
	var path := str(ProjectSettings.get_setting(_SETTINGS_PATH_SETTING, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var resource := load(path)
		if resource is GestureSettings:
			settings = resource
			return
	settings = _DEFAULT_SETTINGS


func _unhandled_input(event: InputEvent) -> void:
	# Only native touch drives recognition. Everything else (including the custom
	# events we re-inject via parse_input_event) is ignored, so there is no loop.
	if event is InputEventScreenTouch:
		_on_screen_touch(event)
	elif event is InputEventScreenDrag:
		_on_screen_drag(event)


func _on_screen_touch(event: InputEventScreenTouch) -> void:
	if event.canceled:
		_abort_session()
	elif event.pressed:
		_on_press(event.index, event.position)
	else:
		_on_release(event.index, event.position)


func _on_screen_drag(event: InputEventScreenDrag) -> void:
	var finger: _Finger = _fingers.get(event.index)
	if finger != null:
		finger.last = event.position
	if _lpd_active and event.index == _lpd_index:
		_emit(&"long_press_drag", InputEventSingleScreenLongPressDrag.new(
			InputEventSingleScreenLongPressDrag.Phase.UPDATE, _lpd_origin, event.position
		))


func _on_press(index: int, position: Vector2) -> void:
	if _active_count == 0:
		_begin_session()
	var finger := _Finger.new()
	finger.start = position
	finger.last = position
	finger.down_time = GestureUtil.now()
	_fingers[index] = finger
	_active_count += 1
	_peak_fingers = maxi(_peak_fingers, _active_count)


func _on_release(index: int, position: Vector2) -> void:
	var finger: _Finger = _fingers.get(index)
	if finger == null: # orphaned release with no matching press
		return
	finger.last = position
	finger.up_time = GestureUtil.now()
	finger.down = false
	_active_count -= 1
	if _active_count <= 0:
		_end_session()


func _begin_session() -> void:
	_fingers.clear()
	_active_count = 0
	_peak_fingers = 0
	_long_press_fired = false
	_session_start_time = GestureUtil.now()
	_long_press_timer.start(settings.long_press_time_threshold)


func _end_session() -> void:
	_long_press_timer.stop()
	if _lpd_active:
		_emit(&"long_press_drag", InputEventSingleScreenLongPressDrag.new(
			InputEventSingleScreenLongPressDrag.Phase.END, _lpd_origin, _lpd_last_position()
		))
	elif not _long_press_fired:
		_classify_release()
	_reset_session()


func _abort_session() -> void:
	_long_press_timer.stop()
	if _lpd_active:
		_emit(&"long_press_drag", InputEventSingleScreenLongPressDrag.new(
			InputEventSingleScreenLongPressDrag.Phase.CANCEL, _lpd_origin, _lpd_last_position()
		))
	_reset_session()


func _reset_session() -> void:
	_fingers.clear()
	_active_count = 0
	_peak_fingers = 0
	_long_press_fired = false
	_lpd_active = false
	_lpd_index = -1


## Classifies a completed session (last finger just lifted) into a tap or swipe.
func _classify_release() -> void:
	var duration := GestureUtil.now() - _session_start_time

	if _peak_fingers >= 2:
		if duration < settings.tap_time_limit and not _any_finger_moved(settings.tap_distance_limit):
			_emit(&"multi_tap", InputEventMultiScreenTap.new(_finger_starts()))
		return

	var finger: _Finger = _fingers.values()[0]
	var relative: Vector2 = finger.last - finger.start
	var distance := relative.length()
	var finger_duration := finger.up_time - finger.down_time

	if distance > settings.swipe_distance_threshold and finger_duration < settings.swipe_time_limit:
		_emit_swipe(finger.start, relative)
	elif distance <= settings.tap_distance_limit and finger_duration < settings.tap_time_limit:
		_emit(&"single_tap", InputEventSingleScreenTap.new(finger.start))


func _on_long_press_timeout() -> void:
	if _long_press_fired or _active_count == 0:
		return
	if _any_finger_moved(settings.long_press_distance_limit):
		return
	_long_press_fired = true

	var held := _held_finger_starts()
	if held.size() >= 2:
		_emit(&"multi_long_press", InputEventMultiScreenLongPress.new(held))
	else:
		_begin_long_press_drag()


## Opens the single-finger press-drag-release lifecycle once a long press is
## recognized. The BEGIN phase is the long press itself; subsequent drags emit
## UPDATE and the release emits END (or CANCEL on abort).
func _begin_long_press_drag() -> void:
	for index: int in _fingers:
		var finger: _Finger = _fingers[index]
		if finger.down:
			_lpd_active = true
			_lpd_index = index
			_lpd_origin = finger.start
			_emit(&"long_press_drag", InputEventSingleScreenLongPressDrag.new(
				InputEventSingleScreenLongPressDrag.Phase.BEGIN, finger.start, finger.start
			))
			return


func _emit_swipe(start: Vector2, relative: Vector2) -> void:
	var event := InputEventSingleScreenSwipe.new(start, relative)
	match event.direction:
		InputEventSingleScreenSwipe.Direction.UP:
			_emit(&"swipe_up", event)
		InputEventSingleScreenSwipe.Direction.DOWN:
			_emit(&"swipe_down", event)
		InputEventSingleScreenSwipe.Direction.LEFT:
			_emit(&"swipe_left", event)
		InputEventSingleScreenSwipe.Direction.RIGHT:
			_emit(&"swipe_right", event)


func _emit(signal_name: StringName, event: InputEvent) -> void:
	if settings.debug:
		print("[GestureManager] %s: %s" % [signal_name, event])
	emit_signal(signal_name, event)
	Input.parse_input_event(event)


# --- Finger helpers -------------------------------------------------------------

## Last known position of the drag-driving finger, falling back to the origin.
func _lpd_last_position() -> Vector2:
	var finger: _Finger = _fingers.get(_lpd_index)
	return finger.last if finger != null else _lpd_origin


func _any_finger_moved(limit: float) -> bool:
	for finger: _Finger in _fingers.values():
		if (finger.last - finger.start).length() > limit:
			return true
	return false


func _finger_starts() -> Array:
	var starts: Array = []
	for finger: _Finger in _fingers.values():
		starts.append(finger.start)
	return starts


func _held_finger_starts() -> Array:
	var starts: Array = []
	for finger: _Finger in _fingers.values():
		if finger.down:
			starts.append(finger.start)
	return starts
