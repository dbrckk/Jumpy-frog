extends RefCounted
## Reproducible weather fronts. Weather affects illustration only: collision,
## speed, scoring, moving-lily phases and race records are never modified.
## Chapter and Daily seeds give identical atmospheres on each replay.
const TYPES := 6
const FRONT_METERS := 78.0
const CROSSFADE_METERS := 18.0
const FORECAST_METERS := 28.0
const LABELS := ["SUNNY", "CLOUDY", "RAIN", "WINDY", "NIGHT", "NIGHT RAIN"]
const CLOUDS := [0.04, 0.86, 0.96, 0.48, 0.09, 0.88]
const RAIN := [0.0, 0.0, 0.82, 0.0, 0.0, 0.90]
const WIND := [0.05, 0.17, 0.46, 1.0, 0.10, 0.71]
const NIGHT := [0.0, 0.0, 0.0, 0.0, 1.0, 1.0]

static func at(distance_m: float, seed: int) -> Dictionary:
	var distance := maxf(0.0, distance_m)
	var front: int = int(floor(distance / FRONT_METERS))
	var kind: int = posmod(front + posmod(seed, TYPES), TYPES)
	var previous: int = posmod(kind + TYPES - 1, TYPES)
	var within: float = distance - float(front) * FRONT_METERS
	var mix: float = 1.0 if front == 0 else smoothstep(0.0, CROSSFADE_METERS, within)
	# A new front initially still looks like the old one: keep the HUD honest.
	var visible_kind: int = previous if front > 0 and mix < 0.5 else kind
	var remaining: float = float(front + 1) * FRONT_METERS - distance
	var show_forecast: bool = remaining <= FORECAST_METERS
	return {
		"kind": kind,
		"label": LABELS[visible_kind],
		"next_label": LABELS[posmod(kind + 1, TYPES)] if show_forecast else "",
		"next_in_m": maxi(1, int(ceil(remaining))) if show_forecast else 0,
		"blend": mix,
		"clouds": lerpf(float(CLOUDS[previous]), float(CLOUDS[kind]), mix) if front > 0 else float(CLOUDS[kind]),
		"rain": lerpf(float(RAIN[previous]), float(RAIN[kind]), mix) if front > 0 else float(RAIN[kind]),
		"wind": lerpf(float(WIND[previous]), float(WIND[kind]), mix) if front > 0 else float(WIND[kind]),
		"night": lerpf(float(NIGHT[previous]), float(NIGHT[kind]), mix) if front > 0 else float(NIGHT[kind])
	}

static func raindrop_budget(quality: int) -> int:
	return 9 if quality <= 0 else (22 if quality == 1 else 42)

static func gust_budget(quality: int) -> int:
	return 4 if quality <= 0 else (8 if quality == 1 else 14)
