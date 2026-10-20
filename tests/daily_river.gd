extends SceneTree
## Daily River integration: route reproducibility, real jumps and one-off currency.
var failures := 0

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var today: int = game.daily.day_id
	_check(today > 0, "UTC day is initialized")
	# Test must not inherit yesterday's QA run or today's already-claimed
	# reward from the same user:// save file. Production claim-once remains intact.
	game.daily.river_completed_day = -1
	game.daily.river_best_score = 0
	game.daily.river_attempts = 0
	game._start_daily_river()
	_check(game.mode == 1 and game.campaign_stage == -2, "daily challenge starts")
	var initial_route: Array = []
	for i in range(mini(9, game.pads.size())):
		var pad: Dictionary = game.pads[i]
		initial_route.append([pad["x"], pad["m"], pad["kind"], pad["coin"], pad["pet"], pad.get("boost", false)])
	_check(game.daily.river_attempts >= 1, "attempt recorded")
	game._start_daily_river()
	var again: Array = []
	for i in range(mini(9, game.pads.size())):
		var pad: Dictionary = game.pads[i]
		again.append([pad["x"], pad["m"], pad["kind"], pad["coin"], pad["pet"], pad.get("boost", false)])
	_check(initial_route == again, "identical UTC daily river on replay")
	_check(game.daily.day_id == today, "retry does not change daily seed")

	# Walk the actual game loop, including the real landing and win handling.
	for hop in range(20):
		if game.mode != 1:
			break
		var next_pad: Dictionary = {}
		for pad in game.pads:
			if float(pad["m"]) > game.player_m + 3.0:
				next_pad = pad
				break
		if next_pad.is_empty():
			_check(false, "next daily platform exists")
			break
		game.aim_x = next_pad["x"]
		game.aim_m = next_pad["m"]
		game._start_jump()
		_check(game.jump_pad_id == int(next_pad["id"]), "daily landing target is valid")
		for frame in range(50):
			game._process(0.02)
			if game.mode != 3:
				break
		_check(game.mode in [1, 9], "daily landing does not unexpectedly die")
	_check(game.mode == 9, "daily finish reached through real hops")
	_check(game.daily.river_complete_today(), "daily finish marks today's challenge complete")
	_check(game.clear_reward == 25, "daily challenge pays 25 leaves only on first success")
	var balance: int = game.leaves
	var highest: int = game.daily.river_best_score
	_check(highest > 0, "daily best score saved")
	game._start_daily_river()
	_check(game.mode == 1 and game.campaign_stage == -2, "daily challenge replay starts")
	# After completing the challenge once, do not issue another 25-leaf prize.
	game.score = 1234
	game.player_m = game.daily.RIVER_TARGET
	game._finish_daily_river()
	_check(game.mode == 9 and game.clear_reward == 0, "replay finishes without double-paying daily reward")
	_check(game.leaves == balance, "replay keeps previous leaf balance")
	var save := ConfigFile.new()
	_check(save.load("user://jumpy_frog.cfg") == OK, "daily progress stored to disk")
	var fresh = load("res://scripts/daily.gd").new()
	fresh.load_from(save)
	_check(fresh.river_completed_day == today, "claimed day persists across reload")
	_check(fresh.river_best_score >= highest, "daily best persists across reload")
	_check(fresh.finish_river(12345) == 0, "reloading cannot claim daily reward twice")
	fresh.refresh_day(today + 1)
	_check(not fresh.river_complete_today(), "new UTC day resets completion status")
	_check(fresh.river_best_score == 0, "new day resets the daily record")
	_check(fresh.finish_river(500) == 25, "new day can claim a new reward")
	_check(fresh.finish_river(600) == 0, "new day still pays once")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: daily route determinism, 180m chapter-like run, reward once per day, save, UTC rollover")
	else:
		printerr("FAIL: daily river integration %d assertions" % failures)
	quit(0 if failures == 0 else 1)

func _check(ok: bool, title: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + title)
