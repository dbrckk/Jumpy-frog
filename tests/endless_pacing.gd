extends SceneTree
## Endless checkpoints award a small guaranteed reward without disrupting
## touch fairness, offline economy, chapter pacing or long-run frame budget.
const PACING = preload("res://scripts/endless_pacing.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_exercise")

func _exercise() -> void:
	_check(is_equal_approx(PACING.hazard_probability(0.0), 0.05), "beginners encounter fewer crabs")
	_check(PACING.hazard_probability(280.0) < PACING.hazard_probability(650.0), "hazard variety ramps gradually")
	_check(is_equal_approx(PACING.hazard_probability(900.0), 0.20), "hazard frequency reaches original maximum")
	_check(is_equal_approx(PACING.hazard_probability(9000.0), 0.20), "no infinite hazard escalation")
	for distance in range(0, 3000, 5):
		_check(PACING.hazard_probability(float(distance)) >= 0.05 and PACING.hazard_probability(float(distance)) <= 0.20,
			"probabilities remain bounded at all distances")
	_check(PACING.crossed_landmark(249.0, 251.0) == 250, "first threshold correctly recognized")
	_check(PACING.crossed_landmark(251.0, 251.0) == 0, "same distance cannot repay a marker")
	_check(PACING.crossed_landmark(251.0, 249.0) == 0, "backtracking cannot repay a marker")
	_check(PACING.crossed_landmark(499.5, 501.0) == 500, "second threshold recognized")
	_check(PACING.crossed_landmark(751.0, 775.0) == 0, "within a bracket earns no reward")
	_check(PACING.crossed_landmark(975.0, 1005.0) == 1000, "kilometer milestone recognized")

	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._reset_game()
	game.mode = game.MODE_PLAY
	game.rng.seed = 41521
	game.daily.goals_claimed = 7
	game.daily.weekly_claimed = 7
	game.daily.milestones_claimed = (1 << game.daily.MILESTONES.size()) - 1
	game.wave_m = -80.0
	var milestones_seen := 0
	for hop in range(76):
		if game.mode != game.MODE_PLAY:
			_check(false, "Endless run survives ordinary long-run landings")
			break
		var next: Dictionary = {}
		for p in game.pads:
			if int(p["id"]) < 1000000 and float(p["m"]) > game.player_m + 3.0:
				next = p
				break
		_check(not next.is_empty(), "course always provides normal route")
		if next.is_empty():
			break
		var attempts := 0
		while game._landing_target(game._predicted_pad_x(next), float(next["m"])).is_empty() and attempts < 115:
			game._process(0.02)
			attempts += 1
			if game.mode != game.MODE_PLAY:
				break
		if game.mode != game.MODE_PLAY:
			break
		_check(attempts < 115, "temporary danger clears fairly")
		var before_wave: float = game.wave_m
		var before_leaves: int = game.leaves
		var previous_mark: int = game.run_landmarks
		var old_height: float = game.highest_m
		var expected_mark: int = PACING.crossed_landmark(old_height, float(next["m"]))
		game.aim_x = game._predicted_pad_x(next)
		game.aim_m = float(next["m"])
		game._start_jump()
		for frame in range(60):
			game._process(0.02)
			if game.mode != game.MODE_FLY:
				break
		_check(game.mode == game.MODE_PLAY, "reachable landing succeeds")
		if game.mode != game.MODE_PLAY:
			break
		if expected_mark > 0:
			milestones_seen += 1
			_check(game.run_landmarks == previous_mark + 1, "exactly one checkpoint credit")
			_check(game.distance_banner_mark == expected_mark, "correct checkpoint banner")
			_check(game.distance_banner_seconds > 0.0, "milestone animation shown")
			_check(game.leaves >= before_leaves + PACING.LANDMARK_LEAVES, "earned leaves paid")
			_check(game.wave_m < before_wave + 10.0, "marker gives real wave relief")
		else:
			_check(game.run_landmarks == previous_mark, "ordinary lily cannot grant free landmark")
		_check(game.particles.size() <= 110, "celebration particles stay bounded")
		_check(game.ripples.size() <= 12, "ripples remain bounded")
	_check(game.player_m > 1050.0, "long run covers more than a kilometer")
	_check(milestones_seen >= 4, "milestones remain a recurring long-run goal")
	_check(game.run_landmarks == int(floor(game.highest_m / 250.0)), "landmark economy never skips or duplicates markers")
	var final_leaves: int = game.leaves
	game._save_progress()
	var cfg := ConfigFile.new()
	_check(cfg.load("user://jumpy_frog.cfg") == OK, "awards persisted by shared resilient storage")
	_check(int(cfg.get_value("progress", "leaves", -1)) == final_leaves, "persisted currency includes checkpoints")
	game._reset_game()
	_check(game.run_landmarks == 0 and game.distance_banner_seconds == 0.0 and game.distance_banner_mark == 0,
		"next Endless run resets ephemeral celebrations and rewards")
	_check(game.leaves == final_leaves, "new run keeps previously earned leaves")

	# Existing narrative and daily mode never earn new Endless checkpoint bonuses.
	for stage in range(6):
		game._start_chapter(stage)
		_check(game.run_landmarks == 0, "chapter never inherits Endless milestones")
	game._start_daily_river()
	_check(game.run_landmarks == 0, "daily seeded event remains independent")

	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: gradual hazard balancing, 250m milestones, exact rewards, long-run safety, save, zero replay")
	else:
		printerr("FAIL: %d pacing/milestone regressions" % failures)
	quit(0 if failures == 0 else 1)

func _check(valid: bool, name: String) -> void:
	if not valid:
		failures += 1
		push_error("FAIL: " + name)
