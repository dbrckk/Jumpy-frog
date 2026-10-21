extends SceneTree
## Skill FLOW: consistent perfects, finite score multiplier, fair wave speed,
## pause-safe timer, no monetization and renderer-tier independent rules.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.flow_seconds == 0.0 and game.flow_triggers == 0, "new game has no skill bonus")
	game.mode = 1
	for hop in range(4):
		var target: Dictionary = _next_pad(game)
		_expect(not target.is_empty(), "fair forward target exists")
		if target.is_empty():
			break
		_hop(game, target)
		_expect(game.mode == 1, "perfect landing survives")
		_expect(game.perfect_streak == hop + 1, "perfect streak advances")
		if hop < 3:
			_expect(game.flow_seconds == 0.0, "fewer than four perfects never activate")
	_expect(game.flow_seconds > 6.0 and game.flow_triggers == 1, "four perfects activate seven-second FLOW")
	var old_timer: float = game.flow_seconds
	game._pause_game()
	for frame in range(12):
		game._process(0.05)
	_expect(is_equal_approx(game.flow_seconds, old_timer), "FLOW timer stops while paused")
	game._resume_game()
	var mod: Dictionary = game.chapters.chapter(game.chapters.biome_at(game.player_m, game.campaign_stage))
	var standard_pressure: float = 2.4 + minf(game.highest_m * 0.013, 4.5) + float(mod["wave"])
	var before_wave: float = game.wave_m
	game._process(0.05)
	_expect(game.wave_m > before_wave, "wave still advances during FLOW")
	_expect(game.wave_m - before_wave < standard_pressure * 0.05 * 0.75, "FLOW noticeably reduces wave pressure")
	var fifth: Dictionary = _next_pad(game)
	if not fifth.is_empty():
		# Isolate points from all existing pickups, without modifying the rules.
		fifth["coin"] = false
		fifth["pet"] = false
		fifth["boost"] = false
		fifth["guardian"] = false
		var distance: float = float(fifth["m"]) - game.highest_m
		var gain: int = maxi(12, int(distance * 13.0))
		gain += 35 + mini(game.perfect_streak + 1, 12) * 4
		var predicted_combo: int = game.combo + 1
		var standard_points: int = gain + maxi(predicted_combo - 2, 0) * 10
		var score_before: int = game.score
		_hop(game, fifth)
		_expect(game.score - score_before == roundi(float(standard_points) * game.FLOW_SCORE_MULTIPLIER),
			"score multiplier exactly matches earned 35% bonus")
	# Expiration does not alter game geometry or force a reset.
	game.flow_seconds = 0.08
	game._process(0.08)
	_expect(game.flow_seconds == 0.0 and game.mode == 1, "FLOW expires naturally without killing a run")
	game._reset_game()
	_expect(game.flow_seconds == 0.0 and game.flow_triggers == 0, "new run cannot reuse previous FLOW")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: skill FLOW, perfect milestone, score multiplier, slow wave, paused timer and reset")
	else:
		printerr("FAIL: FLOW checks: %d" % failures)
	quit(0 if failures == 0 else 1)

func _next_pad(game: Node2D) -> Dictionary:
	for pad in game.pads:
		if float(pad["m"]) > game.player_m + 3.0:
			return pad
	return {}

func _hop(game: Node2D, pad: Dictionary) -> void:
	game.aim_x = float(pad["x"])
	game.aim_m = float(pad["m"])
	game._start_jump()
	for frame in range(60):
		game._process(0.02)
		if game.mode != 3:
			break

func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
