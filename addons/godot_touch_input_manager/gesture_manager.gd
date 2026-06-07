extends Node
## Touch gesture recognizer (autoload singleton "GestureManager").
##
## Consumes native [InputEventScreenTouch] / [InputEventScreenDrag] events,
## classifies them into high-level gestures, and republishes each as a custom
## [InputEventAction] subclass (via [method Input.parse_input_event]) and as a
## matching signal. On desktop, gestures can be emulated with the keyboard/mouse
## bindings registered when [member GestureSettings.default_bindings] is on.
##
## This script is intended to be autoloaded; access it globally as `GestureManager`.

const _DEFAULT_SETTINGS := preload("default_gesture_settings.tres")
const _SETTINGS_PATH_SETTING := "godot_touch_input_manager/settings_path"

## Maps an emulation action suffix to the swipe direction it represents.
const SWIPE_TO_DIRECTION := {
	"swipe_up": Vector2.UP,
	"swipe_up_right": Vector2.UP + Vector2.RIGHT,
	"swipe_right": Vector2.RIGHT,
	"swipe_down_right": Vector2.DOWN + Vector2.RIGHT,
	"swipe_down": Vector2.DOWN,
	"swipe_down_left": Vector2.DOWN + Vector2.LEFT,
	"swipe_left": Vector2.LEFT,
	"swipe_up_left": Vector2.UP + Vector2.LEFT,
}

## Low-level, pre-classification touch event (used by desktop emulation).
signal touch(event: InputEventScreenTouch)
## Low-level, pre-classification drag event (used by desktop emulation).
signal drag(event: InputEventScreenDrag)
signal single_touch(event: InputEventSingleScreenTouch)
signal single_tap(event: InputEventSingleScreenTap)
signal single_drag(event: InputEventSingleScreenDrag)
signal single_swipe(event: InputEventSingleScreenSwipe)
signal single_long_press(event: InputEventSingleScreenLongPress)
signal multi_tap(event: InputEventMultiScreenTap)
signal multi_drag(event: InputEventMultiScreenDrag)
signal multi_swipe(event: InputEventMultiScreenSwipe)
signal multi_long_press(event: InputEventMultiScreenLongPress)
signal pinch(event: InputEventScreenPinch)
signal twist(event: InputEventScreenTwist)
## Emitted on every raw touch/drag with the live [RawGesture] state.
signal raw_gesture(gesture: RawGesture)
signal cancel(event: InputEventScreenCancel)
## Meta-signal fired alongside every gesture above: `(signal_name, event)`.
signal any_gesture(name: StringName, event: InputEvent)

enum Gesture { PINCH, MULTI_DRAG, TWIST, SINGLE_DRAG, NONE }

## Active configuration. Defaults to the bundled resource (or the one named by
## the `godot_touch_input_manager/settings_path` project setting). Reassignable
## at runtime.
var settings: GestureSettings

var raw_gesture_data: RawGesture = RawGesture.new()

var _mouse_event_press_position: Vector2
var _mouse_event: int = Gesture.NONE

var _drag_startup_timer := Timer.new()
var _long_press_timer := Timer.new()

var _single_touch_cancelled: bool = false
var _single_drag_enabled: bool = false


func _ready() -> void:
	_load_settings()

	# Emit events even if the scene tree is paused.
	process_mode = (
		Node.PROCESS_MODE_ALWAYS if settings.process_when_paused else Node.PROCESS_MODE_INHERIT
	)

	_setup_timer(_drag_startup_timer, _on_drag_startup_timer_timeout)
	_setup_timer(_long_press_timer, _on_long_press_timer_timeout)

	if settings.default_bindings:
		_register_default_bindings()


