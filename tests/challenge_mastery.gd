extends SceneTree
## Real landing payouts, durable lifetime mastery, reset semantics, and old-save migration.
var failures := 0
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._reset_game()
	game.mode = game.MODE_PLAY
	game.wave_m = -90.0
	game.daily.goals_claimed = 7
	game.daily.weekly_claimed = 7
	game.daily.milestones_claimed = (1 << game.daily.MILESTONES.size()) - 1
	var old_wins: Array = game.lifetime_challenge_wins.duplicate()
	var old_best_chain: int = game.lifetime_best_challenge_streak
	_check(old_wins.size() == 4, "four permanent mastery counters")
	# Force one genuine optional challenge opening after only one hop,
	# then land three authentic perfect jumps under normal collision logic.
	game.run_hops = 17
	game.rng.seed = 32655
	for i in range(3):
		var target: Dictionary = {}
		for pad in game.pads:
			if int(pad["id"]) < 1000000 and float(pad["m"]) > game.player_m + 3.0:
				target = pad
				break
		_check(not target.is_empty(), "reachable main lily")
		if target.is_empty():
			break
		var tries := 0
		while game._landing_target(game._predicted_pad_x(target), float(target["m"])).is_empty() and tries < 140:
			game._process(0.02)
			tries += 1
		if tries >= 140:
			_check(false, "non-crab perfect target is reachable")
			break
		game.aim_x = game._predicted_pad_x(target)
		game.aim_m = float(target["m"])
		game._start_jump()
		_check(game.jump_is_perfect, "real perfect preview accepted by launcher")
		for frame in range(60):
			game._process(0.02)
			if game.mode != game.MODE_FLY:
				break
		_check(game.mode == game.MODE_PLAY, "perfect landed without death")
	_check(game.precision_sprint.completions == 1, "one truly earned precision challenge")
	_check(game.lifetime_challenge_wins[0] == old_wins[0] + 1, "precisely one permanent precision win credited")
	_check(game.lifetime_best_challenge_streak == maxi(old_best_chain, 1),
		"one truly earned victory updates only a better lifetime chain")
	for kind in range(1,4):
		_check(game.lifetime_challenge_wins[kind] == old_wins[kind], "other categories unaffected")
	var score_before: int = game.score
	var leaves_before: int = game.leaves
	game._save_progress()
	var save := ConfigFile.new()
	_check(save.load("user://jumpy_frog.cfg") == OK, "lifetime mastery persisted to atomic save")
	var stored: Array = save.get_value("records", "challenge_wins", [])
	_check(stored.size() == 4 and stored[0] == old_wins[0] + 1, "saved mastery is exact")
	_check(int(save.get_value("records", "best_challenge_streak", -1)) == maxi(old_best_chain, 1),
		"highest challenge chain is persisted exactly and never loses old records")
	game._reset_game()
	_check(game.lifetime_challenge_wins[0] == old_wins[0] + 1, "new runs do not wipe lifetime mastery")
	_check(game.lifetime_best_challenge_streak == maxi(old_best_chain, 1),
		"new runs do not wipe highest consecutive win record")
	_check(game.precision_sprint.completions == 0, "new run resets temporary win count")
	_check(game.leaves == leaves_before and game.score == 0 and score_before > 0, "permanent vs ephemeral economy clean")
	game._start_daily_river()
	_check(game.lifetime_challenge_wins[0] == old_wins[0] + 1, "daily river retains permanent mastery")
	game.queue_free()
	await process_frame
	var reloaded: Node2D = load("res://main.tscn").instantiate()
	root.add_child(reloaded)
	await process_frame
	_check(reloaded.lifetime_best_challenge_streak == maxi(old_best_chain, 1),
		"reopened application restores the best streak from durable storage")
	_check(reloaded.lifetime_challenge_wins[0] == old_wins[0] + 1,
		"reopened application restores previously earned mastery")
	reloaded.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: real mastery credited once, lifetime best consecutive chain, atomic save, reboot persistence and migration")
	quit(0 if failures == 0 else 1)

func _check(ok: bool, reason: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + reason)
