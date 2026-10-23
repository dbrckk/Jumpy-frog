extends RefCounted
## Optional, zero-currency perfect-landing objectives shared by all six biomes.
## No RNG, no geometry changes and no new colliders; old campaign seeds remain valid.
## One opportunity per six main pads, never on existing hazard/special pads.
const FIRST_ID := 4
const PERIOD := 6
const NAMES := ["SUN PULSE", "BLOOM RUSH", "REED BREATH", "MOON GUARD", "CRYSTAL FOCUS", "STORM SURGE"]
const SCORES := [70, 60, 65, 55, 160, 80]
const WAVE_RELIEF := [3.0, 0.0, 6.0, 0.0, 0.0, 7.0]
const FLOW_SECONDS := [0.0, 3.0, 0.0, 0.0, 0.0, 2.0]

static func eligible(ident: int, festival_step: int, dangerous: bool,
	moving: bool, harmony: bool, fragile: bool, guardian: bool) -> bool:
	return ident >= FIRST_ID and (ident - FIRST_ID) % PERIOD == 0 \
		and festival_step < 0 and not dangerous and not moving \
		and not harmony and not fragile and not guardian

static func reward(biome: int) -> Dictionary:
	if biome < 0 or biome >= NAMES.size():
		return {}
	return {
		"name": NAMES[biome],
		"score": SCORES[biome],
		"wave_relief": WAVE_RELIEF[biome],
		"flow_seconds": FLOW_SECONDS[biome],
		"guardian": biome == 3
	}
