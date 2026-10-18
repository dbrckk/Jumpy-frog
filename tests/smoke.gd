extends SceneTree

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	_assert(scene.mode == 0, "title mode")
	_assert(scene.pads.size() >= 4, "generated platforms")
	_assert(scene.pads[0]["m"] == 0.0, "spawn platform")

	var first: Dictionary = scene.pads[1]
	scene.mode = 1
	scene.aim_x = first["x"]
	scene.aim_m = first["m"]
	scene._start_jump()
	_assert(scene.mode == 3, "jump started")
	_assert(scene.jump_pad_id == first["id"], "magnetic platform landing chosen")
	for i in range(75):
		scene._process(0.02)
	_assert(scene.mode == 1, "landed on lily pad")
	_assert(absf(scene.player_m - float(first["m"])) < 0.01, "forward progress")
	_assert(scene.score > 0, "landing earns points")

	scene.aim_x = 270.0
	scene.aim_m = scene.player_m + 99.0
	scene._start_jump()
	_assert(scene.jump_pad_id == -1, "water target is unsafe")
	for i in range(75):
		scene._process(0.02)
	_assert(scene.mode == 4, "missing pad ends the run")

	scene._reset_game()
	_assert(scene.mode == 0 and scene.score == 0, "retry resets the run")
	_assert(scene.pads.size() >= 4, "retry regenerates platforms")
	print("PASS: spawn, hop, collision, scoring, water loss, retry")
	scene.queue_free()
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		quit(1)
