class_name RawGesture
extends InputEventAction
## Live record of every touch in the gesture currently in progress.
##
## Tracks the latest press/release/drag per finger index plus a full per-finger
## history, which the recognizer in `gesture_manager.gd` analyses to classify
## gestures. The history also supports "rolling back" the gesture to an earlier
## point in time (see [method rollback_absolute]).

## A timestamped event belonging to one finger.
class Event:
	var time: float = -1.0 # seconds
	var index: int = -1

	func _to_string() -> String:
		return "ind: %d | time: %s" % [index, time]


## A press or release.
class Touch extends Event:
	var position: Vector2 = Vector2.ZERO
	var pressed: bool = false

	func _to_string() -> String:
		return "%s | pos: %s | pressed: %s" % [super._to_string(), position, pressed]


## A drag/move sample.
class Drag extends Event:
	var position: Vector2 = Vector2.ZERO
	var relative: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO

	func _to_string() -> String:
		return "%s | pos: %s | relative: %s" % [super._to_string(), position, relative]


# NOTE: these stay untyped. GDScript can't yet use the inner classes below as
# typed-Dictionary value types reliably, and nested typed collections (history)
# are unsupported. The comments document the intended value types.
var presses: Dictionary = {} # int -> Touch
var releases: Dictionary = {} # int -> Touch
var drags: Dictionary = {} # int -> Drag
var history: Dictionary = {} # int -> { "presses"/"releases"/"drags": Array[Event] }

var active_touches: int = 0

var start_time: float = -1.0 # seconds
var elapsed_time: float = -1.0 # seconds


## Number of fingers that have touched down during this gesture.
func size() -> int:
	return presses.size()


## Values of `property_name` across every event in the `events_name`
## ("presses"/"releases"/"drags") collection.
func get_property_array(events_name: String, property_name: String) -> Array:
	var events: Array = get(events_name).values()
	return events.map(func(event: Event) -> Variant: return event.get(property_name))


## Centroid of `property_name` across the `events_name` collection.
func centroid(events_name: String, property_name: String) -> Variant:
	return GestureUtil.centroid(get_property_array(events_name, property_name))


## Latest known position of every finger (drag overrides press, release overrides drag).
func get_ends() -> Dictionary:
	var ends: Dictionary = {}
	for i in presses:
		ends[i] = presses[i].position
	for i in drags:
		ends[i] = drags[i].position
	for i in releases:
		ends[i] = releases[i].position
	return ends


## True when every finger stayed within `length_limit` of its group centroid and
## moved less than `diff_limit` relative to the group — i.e. the fingers moved
## together as a rigid cluster.
func is_consistent(diff_limit: float, length_limit: float = -1.0) -> bool:
	if length_limit == -1.0:
		length_limit = INF

	var ends: Dictionary = get_ends()
	var ends_centroid: Vector2 = GestureUtil.centroid(ends.values())
	var starts_centroid: Vector2 = centroid("presses", "position")

	for i in ends:
		var start_relative_position: Vector2 = presses[i].position - starts_centroid
		var end_relative_position: Vector2 = ends[i] - ends_centroid
		var consistent: bool = (
			start_relative_position.length() < length_limit
			and end_relative_position.length() < length_limit
			and (end_relative_position - start_relative_position).length() < diff_limit
		)
		if not consistent:
			return false
	return true


## Rolls the gesture back to `time` seconds before its latest event.
## Returns `[rolled_back_gesture, discarded_events]`.
func rollback_relative(time: float) -> Array:
	return rollback_absolute(start_time + elapsed_time - time)


