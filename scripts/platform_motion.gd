extends RefCounted
## Deterministic world-space drift for selected moving lilies.
## Physics, touch preview and drawing MUST use this same function.
const MOON_AMPLITUDE := 14.0
const CRYSTAL_AMPLITUDE := 11.0

static func x_at(pad: Dictionary, world_time: float) -> float:
	var base: float = float(pad["x"])
	if not bool(pad.get("moving", false)):
		return base
	var speed: float = float(pad.get("motion_speed", 1.7))
	var amplitude: float = float(pad.get("motion_amplitude", MOON_AMPLITUDE))
	var phase: float = float(pad["id"]) * 0.91
	return clampf(base + sin(world_time * speed + phase) * amplitude, 92.0, 448.0)

static func create_fields(biome: int, ident: int) -> Dictionary:
	# Never hide a motion hazard under a Guardian or timed fragile pad.
	var moves: bool = biome in [3, 4] and ident >= 5 and ident % 6 == 0 and ident % 13 != 0
	return {
		"moving": moves,
		"motion_speed": 1.65 if biome == 3 else 2.25,
		"motion_amplitude": MOON_AMPLITUDE if biome == 3 else CRYSTAL_AMPLITUDE
	}
