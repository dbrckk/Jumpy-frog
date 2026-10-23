extends RefCounted
## Optional campaign forks. Never moves the mandatory course or consumes RNG.
## A stricter-than-215px gesture budget guarantees both entry and return.
const START_ID := 4
const PERIOD := 5
const FORK_ID_OFFSET := 2000000
const DRAG_LIMIT := 202.0
const SIDE_OFFSET := 94.0
const LABELS := ["SUN ARC", "PETAL PATH", "REED RUN", "MOON PATH", "PRISM ROUTE", "RAPID DASH"]
const SCORES := [100, 120, 145, 125, 200, 170]
const RELIEF := [5.0, 0.0, 7.0, 0.0, 0.0, 6.0]
const FLOW := [0.0, 3.5, 0.0, 0.0, 0.0, 2.5]

static func eligible(stage: int, ident: int, main_pad: Dictionary) -> bool:
	return stage >= 0 and stage < 6 and ident >= START_ID \
		and (ident - START_ID) % PERIOD == 0 \
		and not bool(main_pad.get("fragile", false)) \
		and not bool(main_pad.get("moving", false)) \
		and not bool(main_pad.get("danger", false))

static func reachable(source: Dictionary, destination: Dictionary) -> bool:
	var gap: float = float(destination["m"]) - float(source["m"])
	if gap <= 3.0:
		return false
	var span: float = absf(float(destination["x"]) - float(source["x"]))
	if bool(source.get("moving", false)):
		span += absf(float(source.get("motion_amplitude", 0.0)))
	if bool(destination.get("moving", false)):
		span += absf(float(destination.get("motion_amplitude", 0.0)))
	return Vector2(span / 1.2, gap * 8.0 / 1.35).length() <= DRAG_LIMIT

static func build(ident: int, biome: int, previous: Dictionary, main_pad: Dictionary) -> Dictionary:
	if not eligible(biome, ident, main_pad):
		return {}
	var primary_x: float = float(main_pad["x"])
	var previous_x: float = float(previous["x"])
	var toward_previous := -1.0 if previous_x < primary_x else 1.0
	# Try the easier entrance first. The following mandatory pad will later
	# decide whether the branch can remain without creating a dead end.
	for direction in [toward_previous, -toward_previous]:
		var x: float = clampf(primary_x + direction * SIDE_OFFSET, 94.0, 446.0)
		if absf(x - primary_x) < 84.0:
			continue
		var fork: Dictionary = {
			"id": FORK_ID_OFFSET + ident,
			"x": x, "m": float(main_pad["m"]),
			"r": [43.0, 38.0, 40.0, 41.0, 35.0, 39.0][biome],
			"kind": (biome + 1) % 4,
			"coin": false, "pet": false, "boost": false,
			"guardian": false, "harmony": false, "trial": false,
			"danger": false, "fragile": biome == 2,
			"moving": biome == 5 or (biome == 3 and ident >= 9),
			"motion_speed": 2.85 if biome == 5 else 1.55,
			"motion_amplitude": 14.0 if biome == 5 else 10.0,
			"biome_fork": true, "fork_biome": biome
		}
		if reachable(previous, fork):
			return fork
	return {}

static func claim(pad: Dictionary) -> Dictionary:
	if not bool(pad.get("biome_fork", false)):
		return {}
	var biome: int = int(pad.get("fork_biome", -1))
	if biome < 0 or biome >= LABELS.size():
		return {}
	pad["biome_fork"] = false
	return {
		"label": LABELS[biome],
		"score": SCORES[biome],
		"wave_relief": RELIEF[biome],
		"flow_seconds": FLOW[biome],
		"guardian": biome == 3
	}
