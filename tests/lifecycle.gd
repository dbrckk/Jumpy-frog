extends SceneTree
## Android lifecycle: backgrounding during a flight must not cause a lost jump.
var failures := 0

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	_check(game.android_tones_enabled == false or OS.has_feature("android"), "native system tones opt-in only")
	if not OS.has_feature("android"):
		_check(not game.sound.set_android_system_tones(true), "desktop never tries Android Java audio")
		_check(not game.sound.android_system_tones, "desktop cannot enable system tones")

	game.mode = 1
	var pad: Dictionary = game.pads[1]
	game.aim_x = pad["x"]
	game.aim_m = pad["m"]
	game._start_jump()
	_check(game.mode == 3, "real flight started")
	game._process(0.07)
	var time_at_pause: float = game.jump_elapsed
	var m_at_pause: float = game.player_m
	var wave_at_pause: float = game.wave_m
	game._notification(NOTIFICATION_APPLICATION_PAUSED)
	_check(game.mode == 5, "app paused becomes safe gameplay pause")
	_check(game.resume_mode == 3, "midflight resume state remains flight")
	_check(game.sound.paused, "app pause suspends audio")
	game._process(0.12)
	_check(is_equal_approx(game.jump_elapsed, time_at_pause), "flight does not advance in background")
	_check(is_equal_approx(game.player_m, m_at_pause), "player does not move while paused")
	_check(is_equal_approx(game.wave_m, wave_at_pause), "chase wave does not advance while paused")
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(game.resume_mode == 3, "repeated focus event preserves resume state")
	game._resume_game()
	_check(game.mode == 3, "midflight resumes instead of teleporting to pad")
	_check(not game.sound.paused, "resume restores audio state")

	for frame in range(65):
		game._process(0.02)
		if game.mode != 3:
			break
	_check(game.mode == 1, "resumed flight lands normally")
	_check(game.player_m > 0.0 and game.score > 0, "resumed flight awards normal progress")

	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(game.mode == 5 and game.resume_mode == 1, "grounded game pauses on app focus loss")
	game._resume_game()
	_check(game.mode == 1, "grounded game resumes normally")
	game._notification(NOTIFICATION_APPLICATION_PAUSED)
	_check(game.mode == 5, "second pause remains safe")
	game._reset_game()
	_check(game.mode == 0, "reset from paused returns to title")
	_check(not game.sound.paused, "new game clears paused audio state")

	var save := ConfigFile.new()
	_check(save.load("user://jumpy_frog.cfg") == OK, "backgrounded gameplay was saved")
	_check(save.has_section_key("progress", "android_system_tones"), "native Android audio preference is stored")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: optional Android system tones, safe background pause, midflight resume and persistent progress")
	else:
		printerr("FAILED lifecycle assertions: %d" % failures)
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
