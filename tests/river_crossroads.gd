extends SceneTree
## Rare exclusive choices must preserve ordinary Endless geometry and rewards.
const CROSSROADS = preload("res://scripts/river_crossroads.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + why)

func _hop(game: Node2D, target: Dictionary) -> void:
	game.aim_x = game._predicted_pad_x(target)
	game.aim_m = float(target["m"])
	game._start_jump()
	_check(game.jump_pad_id == int(target["id"]), "launch predicts exact REST or SURGE lily")
	for tick in range(70):
		game._process(0.02)
		if game.mode != game.MODE_FLY:
			break
	_check(game.mode == game.MODE_PLAY, "real choice hop lands safely")

func _run() -> void:
	_check(CROSSROADS.eligible(-1, 31, {}), "rare first crossing is scheduled")
	_check(CROSSROADS.eligible(-1, 67, {}), "rare opportunities recur during long runs")
	_check(not CROSSROADS.eligible(0, 31, {}), "campaign does not receive unplanned shortcuts")
	_check(not CROSSROADS.eligible(-2, 31, {}), "daily challenge seed remains untouched")
	_check(not CROSSROADS.eligible(-1, 32, {}), "crossings stay exceptional")
	for flag in ["danger", "moving", "fragile", "guardian", "harmony", "trial", "boost"]:
		var flagged: Dictionary = {}
		flagged[flag] = true
		_check(not CROSSROADS.eligible(-1, 31, flagged),
			"no special hazard or existing reward overlaps: " + flag)
	_check(not CROSSROADS.eligible(-1, 31, {"festival_step": 1}),
		"crossroads never overlap the three-hop festival")
	var previous := {"x": 270.0, "m": 0.0}
	var primary := {"id": 31, "x": 300.0, "m": 17.0}
	var branch: Dictionary = CROSSROADS.create_side(31, 1, previous, primary)
	_check(not branch.is_empty() and CROSSROADS.reachable(previous, branch),
		"side choice has a safe entrance")
	_check(absf(float(branch.get("x", 300.0)) - 300.0) >= 84.0, "choices are visibly separate")
	_check(not CROSSROADS.reachable(branch, {"x": 500.0, "m": 50.0}),
		"uncertain return path fails the strict touch-gesture budget")
	var pair := [primary, branch]
	primary["crossroad_id"] = 31
	primary["crossroad_choice"] = 1
	primary["crossroad_biome"] = 1
	var safe: Dictionary = CROSSROADS.claim(primary, pair)
	_check(float(safe.get("wave_relief", 0.0)) > 0.0 and int(safe.get("score", -1)) == 0,
		"REST genuinely buys breathing room instead of free score")
	_check(CROSSROADS.claim(branch, pair).is_empty(),
		"revisiting SURGE after REST cannot claim a second prize")
	_check(not safe.has("leaves"), "event adds no persistent currency")
	# A branch that fails a future reconnection is discarded along with both
	# flags; no dangling safe/reward marker can remain on its primary.
	primary["crossroad_choice"] = 1
	branch["crossroad_choice"] = 2
	CROSSROADS.cancel_pair(pair, 31)
	_check(not primary.has("crossroad_choice") and not branch.has("crossroad_choice"),
		"discarding unsafe side path clears both signs")
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# Full long-generation sweeps across fixed random streams: verify all
	# visible choice pairs and ordinary geometry remain reachable.
	var total_pairs := 0
	for seed in [11, 57, 812, 4141]:
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
		game.player_m = 3500.0
		game._generate_pads()
		var groups: Dictionary = {}
		for lily in game.pads:
			var choice: int = int(lily.get("crossroad_choice", 0))
			if choice == 0:
				continue
			var ident: int = int(lily["crossroad_id"])
			if not groups.has(ident):
				groups[ident] = []
			groups[ident].append(choice)
			_check(ident >= 31 and (ident - 31) % 36 == 0,
				"rare scheduled event never spawns between checkpoints")
			_check(not bool(lily.get("danger", false)) and not bool(lily.get("fragile", false)),
				"both choices remain free of unadvertised hazards")
			if choice == 2:
				var before: Dictionary = {}
				var next: Dictionary = {}
				var main: Dictionary = {}
				for candidate in game.pads:
					if int(candidate["id"]) == ident - 1:
						before = candidate
					elif int(candidate["id"]) == ident:
						main = candidate
					elif int(candidate["id"]) == ident + 1:
						next = candidate
				_check(not before.is_empty() and not main.is_empty(), "both sides share the original main path")
				if not before.is_empty():
					_check(CROSSROADS.reachable(before, lily), "SURGE entrance is fair for the touch gesture")
				if not next.is_empty():
					_check(CROSSROADS.reachable(lily, next), "SURGE rejoins without an impossible leap")
				if not main.is_empty():
					_check(float(lily["m"]) == float(main["m"]), "choices have identical progress")
		for ident in groups.keys():
			_check(groups[ident].size() == 2 and groups[ident].has(1) and groups[ident].has(2),
				"each visible crossroads offers exactly two mutually exclusive choices")
			total_pairs += 1
		_check(game.pads.size() < 290, "rare choices preserve bounded streaming memory")
	_check(total_pairs >= 3, "four long runs reveal multiple actual crossroads")
	# Real landing test on both branches at normal starting distance.
	for choose_surge in [false, true]:
		game._reset_game()
		game.mode = game.MODE_PLAY
		game.wave_m = -75.0
		game.daily.goals_claimed = 7
		game.daily.weekly_claimed = 7
		game.daily.milestones_claimed = (1 << game.daily.MILESTONES.size()) - 1
		var standard: Dictionary = game.pads[1]
		standard["crossroad_id"] = 31
		standard["crossroad_choice"] = 1
		standard["crossroad_biome"] = 1
		var alternate: Dictionary = standard.duplicate(true)
		alternate["id"] = CROSSROADS.SIDE_ID_BASE + 31
		alternate["x"] = clampf(float(standard["x"]) + (92.0 if float(standard["x"]) < 300.0 else -92.0), 94.0, 446.0)
		alternate["r"] = 39.0
		alternate["coin"] = false
		alternate["pet"] = false
		alternate["boost"] = false
		alternate["guardian"] = false
		alternate["harmony"] = false
		alternate["trial"] = false
		alternate["crossroad_choice"] = 2
		game.pads.insert(2, alternate)
		var leaves_before: int = game.leaves
		var score_before: int = game.score
		var wave_before: float = game.wave_m
		_hop(game, alternate if choose_surge else standard)
		_check(not bool(int(standard.get("crossroad_choice", 0))) and not bool(int(alternate.get("crossroad_choice", 0))),
			"real landing consumes both options, not just selected one")
		_check(CROSSROADS.claim(alternate, game.pads).is_empty() and CROSSROADS.claim(standard, game.pads).is_empty(),
			"both awards are blocked after one successful landing")
		_check(game.leaves == leaves_before, "event itself does not mint extra leaves")
		if choose_surge:
			_check(game.flow_seconds > 0.0 and game.score >= score_before + CROSSROADS.SURGE_POINTS[1],
				"risk path earns real Flow time and score")
		else:
			_check(game.wave_m < wave_before - 4.0, "REST creates substantial actual wave relief")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: exclusive tactical choices, long-stream fair exits, 2 real rewarded landings and zero currency duplication")
	else:
		printerr("FAIL: %d rare-crossroads regressions" % failures)
	quit(0 if failures == 0 else 1)
