extends RefCounted
## Predictable, finite Endless economy and optional hazard ramp.
## Changes nothing about touch range, collision or chapter/daily routes.
const FIRST_LANDMARK := 250
const LANDMARK_SPACING := 250
const LANDMARK_LEAVES := 2
const LANDMARK_SCORE := 120
const LANDMARK_WAVE_RELIEF := 3.5

static func hazard_probability(distance_m: float) -> float:
	# A learner's first river segment stays readable. Later sessions
	# gradually return to the original 20% eligible-lily probability.
	return lerpf(0.05, 0.20, smoothstep(130.0, 900.0, maxf(0.0, distance_m)))

static func crossed_landmark(old_best_m: float, next_m: float) -> int:
	# Return the newly passed absolute marker, or zero for normal hops.
	# Never reward replaying lower pads. Repeated calls for the same
	# old/new values are idempotent only if caller updates its high-water
	# mark as part of processing the landing.
	if next_m <= old_best_m or next_m < float(FIRST_LANDMARK):
		return 0
	var mark := maxi(FIRST_LANDMARK, int(floor(next_m / LANDMARK_SPACING)) * LANDMARK_SPACING)
	return mark if old_best_m < float(mark) else 0
