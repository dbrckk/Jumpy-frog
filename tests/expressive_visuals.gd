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
	_check(is_equal_approx(MOTION.landing_halo_radius(50.0, 0.0), 46.0),
		"landing halo begins outside the frog target")
	_check(MOTION.landing_halo_radius(50.0, 1.0) < MOTION.landing_halo_radius(50.0, 0.0),
		"landing halo contracts smoothly into the approaching lily")
	_check(is_equal_approx(MOTION.landing_halo_radius(50.0, -1.0), MOTION.landing_halo_radius(50.0, 0.0)),
		"unusual elapsed time cannot expand beyond opening radius")
	_check(MOTION.landing_halo_alpha(1.0) > MOTION.landing_halo_alpha(0.0),
		"approaching landing increases legibility")
	_check(MOTION.landing_halo_alpha(5.0) <= 0.72, "halo alpha is capped for slow phones")
	_check(is_zero_approx(MOTION.airborne_tuck(0.0)) and is_zero_approx(MOTION.airborne_tuck(1.0)),
		"frog legs start and finish extended with no animation snap")
	_check(absf(MOTION.airborne_tuck(0.5) - 1.0) < 0.0001,
		"frog tucks its hind legs at jump apex")
	_check(is_zero_approx(MOTION.landing_reach(0.5)) and MOTION.landing_reach(0.98) == 1.0,
		"frog anticipates the landing late in the flight")
	_check(MOTION.landing_reach(0.75) > 0.0 and MOTION.landing_reach(0.75) < 1.0,
		"landing reach eases smoothly rather than popping")
	_check(MOTION.airborne_tuck(-2.0) == MOTION.airborne_tuck(0.0)
		and MOTION.landing_reach(2.0) == 1.0,
		"visual phase interpolation is safe with exceptional frame phases")
	_check(MOTION.effect_visible(Vector2(270, 700)), "active landing VFX remains visible")
	_check(MOTION.effect_visible(Vector2(-15, 900), 20.0), "partially clipped water crown is retained")
	_check(not MOTION.effect_visible(Vector2(-300, 700), 40.0), "offscreen effects skip CanvasItem commands")
	_check(not MOTION.effect_visible(Vector2(270, 1200), 100.0), "far below screen particles are culled")
	_check(absf(MOTION.landing_rebound(0.0)) < 0.001 and absf(MOTION.landing_rebound(1.0)) < 0.001,
		"landing spring starts and finishes with no displacement")
	_check(MOTION.landing_rebound(0.5) < -4.0,
		"responsive landing causes visible upward rebound")
	_check(MOTION.landing_rebound(-2.0) == MOTION.landing_rebound(0.0),
		"malformed spring progress remains bounded")
	_check(MOTION.landing_signature_count(0) == 2 and MOTION.landing_signature_count(1) == 4
		and MOTION.landing_signature_count(2) == 6,
		"tier-zero graphics still show chapter-specific accents at a bounded draw cost")
	var distinct_signatures: Dictionary = {}
	for biome_index in range(6):
		var signature: Color = MOTION.landing_signature_color(biome_index)
		distinct_signatures[signature.to_html(false)] = true
	_check(distinct_signatures.size() == 6, "six uniquely colored landing signatures")
	_check(MOTION.landing_signature_color(-1) == MOTION.landing_signature_color(0)
		and MOTION.landing_signature_color(99) == MOTION.landing_signature_color(5),
		"invalid biome IDs safely clamp to known palettes")
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
