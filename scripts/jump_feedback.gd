extends RefCounted
## Shared score-grade calculation between the live touch preview and launch.
## Visual spring compression is intentionally independent of simulation.
const PERFECT_RADIUS_RATIO := 0.28

static func is_perfect(pad: Dictionary, desired_x: float, desired_m: float, predicted_x: float, px_per_m: float) -> bool:
	if pad.is_empty():
		return false
	var radius: float = float(pad["r"]) * PERFECT_RADIUS_RATIO
	var delta := Vector2(predicted_x - desired_x, (float(pad["m"]) - desired_m) * px_per_m)
	return delta.length_squared() < radius * radius

static func windup(aimed_m: float, player_m: float) -> float:
	return clampf((aimed_m - player_m) / 23.0, 0.0, 1.0)

static func place_message(requested: Vector2, active: Array, max_items: int = 8) -> Vector2:
	# Existing rewards stay stable while a new caption gets an available lane.
	# This is a short, bounded search; avoid allocating fonts or UI nodes.
	var candidate := requested
	for attempt in range(max_items + 1):
		var overlaps := false
		for item in active:
			if float(item.get("life", 0.0)) < 0.16:
				continue
			var old: Vector2 = item["pos"]
			if absf(old.x - candidate.x) < 140.0 and absf(old.y - candidate.y) < 32.0:
				overlaps = true
				break
		if not overlaps:
			return candidate
		candidate.y -= 36.0
		if candidate.y < 175.0:
			candidate = Vector2(requested.x, clampf(requested.y + 38.0 * (attempt + 1), 180.0, 850.0))
	return candidate
