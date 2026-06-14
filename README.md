# Godot Touch Input Manager

A small, focused **touch gesture** addon for **Godot 4.6+**. Autoload one singleton and it
analyzes native touch input, recognizing a handful of gestures and delivering each both as a
**signal** and as a **custom `InputEvent`** (fed through Godot's input system via
[`Input.parse_input_event`](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-parse-input-event),
so they reach `_input` / `_unhandled_input` like any other event).

This is a modernized, slimmed-down fork of the original
[GodotTouchInputManager](https://github.com/Federico-Ciuffardi/GodotTouchInputManager) by
Federico Ciuffardi.

## Supported gestures

| Signal | Custom InputEvent | Description |
|---|---|---|
| `single_tap` | `InputEventSingleScreenTap` | Quick press & release with one finger |
| `long_press_drag` | `InputEventSingleScreenLongPressDrag` | One finger held past the threshold, then optionally dragged and released — a `BEGIN → UPDATE… → END` lifecycle (plus `CANCEL`). Great for in-place radial / context menus |
| `swipe_up` / `swipe_down` / `swipe_left` / `swipe_right` | `InputEventSingleScreenSwipe` | Fast one-finger flick; event carries `direction` + raw `relative` vector |
| `multi_tap` | `InputEventMultiScreenTap` | Quick press & release with 2+ fingers |
| `multi_long_press` | `InputEventMultiScreenLongPress` | 2+ fingers held in place past the threshold |

> `long_press_drag` **replaces** the old single-finger `single_long_press`. A plain long press is
> now a `BEGIN` followed by an `END` with little or no movement.

Event fields:
- **Tap:** `position: Vector2`
- **Long press drag:** `phase: InputEventSingleScreenLongPressDrag.Phase` (`BEGIN`/`UPDATE`/`END`/`CANCEL`), `position: Vector2` (origin — where the press began, constant), `current: Vector2` (live finger position), `relative: Vector2` (`current - position`)
- **Swipe:** `position: Vector2` (start), `relative: Vector2` (raw press→release), `direction: InputEventSingleScreenSwipe.Direction` (`UP`/`DOWN`/`LEFT`/`RIGHT`)
- **Multi tap / long press:** `position: Vector2` (centroid), `fingers: int`, `positions: Array` (per-finger starts)

## Installation

1. Copy the `addons/godot_touch_input_manager/` folder into your project.
2. Enable the plugin: **Project → Project Settings → Plugins → Godot Touch Input Manager**.
3. Enabling it registers the **`GestureManager`** autoload automatically. That's it.

## Usage

### Connect to a signal (simplest)

```gdscript
func _ready() -> void:
    GestureManager.swipe_left.connect(_on_swipe_left)
    GestureManager.single_tap.connect(_on_tap)

func _on_swipe_left(event: InputEventSingleScreenSwipe) -> void:
    player.dash(Vector2.LEFT)

func _on_tap(event: InputEventSingleScreenTap) -> void:
    print("tapped at ", event.position)
```

### Driving a press-drag-release menu

`long_press_drag` is a multi-phase gesture: connect once and switch on `event.phase` to open a
menu where the press began, track the finger as it drags, and commit (or cancel) on release.

```gdscript
func _ready() -> void:
    GestureManager.long_press_drag.connect(_on_long_press_drag)

func _on_long_press_drag(event: InputEventSingleScreenLongPressDrag) -> void:
    match event.phase:
        InputEventSingleScreenLongPressDrag.Phase.BEGIN:
            menu.open_at(event.position)               # the long press happened here
        InputEventSingleScreenLongPressDrag.Phase.UPDATE:
            menu.highlight(event.current)              # finger is dragging while held
        InputEventSingleScreenLongPressDrag.Phase.END:
            menu.commit(event.current)                 # released — pick the option
        InputEventSingleScreenLongPressDrag.Phase.CANCEL:
            menu.dismiss()                             # touch was canceled
```

### Or handle it as an InputEvent

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventSingleScreenSwipe:
        if event.direction == InputEventSingleScreenSwipe.Direction.LEFT:
            player.dash(Vector2.LEFT)
    elif event is InputEventSingleScreenTap:
        select(event.position)
```

### Driving an Input Map action

Godot's **Input Map** editor cannot list custom event types, so gestures can't be bound there
alongside keys/joypad. To make a gesture drive a named action (so `Input.is_action_*` responds),
create the action in Project Settings and bridge it in code:

```gdscript
func _ready() -> void:
    GestureManager.swipe_left.connect(_trigger.bind(&"move_left"))

func _trigger(_event: InputEvent, action: StringName) -> void:
    Input.action_press(action)               # just_pressed this frame
    Input.action_release.call_deferred(action)
```

## Configuration

All thresholds live in a `GestureSettings` resource. The addon ships
`addons/godot_touch_input_manager/default_gesture_settings.tres`. To customize, duplicate that
`.tres`, edit it in the Inspector, and either:
- set its path in **Project Settings → `godot_touch_input_manager/settings_path`**, or
- assign it at runtime: `GestureManager.settings = preload("res://my_gestures.tres")`.

| Property | Default | Description |
|---|---|---|
| `process_when_paused` | `true` | Keep recognizing gestures while the SceneTree is paused |
| `debug` | `false` | Print every emitted gesture to the Output panel |
| `tap_time_limit` | `0.2` | Max duration (s) of a tap |
| `tap_distance_limit` | `25.0` | Max travel (px) allowed during a tap |
| `long_press_time_threshold` | `0.75` | Hold time (s) to trigger a long press |
| `long_press_distance_limit` | `25.0` | Max travel (px) allowed during a long press |
| `swipe_time_limit` | `0.5` | Max duration (s) of a swipe |
| `swipe_distance_threshold` | `200.0` | Min travel (px) for a swipe to register |

## Testing

This addon is **touch-only**. The included demo project (`demo/demo.tscn`) visualizes gestures and
includes a working press-drag-release radial menu driven by `long_press_drag`.

- **On a device:** every gesture, including the multi-finger ones.
- **On desktop:** the demo project enables *Emulate Touch From Mouse*, so single-finger gestures
  work with the mouse — **click** = tap, **click-and-hold** = open the radial menu (then drag to an
  option and release to pick), **flick** = swipe. Multi-finger gestures require a real touchscreen.

## Notes & FAQ

**Control nodes consume touch.** Gestures are detected in `_unhandled_input`, so a `Control` with
`mouse_filter = Stop` (the default) will swallow touches before they reach the recognizer. Set
`mouse_filter = Ignore` on controls that should let touches pass through. See the
[`Control.mouse_filter` docs](https://docs.godotengine.org/en/stable/classes/class_control.html#enum-control-mousefilter).

**Custom input events don't trigger physics collisions.** Like the original addon, the emitted
custom events won't drive `_input_event` collision callbacks; check positions manually if needed.

## Credits & license

- Original author: **Federico Ciuffardi** — https://github.com/Federico-Ciuffardi/GodotTouchInputManager
- Licensed under the **MIT License** (see [LICENSE](LICENSE)).
