extends SceneTree
## Professional fairness checks: forecast, hard-mode economy, festival pauses,
## idempotent callbacks and the nonintrusive full-length run.
const DIRECTOR = preload("res://scripts/precision_sprint.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_exercise")

func _exercise() -> void:
	var d := DIRECTOR.new()
	var preview := d.snapshot(16)
	_check(bool(preview.get("upcoming", false)) and int(preview["starts_in"]) == 2,
		"shows the first objective three actual jumps before it begins")
	_check(String(preview.get("next_title", "")) == "PRECISION SPRINT",
		"advance hint correctly names the next objective")
	_check(not bool(d.snapshot(15).get("upcoming", false)),
		"early gameplay does not clutter the HUD")
	_check(not d.active and d.attempts == 0 and d.completions == 0,
		"preview has zero game-state side effects")
	_check(not bool(d.snapshot(19).get("upcoming", false)),
		"no false preview after start threshold if no actual landings occurred")

	var paid := 0
	var successes := [0, 0, 0, 0]
	for seq in range(8):
		var start_hop: int = DIRECTOR.FIRST_HOP + seq * DIRECTOR.INTERVAL
		var next_hop: int = d.last_processed_hop + 1
		while next_hop < start_hop:
			var empty: Dictionary = d.on_landing(next_hop, true, true, 24.0, true)
			_check(empty.is_empty(), "no spontaneous challenge between 34-hop windows")
			next_hop += 1
		var expected_type: int = seq % 4
		var expected_level: int = 0 if seq < 4 else 1
		var expected_target: int = int(DIRECTOR.TARGETS[expected_type] if expected_level == 0 else DIRECTOR.ADVANCED_TARGETS[expected_type])
		var level_seen := false
		for hop in range(start_hop, start_hop + DIRECTOR.LENGTH):
			var challenge: Dictionary = d.on_landing(hop, true, true, 20.0, true)
			if hop == start_hop:
				level_seen = d.level == expected_level and d.challenge_type == expected_type
				_check(d.target() == expected_target, "each difficulty has correctly balanced target")
			if bool(challenge.get("won", false)):
				paid += 1
				successes[expected_type] += 1
				_check(int(challenge["level"]) == expected_level, "clear reward difficulty is accurate")
				var expected_bonus: int = 1 if paid % DIRECTOR.STREAK_REWARD_AT == 0 else 0
				_check(int(challenge["streak_bonus"]) == expected_bonus,
					"only every third consecutive win gives a streak bonus")
				_check(int(challenge["win_streak"]) == paid,
					"winning challenge increments real streak only once")
				_check(int(challenge["leaves"]) == (2 if expected_level == 0 else 3) + expected_bonus,
					"advanced base award plus a bounded streak bonus")
				_check(int(challenge["score"]) == (180 if expected_level == 0 else 260),
					"advanced award scales from 180 to 260 score")
				_check(int(challenge["target"]) == expected_target,
					"banner communicates exactly the goal achieved")
			else:
				_check(not challenge.has("won") or not bool(challenge.get("won", false)),
					"no duplicate payout while the event is closed")
		_check(level_seen, "sequential four-goal rotations remain predictable")
		_check(d.on_landing(start_hop + DIRECTOR.LENGTH - 1, true, true, 20, true).is_empty(),
			"replayed last landing cannot collect more leaves")
	_check(paid == 8 and successes == [2, 2, 2, 2] and d.completions == 8,
		"two complete cycles across all four gameplay categories")
	_check(d.win_streak == 8 and d.best_win_streak == 8,
		"consecutive wins track the correct personal best")

	# Higher difficulty is capped, not an unfair exponential grind.
	for hop in range(d.last_processed_hop + 1, 290):
		d.on_landing(hop, true, true, 22, true)
	_check(d.level <= DIRECTOR.MAX_LEVEL,
		"long runs never escalate the goals beyond the tested safe cap")

	# A complete three-step Firefly Festival is excluded from the challenge
	# attempt counter (the festival makes the collectibles unavailable).
	d.reset()
	for hop in range(1, 18):
		d.on_landing(hop, true)
	var rest: Dictionary = d.on_landing(18, false, false, 8.0, false, false)
	_check(d.active and d.attempts == 0 and d.rest_hops == 1 and bool(rest.get("started", false)),
		"festival first landing starts but does not consume an attempt")
	d.on_landing(19, false, false, 8.0, false, false)
	d.on_landing(20, false, false, 8.0, false, false)
	_check(d.attempts == 0 and d.rest_hops == 3 and d.snapshot()["remaining"] == 6,
		"all three festival pads grant a genuine rest")
	for hop in range(21, 27):
		var outcome: Dictionary = d.on_landing(hop, false)
		if hop == 26:
			_check(outcome.has("won") and not bool(outcome["won"]),
				"unsuccessful skill challenge finishes after six eligible hops")
	_check(d.completions == 0 and not d.active,
		"festival pause cannot mint unearned currency")
	_check(d.on_landing(26, true).is_empty(), "replaying a festival result is ineffective")
	d.reset()
	_check(d.last_processed_hop == 0 and d.rest_hops == 0 and d.level == 0,
		"new games clear all temporary challenge state")

	# Long real game simulation with actual procedurally generated lilies.
	# No artificial credits, obstacle changes or invocation of '_finish_jump'.
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._reset_game()
	game.mode = game.MODE_PLAY
	game.daily.goals_claimed = 7
	game.daily.weekly_claimed = 7
	game.daily.milestones_claimed = (1 << game.daily.MILESTONES.size()) - 1
	game.wave_m = -80.0
	game.rng.seed = 54821
	var windows := [false, false, false, false]
	for hop in range(285):
		if game.mode != game.MODE_PLAY:
			_check(false, "Endless game survives 285 natural physical hop landings")
			break
		var next: Dictionary = {}
		for pad in game.pads:
			if int(pad["id"]) < 1000000 and float(pad["m"]) > game.player_m + 3.0:
				next = pad
				break
		if next.is_empty():
			_check(false, "river never loses its primary route")
			break
		var wait := 0
		while game._landing_target(game._predicted_pad_x(next), float(next["m"])).is_empty() and wait < 145:
			game._process(0.02)
			wait += 1
		if game.mode != game.MODE_PLAY or wait >= 145:
			_check(false, "red hazards remain safely avoidable without artificial force")
			break
		game.aim_x = game._predicted_pad_x(next)
		game.aim_m = float(next["m"])
		game._start_jump()
		for frame in range(65):
			game._process(0.02)
			if game.mode != game.MODE_FLY:
				break
		if game.mode != game.MODE_PLAY:
			_check(false, "long-run honest landing completes")
			break
		if game.precision_sprint.active:
			windows[game.precision_sprint.challenge_type] = true
		_check(game.particles.size() <= 110 and game.ripples.size() <= 12 and game.float_texts.size() <= 8,
			"VFX stays bounded across advanced challenge cycles")
	_check(game.run_hops == 285, "285 real hops complete on one continuous river")
	_check(windows == [true, true, true, true], "all four modes actually occur on the generated river")
	_check(game.precision_sprint.level <= 1, "long-run game uses a bounded advanced tier")
	_check(game.precision_sprint.completions >= 5 and game.precision_sprint.completions <= 8,
		"strong play earns a useful but bounded number of skill rewards")
	var leaves_after: int = game.leaves
	game._save_progress()
	var save := ConfigFile.new()
	_check(save.load("user://jumpy_frog.cfg") == OK and int(save.get_value("progress", "leaves", -1)) == leaves_after,
		"real earned challenge leaves are persisted atomically")
	game._reset_game()
	_check(game.leaves == leaves_after and game.challenge_banner_seconds == 0.0,
		"restart keeps earned rewards but no transient celebration")
	game._start_daily_river()
	_check(not game.precision_sprint.active and game.challenge_banner_seconds == 0.0,
		"daily mode never inherits an active Endless objective")
	for chapter in range(6):
		game._start_chapter(chapter)
		_check(not game.precision_sprint.active, "campaign remains independent")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: 8 balanced challenge cycles, 3 festival rest hops, precise previews, antireplay, 285 real landings, safe economy and independent story/daily")
	else:
		printerr("FAIL: %d advanced balancing assertions" % failures)
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
