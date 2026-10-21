extends SceneTree
## Deterministic QA for bounded frame metrics and the pause-only diagnostics UI.
const MONITOR = preload("res://scripts/device_diagnostics.gd")
var problems := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var monitor := MONITOR.new()
	_check(monitor.snapshot()["frames"] == 0, "empty monitor reports no invented FPS")
	for i in range(120):
		monitor.record(1.0 / 60.0)
	var stats := monitor.snapshot()
	_check(int(stats["frames"]) == 120, "60 FPS samples are recorded")
	_check(absf(float(stats["fps"]) - 60.0) < 0.2, "mean FPS is numerically accurate")
	_check(absf(float(stats["p95_ms"]) - 16.67) < 0.3, "correct p95 under uniform frame time")
	_check(float(stats["slow_pct"]) == 0.0, "fast frames are never slow")
	monitor.record(0.3)
	_check(monitor.snapshot()["background_ignored"] == 1, "resume stall is not a GPU jank")
	monitor.record(0.05)
	stats = monitor.snapshot()
	_check(int(stats["slow_frames"]) == 1, "genuine 50 ms stall counted")
	_check(float(stats["slow_pct"]) > 0.0, "slow percentage exposed")
	for i in range(400):
		monitor.record(0.02)
	stats = monitor.snapshot()
	_check(int(stats["frames"]) == MONITOR.MAX_SAMPLES, "sample array capped to 240")
	_check(absf(float(stats["fps"]) - 50.0) < 0.1, "window statistics reflect recent frame timings")
	_check(int(stats["background_ignored"]) == 1, "background stall counter persists")
	monitor.reset()
	_check(monitor.snapshot()["frames"] == 0, "statistics can be reset")

	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._reset_game()
	game.mode = game.MODE_PLAY
	for i in range(90):
		game._process(1.0 / 60.0)
	_check(game.performance_sampler.snapshot()["frames"] >= 80, "normal game captures actual frame timing")
	game._pause_game()
	var game_clock: float = game.clock
	var wave_before: float = game.wave_m
	var observed: int = int(game.performance_sampler.snapshot()["frames"])
	game._down(Vector2(265, 403))
	_check(game.mode == game.MODE_DIAGNOSTICS, "pause button opens diagnostics")
	for i in range(20):
		game._process(0.02)
	_check(game.mode == game.MODE_DIAGNOSTICS, "diagnostics remains open")
	_check(game.clock == game_clock and game.wave_m == wave_before, "diagnostics freezes game simulation")
	_check(int(game.performance_sampler.snapshot()["frames"]) == observed, "diagnostics frames excluded from real game FPS")
	game._down(Vector2(265, 749))
	_check(game.mode == game.MODE_PAUSED, "back returns to paused state")
	_check(game.sound.paused, "audio remains paused during diagnostics")
	game._resume_game()
	_check(game.mode == game.MODE_PLAY and not game.sound.paused, "game resumes safely")
	game._process(0.018)
	_check(int(game.performance_sampler.snapshot()["frames"]) == observed + 1, "sample collection resumes")
	game._pause_game()
	game._down(Vector2(260, 400))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	_check(game.mode == game.MODE_PAUSED, "Android back/escape exits diagnostics")
	game.queue_free()
	await process_frame
	if problems == 0:
		print("PASS: bounded frame timing, background exclusion, readable pause diagnostics and lifecycle")
	else:
		printerr("FAIL: %d device diagnostics regressions" % problems)
	quit(0 if problems == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		problems += 1
		push_error("FAIL: " + message)
