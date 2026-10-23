extends RefCounted
## Bounded frame timing sampler for on-device QA.
## No GPU readback, filesystem access, native calls, or per-frame sorting.
const MAX_SAMPLES := 240
const STALL_THRESHOLD_MS := 33.34
# A suspended Android app can resume without delivering a focus notification.
# Treat only an exceptionally large *single frame* as an interruption, not
# normal 30 FPS operation. Gameplay must pause before touching the simulation.
const INTERRUPTION_SECONDS := 0.55

static func is_interruption_frame(delta: float) -> bool:
	return delta >= INTERRUPTION_SECONDS
var samples: PackedFloat32Array = PackedFloat32Array()
var next_index := 0
var observed_frames := 0
var stalls := 0
var excluded_background_frames := 0
var max_ms := 0.0

func record(delta: float, playing: bool = true) -> void:
	if not playing or delta <= 0.0:
		return
	# Background suspension and process resume can deliver very large delta.
	# They must not be mistaken for device-rendering stutters.
	if delta > 0.15:
		excluded_background_frames += 1
		return
	var ms := delta * 1000.0
	if samples.size() < MAX_SAMPLES:
		samples.append(ms)
	else:
		samples[next_index] = ms
	next_index = (next_index + 1) % MAX_SAMPLES
	observed_frames += 1
	if ms >= STALL_THRESHOLD_MS:
		stalls += 1
	max_ms = maxf(max_ms, ms)

func snapshot() -> Dictionary:
	if samples.is_empty():
		return {
			"frames": 0, "fps": 0.0, "p95_ms": 0.0,
			"slow_frames": 0, "slow_pct": 0.0,
			"max_ms": 0.0, "background_ignored": excluded_background_frames
		}
	var sorted := Array(samples)
	sorted.sort()
	var sum_ms := 0.0
	var slow := 0
	for value in samples:
		sum_ms += value
		if value >= STALL_THRESHOLD_MS:
			slow += 1
	var n := samples.size()
	var p95_index := clampi(int(ceil(float(n) * 0.95)) - 1, 0, n - 1)
	return {
		"frames": n,
		"fps": 1000.0 * float(n) / maxf(sum_ms, 0.001),
		"p95_ms": float(sorted[p95_index]),
		"slow_frames": slow,
		"slow_pct": 100.0 * float(slow) / float(n),
		"max_ms": max_ms,
		"background_ignored": excluded_background_frames
	}

func reset() -> void:
	samples.clear()
	next_index = 0
	observed_frames = 0
	stalls = 0
	excluded_background_frames = 0
	max_ms = 0.0
