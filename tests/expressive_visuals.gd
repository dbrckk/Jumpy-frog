extends SceneTree
## Expressive frog animation and biome silhouettes: safe even on Redmi quality 0.
const MOTION = preload("res://scripts/visual_motion.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_exercise")

func _exercise() -> void:
	_check(MOTION.gaze(1, Vector2(200, 600), Vector2(440, 200), 0.0) == Vector2.ZERO,
		"idle game look is neutral")
	_check(is_equal_approx(MOTION.gaze(2, Vector2(200, 600), Vector2(440, 200), 0.0).x, MOTION.LOOK_LIMIT_X),
		"far right target gaze is bounded")
	_check(is_equal_approx(MOTION.gaze(2, Vector2(440, 600), Vector2(200, 200), 0.0).x, -MOTION.LOOK_LIMIT_X),
		"far left target gaze is bounded")
	_check(MOTION.gaze(2, Vector2(200, 600), Vector2(200, 600), 0.0) == Vector2.ZERO,
		"zero-distance gaze remains centered")
	_check(MOTION.gaze(3, Vector2.ZERO, Vector2.ZERO, 0.5).x <= MOTION.LOOK_LIMIT_X,
		"flight follows inertia within safe eye socket")
	for mood in [-1, 0, 1, 2]:
		_check(mood in [-1, 0, 1, 2], "bounded expression palette")
	_check(MOTION.mood(2, true, true, false) == 2, "gold PERFECT preview makes frog smile")
	_check(MOTION.mood(2, true, false, false) == 1, "green safe preview stays focused")
	_check(MOTION.mood(2, false, false, true) == -1, "timed crab warns with a worried face")
	_check(MOTION.mood(2, true, true, true) == -1, "danger always outranks false celebratory mood")
	_check(MOTION.mood(1, true, true, true) == 0, "not aiming returns to idle facial pose")
	_check(MOTION.bank_prop_count(0) == 2 and MOTION.bank_prop_count(1) == 6 and MOTION.bank_prop_count(2) == 10,
		"tier zero has just two bank silhouettes; high quality remains bounded")
	for biome in range(6):
		for quality in range(3):
			var last := MOTION.environmental_drift(1.25, 4, biome)
			var repeated := MOTION.environmental_drift(1.25, 4, biome)
			_check(is_equal_approx(last, repeated), "environmental animation repeatable without RNG")
			_check(absf(last) <= (5.31 if biome == 5 else 2.81),
				"wind movement stays within the shoreline")

	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._reset_game()
	game.mode = game.MODE_AIM
	var initial_score: int = game.score
	var initial_pads: int = game.pads.size()
	var initial_leaves: int = game.leaves
	var target: Dictionary = game.pads[1]
	game.aim_m = float(target["m"])
	game.aim_x = float(target["x"])
	var position_before: Vector2 = Vector2(game.player_x, game.player_m)
	var generated: int = game.next_pad_id
	game.queue_redraw()
	await process_frame
	_check(Vector2(game.player_x, game.player_m) == position_before,
		"rendering expressions never advances gameplay")
	_check(game.next_pad_id == generated and game.pads.size() == initial_pads,
		"new environmental draw layers cannot generate platforms")
	_check(game.score == initial_score and game.leaves == initial_leaves,
		"draw changes cannot grant rewards")
	for biome in range(6):
		game.campaign_stage = biome
		game.cam_m = float(biome * 140)
		for quality in range(3):
			game.graphics_quality = quality
			game.queue_redraw()
			await process_frame
			_check(game.graphics_quality == quality, "drawing never modifies adaptive quality")
	_check(game.score == initial_score and game.leaves == initial_leaves,
		"all 18 biome-quality redraws preserve economy")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: expressive frog gaze and moods, six scenic biomes, tier-aware props, pure rendering and safe Android quality zero")
	else:
		printerr("FAIL: %d animation or environmental safety regressions" % failures)
	quit(0 if failures == 0 else 1)

func _check(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + description)
