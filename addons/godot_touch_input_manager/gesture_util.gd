class_name GestureUtil
extends RefCounted
## Small stateless helpers shared across the addon.
##
## Replaces the old `Util.gd`. `map_callv` is gone: callers now use GDScript
## lambdas with `Array.map` instead of string-name reflection.

const _SEC_IN_USEC: float = 1_000_000.0


## Average of a non-empty array of values that support `+` and `/` (e.g. Vector2).
## Precondition: `points` is not empty.
static func centroid(points: Array) -> Variant:
	var sum: Variant = points[0]
	for i in range(1, points.size()):
		sum += points[i]
	return sum / points.size()


## Current monotonic time in seconds.
static func now() -> float:
	return Time.get_ticks_usec() / _SEC_IN_USEC
