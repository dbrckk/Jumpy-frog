extends SceneTree
## Long-session, chapter and procedural-generation endurance regression.
## Keeps the Godot main loop headless and exercises real hop/landing mechanics.
var failures := 0

func _initialize() -> void:
	call_deferred("_exercise")

func _exercise() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# The six handcrafted chapters must all unlock and be finishable in sequence.
	for chapter_index in range(6):
		_check(game.chapters.can_play(chapter_index), "chapter %d is accessible after predecessor" % chapter_index)
		game._start_chapter(chapter_index)
		_check(game.mode == 1, "chapter %d starts correctly" % chapter_index)
		_play_hops(game, 24)
		_check(game.mode == 9, "chapter %d completes by jumping, not by bypassing gameplay" % chapter_index)
		_check(game.chapters.medals[chapter_index] > 0, "chapter %d awards a medal" % chapter_index)
		_check(game.clear_reward >= 0, "chapter %d reward is nonnegative" % chapter_index)
		if game.mode != 9:
			break
	_check(game.chapters.completed_count() == 6, "all six chapters can be completed")
	_check(game.chapters.unlocked_count == 6, "all chapters eventually unlock")

	# Endless mode: advance for >2 km, cross all biomes and keep memory bounded.
	game._reset_game()
	game.mode = 1
	var seen_biomes: Dictionary = {}
	for hop in range(155):
		if game.mode != 1:
			_check(false, "endless run stays alive for 155 valid hops")
			break
		seen_biomes[game.chapters.biome_at(game.player_m, -1)] = true
		_play_hops(game, 1)
		_check(game.pads.size() <= 24, "platform window pruned on prolonged run")
		_check(game.particles.size() <= 110, "VFX pool bounded on prolonged run")
		_check(game.ripples.size() <= 12, "ripples bounded on prolonged run")
	_check(game.player_m > 2200, "endless distance exceeds 2.2 kilometers")
	_check(seen_biomes.size() == 6, "endless run visits all six biomes")
	_check(game.score > 0 and game.daily.lifetime_hops >= 155, "long run earns score and persistent progression")
	# Realistic user idle between hops: the game must not let decorative
	# menus/repeated focus interruptions corrupt an established long run.
	var survived_m: float = game.player_m
	var survived_score: int = game.score
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(game.mode == game.MODE_PAUSED, "backgrounding an extended endless run pauses safely")
	for background_frame in range(12):
		game._process(0.10)
	_check(game.player_m == survived_m and game.score == survived_score,
		"lengthy background frames never consume long-run progress")
	game._resume_game()
	_check(game.mode == game.MODE_PLAY and game.player_m == survived_m,
		"long run resumes at its original lily without teleportation")
	game._save_progress()
	var stored := ConfigFile.new()
	_check(stored.load("user://jumpy_frog.cfg") == OK, "long-run save is readable")
	_check(int(stored.get_value("lifetime", "hops", 0)) >= 155, "endurance milestones persist")

	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: 6 campaign chapters, permanent medals, 155-hop endurance, all biomes, bounded VFX and saves")
	else:
		printerr("FAIL: endurance assertions " + str(failures))
	quit(0 if failures == 0 else 1)

func _play_hops(game: Node2D, count: int) -> void:
	for i in range(count):
		if game.mode != 1:
			return
		var pad_target: Dictionary = {}
		for candidate in game.pads:
			if float(candidate["m"]) > game.player_m + 3.0:
				pad_target = candidate
				break
		if pad_target.is_empty():
			_check(false, "generated course always provides a next lily")
			return
		# The bot respects temporary danger warnings just like a player:
		# wait briefly for the red landing ring to become safe. Holding the
		# starting lily is safe, and no artificial collision bypass is used.
		var waits := 0
		while game._landing_target(game._predicted_pad_x(pad_target), float(pad_target["m"])).is_empty() and waits < 100:
			game._process(0.02)
			waits += 1
			if game.mode != 1:
				return
		_check(waits < 100, "temporary crab clears within its announced hazard cycle")
		game.aim_x = game._predicted_pad_x(pad_target)
		game.aim_m = pad_target["m"]
		game._start_jump()
		_check(game.jump_pad_id == int(pad_target["id"]), "hop lands on predictable target")
		for frame in range(55):
			game._process(0.02)
			if game.mode != 3:
				break
		_check(game.mode in [1, 9], "generated valid hop avoids accidental death")
		if game.mode != 1:
			return

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
