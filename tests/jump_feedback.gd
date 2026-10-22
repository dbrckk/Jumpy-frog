extends SceneTree
## Touch aim affordances must be truthful, safe and inexpensive on Android.
const FEEDBACK = preload("res://scripts/jump_feedback.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_exercise")

func _exercise() -> void:
	_check(is_equal_approx(FEEDBACK.windup(0.0, 0.0), 0.0), "zero pull leaves frog standing")
	_check(is_equal_approx(FEEDBACK.windup(11.5, 0.0), 0.5), "half pull compresses frog halfway")
	_check(is_equal_approx(FEEDBACK.windup(50.0, 0.0), 1.0), "large pull caps windup")
	_check(is_equal_approx(FEEDBACK.windup(-5.0, 0.0), 0.0), "pull in wrong direction never compresses")
	var sample := {"m": 16.0, "r": 50.0}
	_check(FEEDBACK.is_perfect(sample, 270.0, 16.0, 270.0, 8.0), "center touch gives perfect")
	_check(FEEDBACK.is_perfect(sample, 283.0, 16.0, 270.0, 8.0), "interior near-center gives perfect")
	_check(not FEEDBACK.is_perfect(sample, 285.0, 16.0, 270.0, 8.0), "edge touch is safe but not perfect")
	_check(not FEEDBACK.is_perfect(sample, 270.0, 19.0, 270.0, 8.0), "long miss is not perfect")
	_check(not FEEDBACK.is_perfect({}, 270.0, 16.0, 270.0, 8.0), "empty target never scores")

	var captions: Array = []
	for i in range(8):
		var pos: Vector2 = FEEDBACK.place_message(Vector2(270, 610), captions)
		for previous in captions:
			var old: Vector2 = previous["pos"]
			_check(absf(old.y - pos.y) >= 32.0, "at most eight reward captions have independent vertical lanes")
		_check(pos.y >= 175.0 and pos.y <= 850.0, "reward text remains within game viewport")
		captions.append({"pos": pos, "life": 1.0})
	var expired: Array = [{"pos": Vector2(270, 610), "life": 0.02}]
	_check(FEEDBACK.place_message(Vector2(270, 610), expired) == Vector2(270, 610),
		"expired rewards cannot block new captions")
	_check(FEEDBACK.place_message(Vector2(270, 610), []) == Vector2(270, 610),
		"one reward preserves original placement")

	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._reset_game()
	game.mode = game.MODE_PLAY
	var first: Dictionary = game.pads[1]
	_check(not first.is_empty(), "generated first lily exists")
	game.aim_x = game._predicted_pad_x(first)
	game.aim_m = float(first["m"])
	var preview_pad: Dictionary = game._landing_target(game.aim_x, game.aim_m)
	_check(int(preview_pad.get("id", -1)) == int(first["id"]), "aim guide selects same lily as launch")
	var preview_perfect: bool = FEEDBACK.is_perfect(preview_pad, game.aim_x, game.aim_m, game._predicted_pad_x(preview_pad), 8.0)
	_check(preview_perfect, "precise touch preview shows gold grade")
	var rp: int = game.ripples.size()
	var particles: int = game.particles.size()
	game._start_jump()
	_check(game.jump_is_perfect == preview_perfect, "gold live preview and launched jump grade agree")
	_check(game.jump_pad_id == int(preview_pad["id"]), "perfect cue guarantees chosen lily by shared resolver")
	_check(game.ripples.size() == rp + 1, "launch creates exactly one small takeoff ripple")
	_check(game.particles.size() > particles and game.particles.size() <= 110, "takeoff sparks obey bounded pool")
	for frame in range(65):
		game._process(0.02)
		if game.mode != game.MODE_FLY:
			break
	_check(game.mode == game.MODE_PLAY, "actual leap lands")
	_check(game.run_perfects == 1 and game.perfect_streak == 1, "actual perfect credit equals preview")
	_check(game.particles.size() <= 110 and game.ripples.size() <= 12, "VFX pools remain bounded")

	# A normal valid but off-center landing must not promise a perfect.
	var next: Dictionary = {}
	for pad in game.pads:
		if float(pad["m"]) > game.player_m + 3.0:
			next = pad
			break
	_check(not next.is_empty(), "second lily present")
	var proposed_x: float = game._predicted_pad_x(next) + float(next["r"]) * 0.40
	game.aim_x = proposed_x
	game.aim_m = float(next["m"])
	var safe: Dictionary = game._landing_target(proposed_x, game.aim_m)
	_check(int(safe.get("id",-1)) == int(next["id"]), "off-center guide remains safe")
	var grade: bool = FEEDBACK.is_perfect(safe, game.aim_x, game.aim_m, game._predicted_pad_x(safe), 8.0)
	_check(not grade, "valid edge landing displays green, not gold")
	game._start_jump()
	_check(not game.jump_is_perfect, "launched edge leap never yields an accidental perfect")

	# Graphic quality changes affect only optional particles, never grade.
	game._reset_game()
	game.mode = game.MODE_PLAY
	game.graphics_quality = 0
	first = game.pads[1]
	game.aim_x = float(first["x"])
	game.aim_m = float(first["m"])
	particles = game.particles.size()
	game._start_jump()
	_check(game.jump_is_perfect and game.particles.size() == particles,
		"tier zero retains scoring while avoiding decorative takeoff particles")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: accurate perfect prediction, visual crouch, launch ripple, capped effects, independent reward captions and tier-zero scoring")
	else:
		printerr("FAIL: %d landing feel assertions" % failures)
	quit(0 if failures == 0 else 1)

func _check(valid: bool, detail: String) -> void:
	if not valid:
		failures += 1
		push_error("FAIL: " + detail)