## Rolls the gesture back to absolute timestamp `time`, undoing every event newer
## than it. Returns `[rolled_back_gesture, discarded_events]`.
func rollback_absolute(time: float) -> Array:
	var discarded_events: Array = []
	var rg: RawGesture = copy()

	var latest_event_id: Array = rg.latest_event_id(time)
	while not latest_event_id.is_empty():
		var latest_index: int = latest_event_id[0]
		var latest_type: String = latest_event_id[1]
		var latest_event: Event = rg.history[latest_index][latest_type].pop_back()
		discarded_events.append(latest_event)
		if latest_type == "presses":
			rg.active_touches -= 1
		elif latest_type == "releases":
			rg.active_touches += 1
		if rg.history[latest_index][latest_type].is_empty():
			rg.history[latest_index].erase(latest_type)
			if rg.history[latest_index].is_empty():
				rg.history.erase(latest_index)
		latest_event_id = rg.latest_event_id(time)

	for index in rg.presses.keys():
		if rg.history.has(index):
			if rg.history[index].has("presses"):
				var presses_history: Array = rg.history[index]["presses"]
				rg.presses[index] = presses_history.back()
			else:
				rg.presses.erase(index)

			if rg.history[index].has("releases"):
				var releases_history: Array = rg.history[index]["releases"]
				# A release always follows its press, so presses.has(index) holds here.
				if releases_history.back().time < rg.presses[index].time:
					rg.releases.erase(index)
				else:
					rg.releases[index] = releases_history.back()
			else:
				rg.releases.erase(index)

			if rg.history[index].has("drags"):
				var drags_history: Array = rg.history[index]["drags"]
				# A drag needs a fresh touch after any release, so an active
				# release means the recorded drag is stale.
				if rg.releases.has(index):
					rg.drags.erase(index)
				else:
					rg.drags[index] = drags_history.back()
			else:
				rg.drags.erase(index)
		else:
			rg.presses.erase(index)
			rg.releases.erase(index)
			rg.drags.erase(index)

	return [rg, discarded_events]


## Flat, chronological list of every event in the gesture.
func get_linear_event_history() -> Array:
	return rollback_absolute(0)[1]


## Deep copy of this gesture.
func copy() -> RawGesture:
	var rg: RawGesture = get_script().new()
	rg.presses = presses.duplicate(true)
	rg.releases = releases.duplicate(true)
	rg.drags = drags.duplicate(true)
	rg.history = history.duplicate(true)
	rg.active_touches = active_touches
	rg.start_time = start_time
	rg.elapsed_time = elapsed_time
	return rg


## `[index, type]` of the newest event at or after `latest_time`, or `[]` if none.
func latest_event_id(latest_time: float = -1.0) -> Array:
	var res: Array = []
	for index in history:
		for type in history[index]:
			var event_time: float = history[index][type].back().time
			if event_time >= latest_time:
				res = [index, type]
				latest_time = event_time
	return res


func _to_string() -> String:
	var lines: PackedStringArray = ["presses: "]
	for e in presses.values():
		lines.append(str(e))
	lines.append("drags: ")
	for e in drags.values():
		lines.append(str(e))
	lines.append("releases: ")
	for e in releases.values():
		lines.append(str(e))
	return "\n".join(lines)


func _update_screen_drag(event: InputEventScreenDrag, time: float = -1.0) -> void:
	if time < 0.0:
		time = GestureUtil.now()
	var drag := Drag.new()
	drag.position = event.position
	drag.relative = event.relative
	drag.velocity = event.velocity
	drag.index = event.index
	drag.time = time
	_add_history(event.index, "drags", drag)
	drags[event.index] = drag
	elapsed_time = time - start_time


func _update_screen_touch(event: InputEventScreenTouch, time: float = -1.0) -> void:
	if time < 0.0:
		time = GestureUtil.now()
	var touch := Touch.new()
	touch.position = event.position
	touch.pressed = event.pressed
	touch.index = event.index
	touch.time = time
	if event.pressed:
		_add_history(event.index, "presses", touch)
		presses[event.index] = touch
		active_touches += 1
		releases.erase(event.index)
		drags.erase(event.index)
		if active_touches == 1:
			start_time = time
	else:
		_add_history(event.index, "releases", touch)
		releases[event.index] = touch
		active_touches -= 1
		drags.erase(event.index)
	elapsed_time = time - start_time


func _add_history(index: int, type: String, value: Event) -> void:
	if not history.has(index):
		history[index] = {}
	if not history[index].has(type):
		history[index][type] = []
	history[index][type].append(value)
