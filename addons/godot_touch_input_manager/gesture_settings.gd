class_name GestureSettings
extends Resource
## Tunable thresholds for gesture recognition.
##
## Edit a `.tres` of this resource and point the project setting
## `godot_touch_input_manager/settings_path` at it (or assign one to
## `GestureManager.settings` at runtime) to customize behavior per project.

@export_group("Behavior")
## Emit gestures even while the SceneTree is paused.
@export var process_when_paused: bool = true
## Print every emitted gesture to the Output panel (debugging only).
@export var debug: bool = false

@export_group("Tap")
## Maximum duration of a tap (seconds).
@export var tap_time_limit: float = 0.2
## Maximum travel distance allowed during a tap (px).
@export var tap_distance_limit: float = 25.0

@export_group("Long press")
## How long a touch must be held to count as a long press (seconds).
@export var long_press_time_threshold: float = 0.75
## Maximum travel distance allowed during a long press (px).
@export var long_press_distance_limit: float = 25.0

@export_group("Swipe")
## Maximum duration of a swipe (seconds).
@export var swipe_time_limit: float = 0.5
## Minimum travel distance for a swipe to register (px).
@export var swipe_distance_threshold: float = 200.0
