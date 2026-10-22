extends SceneTree
## Real 3km procedural-course audit and exactly-once Tide Refuge landing.
## No synthetic reward events: every economy assertion follows _start_jump.
const TIDE = preload("res://scripts/tide_refuge.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_exercise")

func _exercise() -> void:
	_check(not TIDE.eligible(17, false, -1, false, false, false, false, false),
		"no story/daily refuge")
	_check(not TIDE.eligible(17, true, 0, false, false, false, false, false),
		"festival hops never fork into refuge")
	_check(not TIDE.eligible(17, true, -1, true, false, false, false, false),
		"dangerous primary never becomes a refuge fork")
	_check(not TIDE.eligible(17, true, -1, false, true, false, false, false),
		"moving primary cannot hide an optional route")
	_check(not TIDE.eligible(17, true, -1, false, false, false, true, false),
		"fragile primary cannot host refuge")
	_check(TIDE.eligible(41, true, -1, false, false, false, false, false),
		"sparse refuge cycle remains deterministic")
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var total_refuges := 0
	var total_golden := 0
	for seed in [74, 982, 1165, 3024, 9876, 12059]:
		game._reset_game()
		game.mode = game.MODE_PLAY
		game.rng.seed = seed
		game.pads.resize(1)
		game.last_generated_m = 0.0
		game.last_pad_x = 270.0
		game.next_pad_id = 1
		game.last_danger_id = -99
		game.festival.reset()
		game.route_director.reset()
		game.player_m = 3250.0
		game._generate_pads()
		var local_refuges := 0
		for pad in game.pads:
			if bool(pad.get("branch_bonus", false)):
				total_golden += 1
			if not bool(pad.get("tide_refuge", false)):
				continue
			# Streaming only guarantees the following primary for encounters
			# behind the frontier. The final optional lily is generated ahead
			# of the next section on purpose; do not mislabel that as a dead end.
			if float(pad["m"]) >= game.last_generated_m - 30.0:
				continue
			local_refuges += 1
			total_refuges += 1
			var ident: int = int(pad["id"]) - 1000000
			_check(ident >= TIDE.FIRST_ID and ident % TIDE.PERIOD == TIDE.FIRST_ID,
				"tide fork appears only at a sparse scheduled primary id")
			_check(not bool(pad.get("danger", false)) and not bool(pad.get("fragile", false))
				and not bool(pad.get("moving", false)) and not bool(pad.get("branch_bonus", false)),
				"no trap, double bonus or moving refuge")
			var primary: Dictionary = {}
			var previous: Dictionary = {}
			var following: Dictionary = {}
			for other in game.pads:
				var id: int = int(other["id"])
				if id == ident:
					primary = other
				elif id == ident - 1:
					previous = other
				elif id == ident + 1:
					following = other
			_check(not primary.is_empty() and not previous.is_empty() and not following.is_empty(),
				"every choice retains surrounding normal route pads")
			if primary.is_empty() or previous.is_empty() or following.is_empty():
				continue
			_check(TIDE.is_clear_fork(float(primary["x"]), float(pad["x"])),
				"turquoise branch physically separated from regular route")
			_check(is_equal_approx(float(primary["m"]), float(pad["m"])),
				"main and optional pads are equally forward along the river")
			_check(not bool(primary["danger"]) and not bool(primary["moving"])
				and not bool(primary["fragile"]) and not bool(primary["harmony"]),
				"normal lily at fork always remains easy and hazard-free")
			var start_gesture := Vector2((float(pad["x"]) - float(previous["x"])) / 1.2,
				(float(pad["m"]) - float(previous["m"])) * 8.0 / 1.35).length()
			var reconnect_gesture := Vector2((float(following["x"]) - float(pad["x"])) / 1.2,
				(float(following["m"]) - float(pad["m"])) * 8.0 / 1.35).length()
			_check(start_gesture < 215.0, "tide detour reachable from previous primary touch")
			_check(reconnect_gesture < 215.0, "tide detour reconnects safely to next primary")
			_check(float(pad["r"]) >= 40.0, "rest path is not smaller than advertised")
		_check(local_refuges >= 2, "each 3km procedural river contains multiple real tide decisions")
		_check(game.pads.size() < 270, "rare choice pads do not grow streaming memory unboundedly")
	_check(total_refuges >= 18 and total_golden >= 12,
		"gold and tide choices both occur regularly across sampled long runs")
	
	# Real landing of a turquoise lily. Collects no leaves, but produces
	# score and true wave relief. Confirm the same landing cannot re-pay.
	game._reset_game()
	game.mode = game.MODE_PLAY
	game.wave_m = -75.0
	game.daily.goals_claimed = 7
	game.daily.weekly_claimed = 7
	game.daily.milestones_claimed = (1 << game.daily.MILESTONES.size()) - 1
	var first: Dictionary = game.pads[1]
	var refuge := first.duplicate(true)
	refuge["id"] = 1000000 + int(first["id"])
	refuge["x"] = clampf(float(first["x"]) + 95.0, 95.0, 445.0)
	refuge["r"] = TIDE.ROUTE_RADIUS
	refuge["coin"] = false
	refuge["pet"] = false
	refuge["boost"] = false
	refuge["guardian"] = false
	refuge["moving"] = false
	refuge["harmony"] = false
	refuge["fragile"] = false
	refuge["danger"] = false
	refuge["branch_bonus"] = false
	refuge["tide_refuge"] = true
	game.pads.insert(2, refuge)
	var old_leaves: int = game.leaves
	var old_wave: float = game.wave_m
	game.aim_x = float(refuge["x"])
	game.aim_m = float(refuge["m"])
	_check(int(game._landing_target(game.aim_x, game.aim_m).get("id", -1)) == int(refuge["id"]),
		"aim guide targets real tide alternate")
	game._start_jump()
	for frame in range(60):
		game._process(0.02)
		if game.mode != game.MODE_FLY:
			break
	_check(game.mode == game.MODE_PLAY and game.standing_pad_id == int(refuge["id"]),
		"legitimate tide landing succeeds")
	_check(game.wave_m <= old_wave - 7.0, "tide reward truly pushes wave back about nine meters")
	_check(game.score >= TIDE.SCORE_BONUS, "score payout added to normal landing")
	_check(game.leaves == old_leaves and game.run_leaves == 0,
		"safe strategic choice does not mint premium currency")
	_check(not bool(refuge.get("tide_refuge", true)) and not TIDE.claim(refuge),
		"tide reward consumed exactly once")
	game._save_progress()
	var save := ConfigFile.new()
	_check(save.load("user://jumpy_frog.cfg") == OK, "tide score saved safely")

	for chapter in range(6):
		game._start_chapter(chapter)
		for pad in game.pads:
			_check(not bool(pad.get("tide_refuge", false)), "all six narrative chapters are unchanged")
	game._start_daily_river()
	for pad in game.pads:
		_check(not bool(pad.get("tide_refuge", false)), "daily challenge route remains unchanged")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: 6x3km course forks, 2 safe route options, replay-safe tide relief, golden paths, and independent chapter/daily")
	else:
		printerr("FAIL: %d optional tide route assertions" % failures)
	quit(0 if failures == 0 else 1)

func _check(valid: bool, message: String) -> void:
	if not valid:
		failures += 1
		push_error("FAIL: " + message)
