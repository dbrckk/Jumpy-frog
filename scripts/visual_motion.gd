extends RefCounted
## Pure visual state; never touches gameplay, collisions or run economy.
const LOOK_LIMIT_X := 2.8
const LOOK_LIMIT_Y := 1.9

static func gaze(mode: int, player_at: Vector2, aim_at: Vector2, body_tilt: float) -> Vector2:
	if mode == 2: # AIM
		return Vector2(
			clampf((aim_at.x - player_at.x) * 0.025, -LOOK_LIMIT_X, LOOK_LIMIT_X),
			clampf((aim_at.y - player_at.y) * 0.012, -LOOK_LIMIT_Y, LOOK_LIMIT_Y))
	if mode == 3: # FLY
		return Vector2(clampf(body_tilt * 8.0, -LOOK_LIMIT_X, LOOK_LIMIT_X), -1.5)
	return Vector2.ZERO

static func mood(mode: int, aim_valid: bool, aim_perfect: bool, dangerous: bool) -> int:
	# 0 = idle, 1 = focused, 2 = delighted, -1 = worried.
	if mode != 2:
		return 0
	if dangerous:
		return -1
	if aim_perfect and aim_valid:
		return 2
	return 1

static func bank_prop_count(quality: int) -> int:
	# Total across both banks. Still some foreground silhouette at tier zero.
	return 10 if quality >= 2 else (6 if quality == 1 else 2)

static func environmental_drift(time: float, index: int, biome: int) -> float:
	return sin(time * (0.7 if biome != 5 else 1.6) + float(index) * 1.78) * (2.8 if biome != 5 else 5.3)
