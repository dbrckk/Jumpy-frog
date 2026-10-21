extends RefCounted
## Deterministic, visually telegraphed hazard occupying occasional lilies.
## Landing is resolved once at launch using the same future-time rule as aim.
const CYCLE_SECONDS := 4.8
const ACTIVE_SECONDS := 1.55

static func is_active(pad: Dictionary, future_time: float) -> bool:
	if not bool(pad.get("danger", false)):
		return false
	var phase: float = float(pad.get("danger_phase", 0.0))
	return fposmod(future_time + phase, CYCLE_SECONDS) < ACTIVE_SECONDS

static func seconds_until_safe(pad: Dictionary, time: float) -> float:
	if not is_active(pad, time):
		return 0.0
	return ACTIVE_SECONDS - fposmod(time + float(pad.get("danger_phase", 0.0)), CYCLE_SECONDS)