func _load_settings() -> void:
	var path := str(ProjectSettings.get_setting(_SETTINGS_PATH_SETTING, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var resource := load(path)
		if resource is GestureSettings:
			settings = resource
			return
	settings = _DEFAULT_SETTINGS


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	else:
		_handle_action(event)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if raw_gesture_data.size() == 1 and _mouse_event == Gesture.SINGLE_DRAG:
		_dispatch(&"drag", _native_drag_event(0, event.position, event.relative, event.velocity))
	elif raw_gesture_data.size() == 2 and _mouse_event == Gesture.MULTI_DRAG:
		var offset := Vector2(5, 5)
		var e0 := _native_drag_event(0, event.position - offset, event.relative, event.velocity)
		raw_gesture_data._update_screen_drag(e0)
		var e1 := _native_drag_event(1, event.position + offset, event.relative, event.velocity)
		raw_gesture_data._update_screen_drag(e1)
		_dispatch(&"multi_drag", InputEventMultiScreenDrag.new(raw_gesture_data, e0))
		_dispatch(&"multi_drag", InputEventMultiScreenDrag.new(raw_gesture_data, e1))
	elif _mouse_event == Gesture.TWIST:
		var rel1 := event.position - _mouse_event_press_position
		var rel2 := rel1 + event.relative
		var twist_event := InputEventScreenTwist.new()
		twist_event.position = _mouse_event_press_position
		twist_event.relative = rel1.angle_to(rel2)
		twist_event.fingers = 2
		_dispatch(&"twist", twist_event)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.index < 0:
		_dispatch(&"cancel", InputEventScreenCancel.new(raw_gesture_data, event))
		_end_gesture()
		return

	# Ignore orphaned release events (release with no matching press on record).
	if not event.pressed and not raw_gesture_data.presses.has(event.index):
		return

	raw_gesture_data._update_screen_touch(event)
	_dispatch(&"raw_gesture", raw_gesture_data)

	if event.pressed:
		if raw_gesture_data.size() == 1: # First and only touch.
			_long_press_timer.start(settings.long_press_time_threshold)
			_single_touch_cancelled = false
			_dispatch(&"single_touch", InputEventSingleScreenTouch.new(raw_gesture_data))
		elif not _single_touch_cancelled:
			_single_touch_cancelled = true
			_cancel_single_drag()
			_dispatch(&"single_touch", InputEventSingleScreenTouch.new(raw_gesture_data))
	else:
		var fingers := raw_gesture_data.size()
		if event.index == 0:
			_dispatch(&"single_touch", InputEventSingleScreenTouch.new(raw_gesture_data))
			if not _single_touch_cancelled:
				var distance: float = (
					raw_gesture_data.releases[0].position - raw_gesture_data.presses[0].position
				).length()
				if (
					raw_gesture_data.elapsed_time < settings.tap_time_limit
					and distance <= settings.tap_distance_limit
				):
					_dispatch(&"single_tap", InputEventSingleScreenTap.new(raw_gesture_data))
				if (
					raw_gesture_data.elapsed_time < settings.swipe_time_limit
					and distance > settings.swipe_distance_threshold
				):
					_dispatch(&"single_swipe", InputEventSingleScreenSwipe.new(raw_gesture_data))
		if raw_gesture_data.active_touches == 0: # Last finger released.
			if _single_touch_cancelled:
				_try_emit_multi_release(fingers)
			_end_gesture()
		_cancel_single_drag()


## Emits a multi-tap or multi-swipe if the just-completed multi-finger gesture
## qualifies. Only called once the last finger of a multi-touch lifts off.
func _try_emit_multi_release(fingers: int) -> void:
	var distance: float = (
		raw_gesture_data.centroid("releases", "position")
		- raw_gesture_data.centroid("presses", "position")
	).length()
	var released_together := _released_together(
		raw_gesture_data, settings.multi_finger_release_threshold
	)

	if (
		raw_gesture_data.elapsed_time < settings.tap_time_limit
		and distance <= settings.tap_distance_limit
		and raw_gesture_data.is_consistent(settings.tap_distance_limit, settings.finger_size * fingers)
		and released_together
	):
		_dispatch(&"multi_tap", InputEventMultiScreenTap.new(raw_gesture_data))
	if (
		raw_gesture_data.elapsed_time < settings.swipe_time_limit
		and distance > settings.swipe_distance_threshold
		and raw_gesture_data.is_consistent(settings.finger_size, settings.finger_size * fingers)
		and released_together
	):
		_dispatch(&"multi_swipe", InputEventMultiScreenSwipe.new(raw_gesture_data))


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index < 0:
		_dispatch(&"cancel", InputEventScreenCancel.new(raw_gesture_data, event))
		_end_gesture()
		return

	raw_gesture_data._update_screen_drag(event)
	_dispatch(&"raw_gesture", raw_gesture_data)

	if raw_gesture_data.drags.size() > 1:
		_cancel_single_drag()
		match _identify_gesture(raw_gesture_data):
			Gesture.PINCH:
				_dispatch(&"pinch", InputEventScreenPinch.new(raw_gesture_data, event))
			Gesture.MULTI_DRAG:
				_dispatch(&"multi_drag", InputEventMultiScreenDrag.new(raw_gesture_data, event))
			Gesture.TWIST:
				_dispatch(&"twist", InputEventScreenTwist.new(raw_gesture_data, event))
	elif _single_drag_enabled:
		_dispatch(&"single_drag", InputEventSingleScreenDrag.new(raw_gesture_data))
	elif _drag_startup_timer.is_stopped():
		_drag_startup_timer.start(settings.drag_startup_time)


## Desktop emulation: translate registered keyboard/mouse actions into gestures.
func _handle_action(event: InputEvent) -> void:
	# `is_pressed()` (not `.pressed`) so this stays valid for the base InputEvent type.
	var pressed := event.is_pressed()
	if _is_action(event, "single_touch"):
		_dispatch(&"touch", _native_touch_event(0, _mouse_position(), pressed))
		_mouse_event = Gesture.SINGLE_DRAG if pressed else Gesture.NONE
	elif _is_action(event, "multi_touch"):
		_dispatch(&"touch", _native_touch_event(0, _mouse_position(), pressed))
		_dispatch(&"touch", _native_touch_event(1, _mouse_position(), pressed))
		_mouse_event = Gesture.MULTI_DRAG if pressed else Gesture.NONE
	elif _is_action(event, "twist"):
		_mouse_event_press_position = _mouse_position()
		_mouse_event = Gesture.TWIST if pressed else Gesture.NONE
	elif _is_action_pressed(event, "pinch_outward") or _is_action_pressed(event, "pinch_inward"):
		var pinch_event := InputEventScreenPinch.new()
		pinch_event.fingers = 2
		pinch_event.position = _mouse_position()
		pinch_event.distance = 400.0
		pinch_event.relative = -40.0 if _is_action_pressed(event, "pinch_inward") else 40.0
		_dispatch(&"pinch", pinch_event)
	else:
		_handle_swipe_emulation(event)


func _handle_swipe_emulation(event: InputEvent) -> void:
	for suffix in SWIPE_TO_DIRECTION:
		var direction: Vector2 = SWIPE_TO_DIRECTION[suffix]
		var relative := direction * settings.swipe_distance_threshold * 2.0
		if _is_action_pressed(event, "single_" + suffix):
			var single := InputEventSingleScreenSwipe.new()
			single.position = _mouse_position()
			single.relative = relative
			_dispatch(&"single_swipe", single)
			return
		if _is_action_pressed(event, "multi_" + suffix):
			var multi := InputEventMultiScreenSwipe.new()
			multi.fingers = 2
			multi.position = _mouse_position()
			multi.relative = relative
			_dispatch(&"multi_swipe", multi)
			return


## Publishes an event: prints if debugging, fires the named signal and the
## `any_gesture` meta-signal, and feeds it back into the input system so it can
## be picked up via `_input`/`is_action_pressed`.
func _dispatch(signal_name: StringName, event: InputEvent) -> void:
	if settings.debug:
		print("[GestureManager] %s: %s" % [signal_name, event])
	any_gesture.emit(signal_name, event)
	emit_signal(signal_name, event)
	Input.parse_input_event(event)


func _cancel_single_drag() -> void:
	_single_drag_enabled = false
	_drag_startup_timer.stop()


## True if all fingers were released within `threshold` seconds of each other.
func _released_together(gesture: RawGesture, threshold: float) -> bool:
	var rolled_back: RawGesture = gesture.rollback_relative(threshold)[0]
	return rolled_back.size() == rolled_back.active_touches


## Classifies a 2+ finger drag as PINCH, TWIST or MULTI_DRAG by checking which
## angular sector each finger's motion falls into relative to the centroid.
func _identify_gesture(gesture: RawGesture) -> int:
	var center: Vector2 = gesture.centroid("drags", "position")

	var sector: int = -1
	for drag in gesture.drags.values():
		var adjusted_position: Vector2 = center - drag.position
		var raw_angle: float = fmod(adjusted_position.angle_to(drag.relative) + (PI / 4), TAU)
		var adjusted_angle: float = raw_angle if raw_angle >= 0 else raw_angle + TAU
		var drag_sector: int = int(floor(adjusted_angle / (PI / 2)))
		if sector == -1:
			sector = drag_sector
		elif sector != drag_sector:
			return Gesture.MULTI_DRAG

	# Opposite sectors (0/2) mean fingers move along the centroid axis -> pinch;
	# perpendicular sectors (1/3) mean they orbit the centroid -> twist.
	if sector == 0 or sector == 2:
		return Gesture.PINCH
	return Gesture.TWIST


func _on_drag_startup_timer_timeout() -> void:
	_single_drag_enabled = raw_gesture_data.drags.size() == 1


func _on_long_press_timer_timeout() -> void:
	var ends_centroid: Vector2 = GestureUtil.centroid(raw_gesture_data.get_ends().values())
	var starts_centroid: Vector2 = raw_gesture_data.centroid("presses", "position")
	var distance := (ends_centroid - starts_centroid).length()

	var held_still := (
		raw_gesture_data.releases.is_empty()
		and distance <= settings.long_press_distance_limit
		and raw_gesture_data.is_consistent(
			settings.long_press_distance_limit, settings.finger_size * raw_gesture_data.size()
		)
	)
	if not held_still:
		return

	if _single_touch_cancelled:
		_dispatch(&"multi_long_press", InputEventMultiScreenLongPress.new(raw_gesture_data))
	else:
		_dispatch(&"single_long_press", InputEventSingleScreenLongPress.new(raw_gesture_data))


func _end_gesture() -> void:
	_single_drag_enabled = false
	_long_press_timer.stop()
	raw_gesture_data = RawGesture.new()


# --- Input helpers --------------------------------------------------------------

func _mouse_position() -> Vector2:
	return get_viewport().get_mouse_position()


func _is_action(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and (
		event.is_action_pressed(action) or event.is_action_released(action)
	)


func _is_action_pressed(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action)


func _native_touch_event(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var native_touch := InputEventScreenTouch.new()
	native_touch.index = index
	native_touch.position = position
	native_touch.pressed = pressed
	return native_touch


func _native_drag_event(
	index: int, position: Vector2, relative: Vector2, velocity: Vector2
) -> InputEventScreenDrag:
	var native_drag := InputEventScreenDrag.new()
	native_drag.index = index
	native_drag.position = position
	native_drag.relative = relative
	native_drag.velocity = velocity
	return native_drag


# --- Desktop emulation bindings -------------------------------------------------

func _setup_timer(timer: Timer, on_timeout: Callable) -> void:
	timer.one_shot = true
	timer.timeout.connect(on_timeout)
	add_child(timer)


func _register_default_bindings() -> void:
	_add_key_action("multi_swipe_up", KEY_I)
	_add_key_action("multi_swipe_up_right", KEY_O)
	_add_key_action("multi_swipe_right", KEY_L)
	_add_key_action("multi_swipe_down_right", KEY_PERIOD)
	_add_key_action("multi_swipe_down", KEY_COMMA)
	_add_key_action("multi_swipe_down_left", KEY_M)
	_add_key_action("multi_swipe_left", KEY_J)
	_add_key_action("multi_swipe_up_left", KEY_U)

	_add_key_action("single_swipe_up", KEY_W)
	_add_key_action("single_swipe_up_right", KEY_E)
	_add_key_action("single_swipe_right", KEY_D)
	_add_key_action("single_swipe_down_right", KEY_C)
	_add_key_action("single_swipe_down", KEY_X)
	_add_key_action("single_swipe_down_left", KEY_Z)
	_add_key_action("single_swipe_left", KEY_A)
	_add_key_action("single_swipe_up_left", KEY_Q)

	_add_mouse_button_action("single_touch", MOUSE_BUTTON_LEFT)
	_add_mouse_button_action("multi_touch", MOUSE_BUTTON_MIDDLE)
	_add_mouse_button_action("pinch_outward", MOUSE_BUTTON_WHEEL_UP)
	_add_mouse_button_action("pinch_inward", MOUSE_BUTTON_WHEEL_DOWN)
	_add_mouse_button_action("twist", MOUSE_BUTTON_RIGHT)


func _add_key_action(action: StringName, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	_set_default_action(action, event)


func _add_mouse_button_action(action: StringName, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	_set_default_action(action, event)


func _set_default_action(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		InputMap.action_add_event(action, event)
