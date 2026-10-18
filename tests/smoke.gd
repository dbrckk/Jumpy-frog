extends SceneTree
## Exit code 1 on *any* failed assertion; CI must never report a false pass.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var scene: Node2D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	_check(scene.mode == 0, "opens on the title screen")
	_check(scene.pads.size() >= 4, "generates platforms")
	_check(scene.pads[0]["m"] == 0.0, "starts on a lily")
	
	var first: Dictionary = scene.pads[1]
	var predicted: Dictionary = scene._landing_target(float(first["x"]), float(first["m"]))
	_check(not predicted.is_empty() and int(predicted.get("id", -1)) == int(first["id"]), "landing preview predicts actual platform")
	_check(scene._landing_target(70.0, 2000.0).is_empty(), "empty water is marked unsafe")
	
	# A direct hop reproduces a future touch release and tests score/collision.
	scene.mode = 1
	scene.aim_x = first["x"]
	scene.aim_m = first["m"]
	scene._start_jump()
	_check(scene.mode == 3, "starts a hop")
	_check(scene.jump_pad_id == first["id"], "flight uses same preview target")
	for i in range(75):
		scene._process(0.02)
	_check(scene.mode == 1, "lands on lily")
	_check(absf(scene.player_m - float(first["m"])) < 0.01, "player moves forward")
	_check(scene.score > 0, "landing earns score")
	
	scene.aim_x = 270.0
	scene.aim_m = scene.player_m + 3000.0
	scene._start_jump()
	_check(scene.jump_pad_id == -1, "missing platform predicts splash")
	for i in range(75):
		scene._process(0.02)
	_check(scene.mode == 4, "missing platform ends run")
	
	scene._reset_game()
	scene.mode = 1
	scene._down(Vector2(494, 99))
	_check(scene.mode == 5, "pause button suspends")
	var pause_wave: float = scene.wave_m
	scene._process(1.0)
	_check(scene.wave_m == pause_wave, "pause freezes wave")
	var previous_mute: bool = scene.muted
	scene._down(Vector2(260, 575))
	_check(scene.muted != previous_mute, "sound setting works")
	scene._down(Vector2(260, 490))
	_check(scene.mode == 1, "resume returns to play")
	
	# Real swipe: pull down and sideways to land on the first lily.
	scene._reset_game()
	scene.mode = 1
	var next_pad: Dictionary = scene.pads[1]
	var down := Vector2(250, 410)
	var swipe := Vector2(
		(scene.player_x - float(next_pad["x"])) / 1.2,
		(float(next_pad["m"]) - scene.player_m) * 8.0 / 1.35
	)
	scene._down(down)
	scene._move(down + swipe)
	_check(scene.mode == 2, "starts gesture aim")
	_check(not scene._landing_target(scene.aim_x, scene.aim_m).is_empty(), "gesture predicts a valid landing")
	scene._up(down + swipe)
	_check(scene.mode == 3 and scene.jump_pad_id == int(next_pad["id"]), "release launches predicted target")
	for i in range(75):
		scene._process(0.02)
	_check(scene.mode == 1, "touch gesture lands correctly")
	
	# Generated runs must never demand a physically impossible next jump.
	for seed_index in range(64):
		scene.rng.seed = seed_index * 173 + 11
		scene._reset_game()
		for index in range(1, scene.pads.size()):
			var prev: Dictionary = scene.pads[index - 1]
			var curr: Dictionary = scene.pads[index]
			var dx: float = (float(curr["x"]) - float(prev["x"])) / 1.2
			var dy: float = (float(curr["m"]) - float(prev["m"])) * 8.0 / 1.35
			_check(Vector2(dx, dy).length() <= 215.0, "random platform gap reachable")
	
	# Animation state must respond to jumping/landing and reset predictably.
	scene._reset_game()
	scene.mode = 1
	var animate_pad: Dictionary = scene.pads[1]
	scene.aim_x = animate_pad["x"]
	scene.aim_m = animate_pad["m"]
	scene._start_jump()
	_check(scene.body_squash > 0.2, "takeoff squash activated")
	for frame in range(75):
		scene._process(0.02)
	_check(scene.landing_impact > 0.0, "landing triggers impact animation")
	scene._reset_game()
	_check(scene.body_tilt == 0.0 and scene.stack_sway == 0.0 and scene.landing_impact == 0.0, "animation reset")
	_check(scene.mode == 0 and scene.score == 0, "retry resets run")
	_check(scene.pads.size() >= 4, "retry generates platforms")
	if failures == 0:
		print("PASS: spawning, prediction, gestures, collision, score, splash, pause, audio, 64 generated runs, retry")
	else:
		printerr("FAILED: %d gameplay assertions" % failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
