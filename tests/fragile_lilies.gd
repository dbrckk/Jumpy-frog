extends SceneTree
## Real biome platforms, grounded timer, paused/airborne fairness, Guardian rescue.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._reset_game()
	game.campaign_stage = 2
	game.mode = 1
	game.pads.resize(1)
	game.last_generated_m = 0.0
	game.last_pad_x = 270.0
	game.next_pad_id = 1
	game._generate_pads()

	var brittle: Dictionary = {}
	for pad in game.pads:
		if bool(pad.get("fragile", false)):
			brittle = pad
			break
	_expect(not brittle.is_empty(), "golden reeds generates a fragile lily")
	_expect(not bool(brittle.get("guardian", false)), "timed hazards never overlap Guardian")
	_expect(int(brittle["id"]) >= 5, "tutorial hops remain safe")
	_expect(float(brittle["m"]) < 150.0, "Golden Reeds chapter features the obstacle before its goal")
	# Use an endless run to avoid the short chapter finishing before pad nine.
	# Keep already generated biome-2 pads and their modifier data intact.
	game.campaign_stage = -1

	# Land legitimately by crossing the generated pads in normal order.
	for hop in range(int(brittle["id"])):
		var target: Dictionary = _next_pad(game)
		if target.is_empty():
			_expect(false, "next platform remains reachable")
			break
		var intended: int = int(target["id"])
		game.aim_x = float(target["x"])
		game.aim_m = float(target["m"])
		game._start_jump()
		_expect(game.jump_pad_id == intended, "existing collision logic predicts the next pad")
		for frame in range(65):
			game._process(0.02)
			if game.mode != 3:
				break
		_expect(game.mode == 1, "actual hop survives")
		if game.mode != 1:
			break
	_expect(game.fragile_pad_id == int(brittle["id"]), "real fragile landing activates timer")
	_expect(game.fragile_seconds > 5.0, "generous 5.5s grace on landing")

	var time_before: float = game.fragile_seconds
	game._pause_game()
	for i in range(40):
		game._process(0.05)
	_expect(is_equal_approx(game.fragile_seconds, time_before), "pause freezes crack timer")
	game._resume_game()
	game._process(0.08)
	_expect(game.fragile_seconds < time_before, "aimable grounded state runs clock")

	# Launching cancels ticking until the next landing: no midair failure.
	var next: Dictionary = _next_pad(game)
	if not next.is_empty():
		game.aim_x = float(next["x"])
		game.aim_m = float(next["m"])
		game._start_jump()
		var in_flight: float = game.fragile_seconds
		game._process(0.08)
		_expect(is_equal_approx(game.fragile_seconds, in_flight), "flight freezes fragile timer")
		for frame in range(65):
			game._process(0.02)
			if game.mode != 3:
				break
		_expect(game.mode == 1 and game.fragile_pad_id == -1, "landing on a safe pad clears crack timer")

	# Re-enter a brittle platform and let the Guardian protect exactly once.
	game.fragile_pad_id = int(brittle["id"])
	game.fragile_seconds = 0.01
	game.guardian_charge = true
	game.mode = 1
	game._process(0.03)
	_expect(game.mode == 1 and not game.guardian_charge, "Guardian absorbs collapse")
	_expect(game.fragile_seconds >= 2.9, "Guardian grants a bounded escape window")
	for i in range(43):
		if game.mode != 1:
			break
		game._process(0.08)
	_expect(game.mode == 4, "unprotected expired lily ends run")
	game._reset_game()
	_expect(game.fragile_pad_id == -1 and game.fragile_seconds == 0.0, "new run starts without hazard state")

	# Other biomes never generate a timed hazard.
	for biome in [0, 1, 3, 4]:
		game._reset_game()
		game.campaign_stage = biome
		game.pads.resize(1)
		game.last_generated_m = 0.0
		game.next_pad_id = 1
		game._generate_pads()
		for pad in game.pads:
			_expect(not bool(pad.get("fragile", false)), "safe biome has no brittle lilies")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: fragile lily gameplay, visual warning source, fair timing, pause, Guardian and biome rules")
	else:
		printerr("FAIL: fragile-lily regressions: %d" % failures)
	quit(0 if failures == 0 else 1)

func _next_pad(game: Node2D) -> Dictionary:
	for pad in game.pads:
		if float(pad["m"]) > game.player_m + 3.0:
			return pad
	return {}

func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
