extends SceneTree
## Endless optional gold lanes, verified reachability, payouts and timed warning.
const DANGER = preload("res://scripts/pad_danger.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	# Cover distinct biomes and a 2km+ generated course, with a strictly
	# bounded number of extra pads and no changed campaign layouts.
	game._reset_game()
	game.mode = game.MODE_PLAY
	game.rng.seed = 5128
	game.player_m = 2300.0
	game._generate_pads()
	var golden := 0
	for pad in game.pads:
		if not bool(pad.get("branch_bonus", false)):
			continue
		golden += 1
		var ident: int = int(pad["id"]) - 1000000
		_check(ident >= 9 and ident % 12 == 9, "gold lane only on sparse skill intervals")
		var primary: Dictionary = {}
		for p in game.pads:
			if int(p["id"]) == ident:
				primary = p
				break
		_check(not primary.is_empty(), "each bonus always has a safe regular alternative")
		if primary.is_empty():
			continue
		_check(absf(float(pad["x"]) - float(primary["x"])) >= 82.0, "bonus route visibly separates")
		_check(is_equal_approx(float(pad["m"]), float(primary["m"])), "two genuine routes at same river height")
		_check(float(pad["r"]) < float(primary["r"]), "gold route rewards accuracy with a smaller platform")
		_check(not bool(pad.get("danger", false)) and not bool(pad.get("fragile", false)),
			"gold platform has no invisible hazard")
		_check(not bool(primary.get("danger", false)) and not bool(primary.get("moving", false)),
			"primary always safe at a fork")
		var next_normal: Dictionary = {}
		for p in game.pads:
			if int(p["id"]) == ident + 1:
				next_normal = p
				break
		if not next_normal.is_empty():
			var dx := (float(next_normal["x"]) - float(pad["x"])) / 1.2
			var dy := (float(next_normal["m"]) - float(pad["m"])) * 8.0 / 1.35
			_check(Vector2(dx, dy).length() < 215.0, "gold branch reconnects to main lane by a fair touch drag")
	_check(golden >= 1, "endless biome has at least one meaningful fork")

	for biome in range(6):
		game._start_chapter(biome)
		for pad in game.pads:
			_check(not bool(pad.get("branch_bonus", false)), "chapter layouts do not change")
	game._start_daily_river()
	for pad in game.pads:
		_check(not bool(pad.get("branch_bonus", false)), "daily course remains stable")
	
	# Test actual optional gold landing and exactly-once leaf economy.
	game._reset_game()
	game.mode = game.MODE_PLAY
	game.daily.goals_claimed = 7
	game.daily.weekly_claimed = 7
	game.daily.milestones_claimed = (1 << game.daily.MILESTONES.size()) - 1
	var primary: Dictionary = game.pads[1]
	var alternate := primary.duplicate(true)
	alternate["id"] = 1000000 + int(primary["id"])
	alternate["x"] = float(primary["x"]) + 94.0
	alternate["r"] = 37.0
	alternate["branch_bonus"] = true
	alternate["coin"] = false
	alternate["pet"] = false
	alternate["boost"] = false
	alternate["guardian"] = false
	alternate["fragile"] = false
	alternate["moving"] = false
	alternate["harmony"] = false
	alternate["danger"] = false
	game.pads.insert(2, alternate)
	var leaves_before: int = game.leaves
	var distance_m: float = float(alternate["m"])
	var base_points: int = maxi(12, int(distance_m * 13.0))
	game.aim_x = float(alternate["x"])
	game.aim_m = distance_m
	_check(game._landing_target(game.aim_x, game.aim_m)["id"] == alternate["id"], "gold lane recognized by shared collision")
	game._start_jump()
	for i in range(60):
		game._process(0.02)
		if game.mode != game.MODE_FLY:
			break
	_check(game.mode == game.MODE_PLAY and game.standing_pad_id == int(alternate["id"]),
		"optional landing succeeds without dead-end")
	_check(game.leaves == leaves_before + 2 and game.run_leaves == 2, "exactly two premium-route leaves granted")
	_check(game.score >= base_points + 225, "gold route score bonus applied")
	_check(not bool(alternate["branch_bonus"]), "bonus consumed and cannot be farmed")
	game._save_progress()
	var saved := ConfigFile.new()
	_check(saved.load("user://jumpy_frog.cfg") == OK, "bonus reward persisted")
	_check(int(saved.get_value("progress", "leaves", -1)) == game.leaves, "gold leaves saved immediately")

	# The crab label predicts the arrival state, not just its current ring.
	game._reset_game()
	game.mode = game.MODE_PLAY
	var crab: Dictionary = game.pads[1]
	crab["danger"] = true
	var duration: float = game._duration_to(float(crab["m"]))
	crab["danger_phase"] = fposmod(0.65 - game.clock - duration, DANGER.CYCLE_SECONDS)
	var warning: Dictionary = game._danger_aim_warning(float(crab["x"]), float(crab["m"]))
	_check(not warning.is_empty(), "danger predicted for the exact target hitbox")
	_check(float(warning.get("wait", 0.0)) > 0.0, "crab hint includes time before safe window")
	_check(game._landing_target(float(crab["x"]), float(crab["m"])).is_empty(), "red warning equals forbidden collision")
	crab["danger_phase"] = fposmod(DANGER.ACTIVE_SECONDS + 0.5 - game.clock - duration, DANGER.CYCLE_SECONDS)
	_check(game._danger_aim_warning(float(crab["x"]), float(crab["m"])).is_empty(),
		"safe landing removes stale crab danger text")
	_check(not game._landing_target(float(crab["x"]), float(crab["m"])).is_empty(),
		"normal green aim cue returns when the danger clears")

	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: golden optional routes, fair reconnection, once-only rewards, and predictive crab warnings")
	else:
		printerr("FAIL: %d route regressions" % failures)
	quit(0 if failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
