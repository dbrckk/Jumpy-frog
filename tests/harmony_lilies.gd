extends SceneTree
## Optional precision rewards must never punish ordinary landings.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	# Deterministic layout: distinct, reachable objectives without a moving
	# or collapsing hazard overlapping a precision reward.
	game.chapters.unlocked_count = 6
	for biome in range(6):
		game._start_chapter(biome)
		game.player_m = 550.0
		game._generate_pads()
		var objectives := 0
		for pad in game.pads:
			if bool(pad.get("harmony", false)):
				objectives += 1
				_check(not bool(pad.get("moving", false)), "harmony never moves")
				_check(not bool(pad.get("fragile", false)), "harmony never collapses")
				_check(not bool(pad.get("guardian", false)), "harmony is distinguishable from Guardian")
				_check(int(pad["id"]) >= 6, "first five tutorial lilies remain ordinary")
		_check(objectives > 0, "all biomes contain optional precision challenges")

	# A centered touch earns 160 extra points and precisely one extra leaf.
	game._reset_game()
	game.mode = 1
	var target: Dictionary = game.pads[1]
	_clean_pickups(target)
	target["harmony"] = true
	var m: float = float(target["m"])
	var base: int = maxi(12, int(m * 13.0))
	var leaves_before: int = game.leaves
	game.aim_x = float(target["x"])
	game.aim_m = m
	_hop(game)
	_check(game.mode == 1 and game.jump_is_perfect, "center landing remains valid")
	_check(game.score == base + 39 + 160, "perfect Harmony adds exactly 160 points")
	_check(game.leaves == leaves_before + 1 and game.run_leaves == 1, "Harmony gives one earned leaf")
	_check(not bool(target["harmony"]), "reward marker is consumed on landing")
	_check(game.precision_pulse > 1.0, "centered Harmony sends a visible bright pulse")
	for i in range(100):
		game._process(0.02)
	_check(game.precision_pulse == 0.0, "visual pulse expires and cannot accumulate")

	# Off-center touch within the unchanged safe target: no penalty and
	# no precision bonus, while the normal progression still advances.
	game._reset_game()
	game.mode = 1
	var ordinary: Dictionary = game.pads[1]
	_clean_pickups(ordinary)
	ordinary["harmony"] = true
	var points: int = maxi(12, int(float(ordinary["m"]) * 13.0))
	var ordinary_leaves_before: int = game.leaves
	game.aim_x = float(ordinary["x"]) + float(ordinary["r"]) * 0.65
	game.aim_m = float(ordinary["m"])
	_hop(game)
	_check(game.mode == 1 and not game.jump_is_perfect, "off-center landing remains safe")
	_check(game.score == points, "ordinary Harmony landing awards only base points")
	_check(game.leaves == ordinary_leaves_before and game.run_leaves == 0, "off-center landing grants no free leaf")
	_check(not bool(ordinary["harmony"]), "Harmony cannot be harvested by visiting again")
	_check(game.precision_pulse == 0.0, "normal landing does not flash precision effect")

	# Perfect but already claimed: the ordinary existing perfect-streak
	# award applies, not another Harmony reward.
	game._reset_game()
	game.mode = 1
	var spent: Dictionary = game.pads[1]
	_clean_pickups(spent)
	spent["harmony"] = false
	var spent_base: int = maxi(12, int(float(spent["m"]) * 13.0))
	var spent_leaves_before: int = game.leaves
	game.aim_x = float(spent["x"])
	game.aim_m = float(spent["m"])
	_hop(game)
	_check(game.score == spent_base + 39, "non-Harmony perfect hop keeps original scoring")
	_check(game.leaves == spent_leaves_before, "claimed or ordinary lilies cannot pay a Harmony leaf")
	game._reset_game()
	_check(game.precision_pulse == 0.0, "new runs clear visual feedback")

	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: fair optional Harmony placement, exact rewards, no farming, off-center safety and bounded VFX")
	else:
		printerr("FAIL: %d harmony regressions" % failures)
	quit(0 if failures == 0 else 1)

func _clean_pickups(pad: Dictionary) -> void:
	pad["coin"] = false
	pad["pet"] = false
	pad["boost"] = false
	pad["guardian"] = false
	pad["fragile"] = false
	pad["moving"] = false

func _hop(game: Node2D) -> void:
	game._start_jump()
	for frame in range(65):
		game._process(0.02)
		if game.mode != 3:
			break

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
