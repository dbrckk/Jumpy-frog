extends SceneTree
## Shared deterministic moving pad prediction, rendering invariance and fairness.
const MOTION = preload("res://scripts/platform_motion.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_exercise")

func _exercise() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.chapters.unlocked_count = 6
	for biome in range(6):
		game._start_chapter(biome)
		var movers: Array[Dictionary] = []
		for pad in game.pads:
			if bool(pad.get("moving", false)):
				movers.append(pad)
				_expect(not bool(pad.get("guardian", false)), "moving pads never overlap Guardians")
				_expect(not bool(pad.get("fragile", false)), "moving pads never overlap fragile hazards")
				_expect(int(pad["id"]) >= 5, "introductory jumps stay static")
			if biome not in [3, 4]:
				_expect(not bool(pad.get("moving", false)) or bool(pad.get("biome_fork", false)),
					"mandatory platforms in other biomes remain stable")
		if biome in [3, 4]:
			_expect(movers.size() >= 1, "moonlit and crystal chapters introduce moving lilies")
			if movers.is_empty():
				continue
			var mover: Dictionary = movers[0]
			var at_zero: float = MOTION.x_at(mover, 0.0)
			var at_later: float = MOTION.x_at(mover, 0.8)
			_expect(absf(at_zero - at_later) > 1.0, "platform moves visibly over time")
			for frame in range(120):
				var x: float = MOTION.x_at(mover, frame * 0.13)
				_expect(x >= 92.0 and x <= 448.0, "all moving pads remain within bounds")
			var duration: float = game._duration_to(float(mover["m"]))
			_expect(is_equal_approx(game._predicted_pad_x(mover), MOTION.x_at(mover, game.clock + duration)),
				"touch preview is exactly shared with platform motion function")
			var predicted: float = game._predicted_pad_x(mover)
			game.aim_x = predicted
			game.aim_m = float(mover["m"])
			_expect(int(game._landing_target(predicted, float(mover["m"])).get("id", -1)) == int(mover["id"]),
				"preview targets expected moving lily")
			game._start_jump()
			_expect(game.jump_pad_id == int(mover["id"]), "launch selects predicted moving lily")
			_expect(absf(game.jump_end.x - predicted) < 0.001, "jump aims for future platform center")
			for frame in range(65):
				game._process(0.02)
				if game.mode != 3:
					break
			_expect(game.mode == 1 and game.standing_pad_id == int(mover["id"]), "predicted landing succeeds")
			_expect(absf(game.player_x - MOTION.x_at(mover, game.clock)) < 0.01, "landing exactly matches drawn pad")
			var prior: float = game.player_x
			game._process(0.10)
			_expect(absf(game.player_x - prior) > 0.1, "frog rides current platform")
			_expect(absf(game.player_x - MOTION.x_at(mover, game.clock)) < 0.01, "frog stays centered after time passes")
			game._pause_game()
			var pause_x: float = game.player_x
			var pause_clock: float = game.clock
			for frame in range(8):
				game._process(0.1)
			_expect(is_equal_approx(game.player_x, pause_x) and is_equal_approx(game.clock, pause_clock),
				"pausing freezes player and platform")
			game._resume_game()
			game.graphics_quality = 0
			game._process(0.05)
			_expect(absf(game.player_x - MOTION.x_at(mover, game.clock)) < 0.01,
				"lowest graphics tier never changes collision or platform travel")
		game._reset_game()
		_expect(game.standing_pad_id == 0, "next game always starts on static initial platform")
	# Validate motion amplitude never pushes two consecutive pads beyond drag capability.
	for biome in [3, 4]:
		game._start_chapter(biome)
		game.player_m = 500.0
		game._generate_pads()
		var previous: Dictionary = game.pads[0]
		for pad in game.pads:
			if int(pad["id"]) == 0:
				continue
			var max_span: float = absf(float(pad["x"]) - float(previous["x"]))
			max_span += float(pad.get("motion_amplitude", 0)) if bool(pad.get("moving", false)) else 0.0
			max_span += float(previous.get("motion_amplitude", 0)) if bool(previous.get("moving", false)) else 0.0
			var dx: float = max_span / 1.2
			var dy: float = (float(pad["m"]) - float(previous["m"])) * 8.0 / 1.35
			_expect(Vector2(dx, dy).length() <= 215.0, "even worst-phase lateral travel is a reachable gesture")
			previous = pad
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: real moving lily prediction, fair reachability, riding, pause and graphics tiers")
	else:
		printerr("FAIL: %d moving-lily regressions" % failures)
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
