extends SceneTree
## Input ownership and reachable procedural platform regressions.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._reset_game()
	game.mode = 1
	var primary := InputEventScreenTouch.new()
	primary.index = 0
	primary.pressed = true
	primary.position = Vector2(270, 675)
	game._input(primary)
	_check(game.mode == 2 and game._active_touch_index == 0, "first finger owns aim")
	var secondary := InputEventScreenTouch.new()
	secondary.index = 1
	secondary.pressed = true
	secondary.position = Vector2(120, 430)
	game._input(secondary)
	_check(game.mode == 2 and game._active_touch_index == 0, "secondary touch cannot steal aim")
	var bad_drag := InputEventScreenDrag.new()
	bad_drag.index = 1
	bad_drag.position = Vector2(100, 860)
	game._input(bad_drag)
	_check(game.aim_m == game.player_m, "secondary drag cannot change trajectory")
	secondary.pressed = false
	game._input(secondary)
	_check(game.mode == 2 and game._active_touch_index == 0, "secondary release cannot cancel aim")
	var good_drag := InputEventScreenDrag.new()
	good_drag.index = 0
	good_drag.position = Vector2(270, 820)
	game._input(good_drag)
	_check(game.aim_m > game.player_m + 3.0, "primary drag updates aim")
	primary.pressed = false
	primary.position = Vector2(270, 820)
	game._input(primary)
	_check(game.mode == 3 and game._active_touch_index == -1, "primary release alone launches jump")
	game._pause_game()
	_check(game.mode == 5 and game._active_touch_index == -1, "interruption clears touch ownership")
	game._reset_game()
	_check(game._active_touch_index == -1, "reset clears touch ownership")

	# Analytic drag reachability is grounded in the game's exact drag rules:
	# horizontal input = pixel displacement / 1.2, vertical input =
	# 8 pixels/metre / 1.35, with a maximum 215 px gesture.
	game.chapters.unlocked_count = 6
	for biome in range(6):
		game._start_chapter(biome)
		for section in range(13):
			game.player_m = float(section * 190)
			game._generate_pads()
		var previous: Dictionary = game.pads[0]
		for pad in game.pads:
			if int(pad["id"]) == 0:
				continue
			# Only mandatory lilies form a linear sequence. The alternative
			# detour sits at the same river height, and has an independent
			# strict two-sided reachability regression in biome_forks.gd.
			if bool(pad.get("biome_fork", false)):
				_check(float(pad["r"]) >= 34.0, "optional skill platform has a visible hitbox")
				continue
			var dx := absf(float(pad["x"]) - float(previous["x"])) / 1.2
			var dy := (float(pad["m"]) - float(previous["m"])) * 8.0 / 1.35
			_check(Vector2(dx, dy).length() <= 215.0, "biome %d mandatory lily is reachable by a real gesture" % biome)
			_check(float(pad["r"]) >= 37.0, "biome %d lily remains a readable collision target" % biome)
			previous = pad
		_check(game.pads.size() > 60, "biome %d generates long courses" % biome)
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: multitouch ownership, pause safety and all six-biome procedural fairness")
	else:
		printerr("FAIL: input/fairness regressions %d" % failures)
	quit(0 if failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
