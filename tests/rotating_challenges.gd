extends SceneTree
## Every rotation category is grounded in the actual successful-hop event.
const DIRECTOR = preload("res://scripts/precision_sprint.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var d := DIRECTOR.new()
	_check(DIRECTOR.LENGTH == 6, "all optional challenges keep the established six-hop time window")
	_check(DIRECTOR.TYPES == 4, "four replayable objectives")
	_check(DIRECTOR.FIRST_HOP == 18 and DIRECTOR.INTERVAL == 34, "same established challenge cadence")
	for hop in range(1, 18):
		_check(d.on_landing(hop, true, true, 25.0, true).is_empty(), "no early hidden reward")
	_check(d.on_landing(18, true).get("type", -1) == DIRECTOR.TYPE_PRECISION, "first objective is precision")
	_check(d.snapshot()["progress"] == 1 and d.snapshot()["target"] == 3, "first genuine perfect credited")
	_check(d.on_landing(18, true).is_empty(), "repeated landing event cannot count twice")
	_check(d.on_landing(19, false, true, 30, true).get("progress", -1) == 1, "other pickup types do not count as precision")
	_check(d.on_landing(20, true).get("progress", -1) == 2, "second actual perfect advances")
	var won: Dictionary = d.on_landing(21, true)
	_check(bool(won.get("won", false)) and int(won["leaves"]) == 2 and int(won["score"]) == 180, "precision reward once")
	_check(d.on_landing(21, true).is_empty() and d.completions == 1, "precision cannot be replayed")
	for hop in range(22, 52):
		_check(d.on_landing(hop, true, true, 23, true).is_empty(), "no challenges between scheduled windows")

	_check(d.on_landing(52, true, false, 30, true).get("type", -1) == DIRECTOR.TYPE_FORAGER, "second objective rotates to leaf collection")
	_check(d.snapshot()["progress"] == 0 and d.snapshot()["target"] == 2, "perfects, jumps, friends cannot fake leaf pickups")
	_check(d.on_landing(53, false, true, 0.0, false).get("progress", -1) == 1, "first real leaf credited")
	won = d.on_landing(54, false, true, 0.0, false)
	_check(bool(won.get("won", false)), "two collected leaves complete forager")
	_check(d.completed_by_type[DIRECTOR.TYPE_FORAGER] == 1, "forager tracks own completion")
	_check(d.on_landing(54, false, true).is_empty(), "picked-up leaf cannot be replayed")
	for hop in range(55, 86):
		d.on_landing(hop, true, true, 23, true)

	_check(d.on_landing(86, true, true, 16.99, true).get("type", -1) == DIRECTOR.TYPE_LONG_JUMP, "third objective rotates to real long jumps")
	_check(d.snapshot()["progress"] == 0, "just under distance threshold never counts")
	_check(d.on_landing(87, false, false, 17.0, false).get("progress", -1) == 1, "qualifying jump distance from game physics counts")
	won = d.on_landing(88, false, false, 18.7, false)
	_check(bool(won.get("won", false)) and d.completed_by_type[DIRECTOR.TYPE_LONG_JUMP] == 1, "two long jumps finish the third type")
	for hop in range(89, 120):
		d.on_landing(hop, true, false, 23, false)

	_check(d.on_landing(120, true, true, 23, false).get("type", -1) == DIRECTOR.TYPE_FRIENDS, "fourth objective is friend rescue")
	_check(d.snapshot()["progress"] == 0 and d.snapshot()["target"] == 1, "other events cannot create a phantom friend")
	won = d.on_landing(121, false, false, 0.0, true)
	_check(bool(won.get("won", false)) and d.completed_by_type[DIRECTOR.TYPE_FRIENDS] == 1, "rescue exactly one true friend")
	for hop in range(122, 154):
		d.on_landing(hop, false)
	_check(d.on_landing(154, false).get("type", -1) == DIRECTOR.TYPE_PRECISION, "cycle returns to precision after four distinct types")
	for hop in range(155, 160):
		var failed: Dictionary = d.on_landing(hop, false)
		if hop == 159:
			_check(failed.has("won") and not bool(failed["won"]) and not d.active, "failed precision ends without a reward")
	_check(d.completions == 4, "exactly four earned optional rewards across this simulation")
	_check(d.completed_by_type == [1, 1, 1, 1], "all four modes individually counted")
	d.reset()
	_check(not d.active and d.completions == 0 and d.completed_by_type == [0, 0, 0, 0], "restarts remove temporary progress")
	_check(d.on_landing(18, false).get("type", -1) == DIRECTOR.TYPE_PRECISION, "new runs restart the cycle predictably")

	# A real 140-hop run generates four complete opportunities from actual
	# landings/collectibles and never introduces a new obstruction.
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._reset_game()
	game.mode = game.MODE_PLAY
	game.daily.goals_claimed = 7
	game.daily.weekly_claimed = 7
	game.daily.milestones_claimed = (1 << game.daily.MILESTONES.size()) - 1
	game.wave_m = -85.0
	game.rng.seed = 50914
	var opportunities := {}
	for hop in range(140):
		_check(game.mode == game.MODE_PLAY, "normal Endless stays alive throughout challenge cycle")
		if game.mode != game.MODE_PLAY:
			break
		var next: Dictionary = {}
		for p in game.pads:
			if int(p["id"]) < 1000000 and float(p["m"]) > game.player_m + 3.0:
				next = p
				break
		_check(not next.is_empty(), "main reachable lily exists")
		if next.is_empty():
			break
		var wait := 0
		while game._landing_target(game._predicted_pad_x(next), float(next["m"])).is_empty() and wait < 140:
			game._process(0.02)
			wait += 1
		_check(game.mode == game.MODE_PLAY and wait < 140, "timed hazards still allow safe waiting")
		if game.mode != game.MODE_PLAY or wait >= 140:
			break
		game.aim_x = game._predicted_pad_x(next)
		game.aim_m = float(next["m"])
		game._start_jump()
		for frame in range(60):
			game._process(0.02)
			if game.mode != game.MODE_FLY:
				break
		_check(game.mode == game.MODE_PLAY, "real hop resolves")
		if game.mode != game.MODE_PLAY:
			break
		if game.precision_sprint.active:
			opportunities[int(game.precision_sprint.challenge_type)] = true
		_check(game.particles.size() <= 110 and game.float_texts.size() <= 8 and game.ripples.size() <= 12,
			"all challenges keep bounded VFX pools on long runs")
	_check(game.run_hops == 140, "all 140 authentic hop landings completed")
	_check(opportunities.size() >= 3, "real course cycles through several different optional activities")
	_check(game.precision_sprint.completions <= 4, "finite economy: at most four payouts in 140 hops")
	var saved_leaves: int = game.leaves
	game._save_progress()
	var config := ConfigFile.new()
	_check(config.load("user://jumpy_frog.cfg") == OK, "game uses atomic existing save")
	_check(int(config.get_value("progress", "leaves", -1)) == saved_leaves, "earned challenge currency persists")
	game._reset_game()
	_check(game.leaves == saved_leaves and game.precision_sprint.completions == 0,
		"new run preserves currency but clears short-lived challenges")
	game._start_daily_river()
	_check(game.precision_sprint.completions == 0 and not game.precision_sprint.active, "daily river remains isolated")
	for chapter in range(6):
		game._start_chapter(chapter)
		_check(game.precision_sprint.completions == 0 and not game.precision_sprint.active, "chapters remain isolated")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: four authentic rotating objectives, anti-replay payouts, 140 real hops, safe timing, retained saves and campaign/daily isolation")
	else:
		printerr("FAIL: %d challenge director regressions" % failures)
	quit(0 if failures == 0 else 1)

func _check(value: bool, reason: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + reason)
