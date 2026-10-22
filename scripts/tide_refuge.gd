extends RefCounted
## Optional tranquil detour in Endless: an actual strategic choice between
## taking the ordinary safe lily or reclaiming water-wave breathing room.
## This system never changes the main route, collisions, payments or RNG.
const FIRST_ID := 17
const PERIOD := 24
const WAVE_RELIEF_METERS := 9.0
const SCORE_BONUS := 140
const MIN_BRANCH_SEPARATION_PX := 82.0
const ROUTE_RADIUS := 40.0

static func eligible(ident: int, endless: bool, festival_step: int, dangerous: bool, moving: bool, harmony: bool, fragile: bool, guardian: bool) -> bool:
	return endless and ident >= FIRST_ID and ident % PERIOD == FIRST_ID 		and festival_step < 0 and not dangerous and not moving 		and not harmony and not fragile and not guardian

static func branch_x(primary_x: float, rng: RandomNumberGenerator) -> float:
	# Take the side with the most open river. The primary route stays intact.
	var direction := -1.0 if primary_x > 270.0 else 1.0
	return clampf(primary_x + direction * rng.randf_range(91.0, 103.0), 95.0, 445.0)

static func is_clear_fork(primary_x: float, optional_x: float) -> bool:
	return absf(primary_x - optional_x) >= MIN_BRANCH_SEPARATION_PX

static func claim(pad: Dictionary) -> bool:
	if not bool(pad.get("tide_refuge", false)):
		return false
	# Mutate exactly the pad held in the Game.pads dictionary array.
	# A second landing on the same pad cannot mint more score/wave relief.
	pad["tide_refuge"] = false
	return true
