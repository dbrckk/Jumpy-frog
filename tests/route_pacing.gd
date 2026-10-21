extends SceneTree
## Endless phrase variety, ordinary reachability, and persistent personal distance.
const DIRECTOR = preload("res://scripts/route_director.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for seed in [132, 764, 981]:
		game._reset_game()
		game.mode = game.MODE_PLAY
		game.rng.seed = seed
		game.pads.resize(1)
		game.last_generated_m = 0.0
		game.last_pad_x = 270.0
		game.next_pad_id = 1
		game.route_director.reset()
		game.player_m = 2950.0
		game._generate_pads()
		var counts: Array = game.route_director.motif_counts
		var variation := 0
		for count in counts:
			if int(count) > 0:
				variation += 1
		_assert(variation >= 3, "long Endless course uses at least three distinct phrases")
		_assert(int(counts[0]) + int(counts[1]) + int(counts[2]) + int(counts[3]) > 7,
			"long course creates many complete sixteen-hop phrases")
		var last: Dictionary = {}
		var max_jump_px := 0.0
		for pad in game.pads:
			if int(pad["id"]) >= 1000000:
				continue # optional branch has its own fairness test
			if not last.is_empty():
				var dx: float = float(pad["x"]) - float(last["x"])
				var dy: float = float(pad["m"]) - float(last["m"])
				_assert(float(pad["m"]) > float(last["m"]), "course always moves up river")
				var gesture := Vector2(dx / 1.2, dy * 8.0 / 1.35).length()
				max_jump_px = maxf(max_jump_px, gesture)
				_assert(gesture < 215.0, "all procedural motifs preserve the touch reachability budget")
				_assert(float(pad["x"]) >= 92.0 and float(pad["x"]) <= 448.0, "every main pad remains inside the river")
			last = pad
		_assert(max_jump_px > 15.0, "motifs create visible route movement")

	# Shared director is deterministic for a given random seed and never
	# repeats the previous phrase (even when the RNG would pick it again).
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 18061
	r2.seed = 18061
	var p1 := DIRECTOR.new()
	var p2 := DIRECTOR.new()
	var previous := -1
	for ident in range(1, 257):
		var raw_a := r1.randf_range(-44.0, 44.0)
		var raw_b := r2.randf_range(-44.0, 44.0)
		_assert(is_equal_approx(raw_a, raw_b), "test source streams begin equivalent")
		var a: float = p1.lateral_delta(ident, raw_a, 44.0, r1, ident in [23, 24, 25])
		var b: float = p2.lateral_delta(ident, raw_b, 44.0, r2, ident in [23, 24, 25])
		_assert(is_equal_approx(a, b), "same seed always produces the same route phrases")
		_assert(absf(a) <= 44.001, "director never exceeds biome drift")
		if ident in [23, 24, 25]:
			_assert(absf(a) <= 44.0 * 0.3 + 0.01, "Firefly Festival remains a genuine breathing space")
		if (ident - 1) % DIRECTOR.LENGTH == 0:
			_assert(p1.current_motif != previous, "no repeated adjacent route phrase")
			previous = p1.current_motif
	_assert(p1.motif_counts == p2.motif_counts, "both directors distribute motifs identically")

	# Story / daily have no route-director changes or surprise triggers.
	for chapter in range(6):
		game._start_chapter(chapter)
		_assert(game.route_director.phrase_number <= 0, "story generator does not use Endless director beyond title setup")
	game._start_daily_river()
	_assert(game.route_director.phrase_number <= 0, "daily generator does not use Endless director beyond title setup")

	# A personal record is awarded only in Endless, saved after the hop,
	# shown in results, and preserved across restart and unrelated chapters.
	game._reset_game()
	game.mode = game.MODE_PLAY
	game.best_endless_m = 0
	var next: Dictionary = game.pads[1]
	game.aim_x = float(next["x"])
	game.aim_m = float(next["m"])
	game._start_jump()
	for frame in range(55):
		game._process(0.02)
		if game.mode != game.MODE_FLY:
			break
	_assert(game.mode == game.MODE_PLAY, "real hop succeeded")
	_assert(game.best_endless_m >= 14 and game.run_new_distance_record, "first Endless personal distance recorded")
	game._save_progress()
	var old_best: int = game.best_endless_m
	var save := ConfigFile.new()
	_assert(save.load("user://jumpy_frog.cfg") == OK, "personal best uses existing reliable storage")
	_assert(int(save.get_value("records", "best_endless_m", 0)) == old_best, "Endless distance persisted")
	game._die()
	_assert(game.run_new_record, "new Endless distance triggers personal best on summary")
	game._reset_game()
	_assert(game.best_endless_m == old_best and not game.run_new_distance_record,
		"new run clears celebration but keeps stored Endless record")
	game._start_chapter(0)
	for i in range(2):
		var primary: Dictionary = {}
		for pad in game.pads:
			if float(pad["m"]) > game.player_m + 3.0:
				primary = pad
				break
		game.aim_x = float(primary["x"])
		game.aim_m = float(primary["m"])
		game._start_jump()
		for frame in range(55):
			game._process(0.02)
			if game.mode != game.MODE_FLY:
				break
	_assert(game.best_endless_m == old_best, "story distance cannot inflate Endless record")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: four deterministic route motifs, reachability, festival rest, untouched story/daily, saved Endless record")
	else:
		printerr("FAIL: %d procedural pacing or distance regressions" % failures)
	quit(0 if failures == 0 else 1)

func _assert(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + why)
