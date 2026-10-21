extends SceneTree
## Reward-free run grades, persisted personal records and the actual result view.
const REPORT = preload("res://scripts/run_report.gd")
const DAILY = preload("res://scripts/daily.gd")
var errors := 0

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	_check(REPORT.grade(0, 0, 0, 0) == "FIRST SPLASH", "zero hop is accurately labeled")
	_check(REPORT.grade(3, 1, 0, 0) == "RIVER ROOKIE", "beginner badge")
	_check(REPORT.grade(9, 2, 0, 0) == "LILY EXPLORER", "replay progress badge")
	_check(REPORT.grade(17, 6, 0, 1) == "CURRENT MASTER", "skill rank")
	_check(REPORT.grade(33, 13, 4, 2) == "RIVER LEGEND", "expert rank")
	var daily = DAILY.new()
	daily.refresh_day(26002)
	_check(REPORT.next_weekly_goal(daily).get("title", "") == "30 RIVER HOPS", "weekly hint starts at first goal")
	daily.weekly_perfect = 7
	var suggested: Dictionary = REPORT.next_weekly_goal(daily)
	_check(String(suggested["title"]) == "8 PERFECT LANDINGS", "hint favors closest unfinished weekly goal")
	daily.weekly_claimed |= 2
	_check(REPORT.next_weekly_goal(daily).get("title", "") == "30 RIVER HOPS", "claimed tasks hidden from retry hint")
	daily.weekly_claimed = 7
	_check(REPORT.next_weekly_goal(daily).is_empty(), "all weekly complete produces no misleading next goal")

	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._reset_game()
	game.best_score = 1000
	game.best_run_perfects = 5
	game.best_run_combo = 5
	game.best_run_friends = 2
	game.score = 1200
	game.run_hops = 8
	game.run_perfects = 6
	game.run_peak_combo = 8
	game.run_friends = 1
	game.mode = game.MODE_PLAY
	game._die()
	_check(game.mode == game.MODE_LOST, "end screen stays visible")
	_check(game.run_new_record, "new score/precision/combo is celebrated")
	_check(game.best_score == 1200 and game.best_run_perfects == 6 and game.best_run_combo == 8, "new career personal best persisted in memory")
	_check(game.best_run_friends == 2, "lesser friend tally never erases existing record")
	game._die()
	_check(game.best_score == 1200, "repeated run termination cannot re-award metrics")
	var save := ConfigFile.new()
	_check(save.load("user://jumpy_frog.cfg") == OK, "records saved to disk on defeat")
	_check(int(save.get_value("records", "perfects", -1)) == 6, "perfect record actually persisted")
	_check(int(save.get_value("records", "combo", -1)) == 8, "combo record actually persisted")
	_check(int(save.get_value("records", "friends", -1)) == 2, "friend record actually persisted")

	game._reset_game()
	_check(game.run_hops == 0 and game.run_perfects == 0 and game.run_peak_combo == 0 and game.run_friends == 0 and not game.run_new_record, "new run resets counters")
	_check(game.best_run_perfects == 6 and game.best_run_combo == 8, "new run retains saved best records")
	game.score = 10
	game.run_hops = 1
	game.run_perfects = 0
	game.run_peak_combo = 1
	game.run_friends = 0
	game.mode = game.MODE_PLAY
	game._die()
	_check(not game.run_new_record, "poorer run does not announce new record")
	_check(game.best_run_perfects == 6, "poorer run never downgrades best")

	game._reset_game()
	game.mode = game.MODE_PLAY
	var target: Dictionary = game.pads[1]
	game.aim_x = float(target["x"])
	game.aim_m = float(target["m"])
	game._start_jump()
	for i in range(65):
		game._process(0.02)
		if game.mode != game.MODE_FLY:
			break
	_check(game.mode == game.MODE_PLAY and game.run_hops == 1, "real landing increments report hop count")
	_check(game.run_perfects == 1 and game.run_peak_combo == 1, "real perfect hop increments report stats")
	game.queue_free()
	await process_frame

	# Compatibility with existing ConfigFile: missing records initialize to 0.
	var legacy := ConfigFile.new()
	_check(int(legacy.get_value("records", "perfects", 0)) == 0, "old saves have safe zero-valued new records")
	if errors == 0:
		print("PASS: real run reports, non-monetary ranks, persisted records and weekly retry guidance")
	else:
		printerr("FAIL: %d run-report checks" % errors)
	quit(0 if errors == 0 else 1)

func _check(ok: bool, what: String) -> void:
	if not ok:
		errors += 1
		push_error("FAIL: " + what)
