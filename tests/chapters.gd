extends SceneTree
## Deterministic chapter progression and replayability regression suite.
var errors := 0

func _initialize() -> void:
	call_deferred("_run")

func _test(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var Chapters: Script = load("res://scripts/chapters.gd")
	var records: RefCounted = Chapters.new()
	_test(records.LEVELS.size() == 6, "all six chapters are defined")
	_test(records.can_play(0) and not records.can_play(1), "only first stage available initially")
	for i in range(6):
		var level: Dictionary = records.chapter(i)
		_test(int(level["target"]) > 100, "chapters have real distance goals")
		_test(int(level["reward"]) > 0, "each chapter awards leaves")
		_test(records.biome_at(20.0, i) == i, "level uses its distinct biome")
	_test(records.biome_at(145.0, -1) == 1, "endless biome changes at 140 meters")
	_test(records.biome_at(850.0, -1) == 0, "endless biomes cycle for infinite replayability")
	var invalid: Dictionary = records.complete(3, 10000, 100)
	_test(int(invalid["stars"]) == 0, "locked chapters cannot award prizes")
	var first: Dictionary = records.complete(0, 1500, 10)
	_test(int(first["stars"]) == 3, "chapter scores and leaves produce three medals")
	_test(int(first["reward"]) > 0, "first full completion grants leaves")
	_test(records.can_play(1), "finishing stage unlocks next")
	var repeat: Dictionary = records.complete(0, 1500, 10)
	_test(int(repeat["reward"]) == 0, "replaying a mastered chapter cannot print currency")
	# No premium currency is awarded by time records.
	_test(not records.record_time(1, 20.0), "locked or unfinished chapter has no PB")
	_test(not records.record_time(0, 0.0), "zero second time is rejected")
	_test(not records.record_time(0, 90000.0), "invalid enormous times are rejected")
	_test(records.record_time(0, 26.42), "first completed race establishes a PB")
	_test(records.best_times_ms[0] == 26420, "race time stored in milliseconds")
	_test(not records.record_time(0, 30.0), "slower attempt cannot replace faster record")
	_test(records.record_time(0, 24.12), "faster attempt sets new record")
	_test(records.format_time(24120) == "00:24.1", "PB formatted consistently")
	var saved := ConfigFile.new()
	records.write_to(saved)
	var loaded: RefCounted = Chapters.new()
	loaded.load_from(saved)
	_test(loaded.can_play(1) and int(loaded.medals[0]) == 3, "chapter medal persists")
	_test(int(loaded.best_times_ms[0]) == 24120, "PB survives save/load")
	_test(not loaded.record_time(0, 24.12), "replayed identical time is not new PB")
	_test(int(loaded.complete(0, 1500, 10)["reward"]) == 0, "reloading cannot duplicate rewards")
	for index in range(1, 6):
		loaded.complete(index, 10000, 100)
	_test(loaded.completed_count() == 6 and loaded.unlocked_count == 6, "entire campaign can be finished")
	var full := ConfigFile.new()
	loaded.write_to(full)
	var restored: RefCounted = Chapters.new()
	restored.load_from(full)
	_test(restored.completed_count() == 6, "completed campaign survives save/load")

	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.chapters = Chapters.new()
	game._reset_game()
	game.mode = 0
	game._down(Vector2(270, 581))
	_test(game.mode == 8, "home opens chapter menu")
	game._down(Vector2(165, 382))
	_test(game.mode == 1 and game.campaign_stage == 0, "first chapter opens as playable game")
	_test(game.chapters.attempts[0] == 1, "chapter attempt recorded")
	_test(game.chapter_elapsed == 0.0, "new chapter starts clock at zero")
	game._process(0.4)
	_test(is_equal_approx(game.chapter_elapsed, 0.4), "timer uses actual delta")
	game._pause_game()
	var frozen_time: float = game.chapter_elapsed
	game._process(3.0)
	_test(is_equal_approx(game.chapter_elapsed, frozen_time), "pause freezes race timer")
	game._resume_game()
	var total_hops := 0
	while game.mode in [1, 2, 3] and total_hops < 20:
		var next: Dictionary = {}
		for pad in game.pads:
			if float(pad["m"]) > game.player_m + 3.0:
				next = pad
				break
		if next.is_empty():
			break
		game.aim_x = float(next["x"])
		game.aim_m = float(next["m"])
		game._start_jump()
		_test(game.jump_pad_id == int(next["id"]), "generated chapter pad reachable")
		for tick in range(65):
			game._process(0.02)
		total_hops += 1
	_test(game.mode == 9, "real jumps finish first chapter and show victory")
	_test(total_hops >= 4, "chapter is a real multi-hop challenge")
	_test(game.perfect_streak >= 4, "center-aimed jumps sustain precise-landing streak")
	_test(game.chapters.can_play(1), "game unlocks chapter two after success")
	_test(game.clear_medal >= 1, "game awards at least one star on success")
	_test(game.clear_new_time_record and game.chapter_elapsed > 0.0, "real completed race sets PB")
	_test(int(game.chapters.best_times_ms[0]) == roundi(game.chapter_elapsed * 1000.0), "PB uses the actual finish duration")
	_test(game.best_score >= game.score, "chapter victories update personal best")
	var hard_earned: int = game.leaves
	game._down(Vector2(375, 667))
	_test(game.mode == 0, "victory HOME button exits to title")
	_test(game.leaves == hard_earned, "leaves survive returning home")
	game._down(Vector2(270, 581))
	game._down(Vector2(360, 375))
	_test(game.campaign_stage == 1 and game.mode == 1, "second chapter opens after unlock")
	_test(game.sound.biome_id == 1, "chapter switches sound palette")
	var cfg := ConfigFile.new()
	_test(cfg.load("user://jumpy_frog.cfg") == OK, "chapter progress stored locally")
	_test(int(cfg.get_value("chapters", "unlocked", 1)) >= 2, "unlocked chapters survive app restart")
	_test(int(cfg.get_value("chapters", "best_time_ms_0", 0)) > 0, "PB written to durable on-device save")
	game.queue_free()
	await process_frame
	if errors == 0:
		print("PASS: 6 replayable chapters, procedural reachability, biome loops, medals, persistent rewards, chapter 2 unlock")
	quit(0 if errors == 0 else 1)
