extends RefCounted
## Rare mutually exclusive tactical choice in Endless; deterministic and fair.
## Original main-route geometry, seeds, collisions and permanent currency unchanged.
const FIRST_ID := 31
const PERIOD := 36
const SIDE_ID_BASE := 3000000
const DRAG_BUDGET := 201.0
const SIDE_DISTANCE := 92.0
const SAFE_LABELS := [
	"SUN SHELTER", "GARDEN REST", "REED HAVEN",
	"MOON SHELTER", "CRYSTAL CALM", "STORM EYE"
]
const SURGE_LABELS := [
	"SUN DASH", "BLOOM SURGE", "REED DASH",
	"MOON FLIGHT", "PRISM DASH", "STORM CHARGE"
]
const SAFE_METERS := [9.0, 8.0, 10.0, 9.0, 8.0, 12.0]
const SURGE_POINTS := [165, 175, 180, 185, 200, 220]
const SURGE_FLOW := [3.0, 3.5, 3.0, 4.0, 4.5, 5.0]

static func eligible(stage: int, ident: int, pad: Dictionary) -> bool:
	return stage == -1 and ident >= FIRST_ID and (ident - FIRST_ID) % PERIOD == 0 \
		and int(pad.get("festival_step", -1)) < 0 \
		and not bool(pad.get("danger", false)) \
		and not bool(pad.get("moving", false)) \
		and not bool(pad.get("fragile", false)) \
		and not bool(pad.get("guardian", false)) \
		and not bool(pad.get("harmony", false)) \
		and not bool(pad.get("trial", false)) \
		and not bool(pad.get("boost", false))

static func reachable(from_pad: Dictionary, to_pad: Dictionary) -> bool:
	var rise: float = float(to_pad["m"]) - float(from_pad["m"])
	if rise <= 3.0:
		return false
	var sideways: float = absf(float(to_pad["x"]) - float(from_pad["x"]))
	if bool(from_pad.get("moving", false)):
		sideways += absf(float(from_pad.get("motion_amplitude", 0.0)))
	if bool(to_pad.get("moving", false)):
		sideways += absf(float(to_pad.get("motion_amplitude", 0.0)))
	return Vector2(sideways / 1.2, rise * 8.0 / 1.35).length() <= DRAG_BUDGET

static func create_side(ident: int, biome: int, previous: Dictionary, primary: Dictionary) -> Dictionary:
	if not eligible(-1, ident, primary) or biome < 0 or biome >= 6:
		return {}
	var x: float = float(primary["x"])
	var previous_x: float = float(previous["x"])
	var easiest: float = -1.0 if previous_x < x else 1.0
	for direction in [easiest, -easiest]:
		var chosen: float = clampf(x + direction * SIDE_DISTANCE, 94.0, 446.0)
		if absf(chosen - x) < 84.0:
			continue
		var side: Dictionary = {
			"id": SIDE_ID_BASE + ident,
			"x": chosen,
			"m": float(primary["m"]),
			"r": 39.0 if biome in [0, 1, 3] else 37.0,
			"kind": (biome + 1) % 4,
			"coin": false, "pet": false, "boost": false,
			"guardian": false, "harmony": false, "trial": false,
			"danger": false, "fragile": false, "moving": false,
			"crossroad_id": ident, "crossroad_choice": 2,
			"crossroad_biome": biome
		}
		if reachable(previous, side):
			return side
	return {}

static func cancel_pair(pads: Array, ident: int) -> void:
	# Called only when the upcoming normal pad makes the detour impossible.
	for pad in pads:
		if int(pad.get("crossroad_id", -1)) == ident:
			pad.erase("crossroad_id")
			pad.erase("crossroad_choice")
			pad.erase("crossroad_biome")

static func claim(landed: Dictionary, pads: Array) -> Dictionary:
	var choice: int = int(landed.get("crossroad_choice", 0))
	if choice not in [1, 2]:
		return {}
	var ident: int = int(landed.get("crossroad_id", -1))
	var biome: int = int(landed.get("crossroad_biome", -1))
	if ident < FIRST_ID or biome < 0 or biome >= SAFE_LABELS.size():
		return {}
	# One landing consumes both alternatives. Revisit never duplicates rewards.
	for pad in pads:
		if int(pad.get("crossroad_id", -1)) == ident:
			pad["crossroad_choice"] = 0
	return {
		"label": SAFE_LABELS[biome] if choice == 1 else SURGE_LABELS[biome],
		"score": 0 if choice == 1 else SURGE_POINTS[biome],
		"wave_relief": SAFE_METERS[biome] if choice == 1 else 0.0,
		"flow_seconds": 0.0 if choice == 1 else SURGE_FLOW[biome],
		"choice": choice
	}
