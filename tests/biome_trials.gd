extends SceneTree
## Optional chapter skill trials must be real landings, safe and non-farmable.
const TRIALS = preload("res://scripts/biome_trials.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _hop(game: Node2D, pad: Dictionary, x_offset: float = 0.0) -> void:
	game.aim_m = float(pad["m"])
	game.aim_x = game._predicted_pad_x(pad) + x_offset
	game._start_jump()
	_check(game.jump_pad_id == int(pad["id"]), "real launch selects the intended target")
	for tick in range(70):
		game._process(0.02)
		if game.mode != game.MODE_FLY:
			break
	_check(game.mode == game.MODE_PLAY or game.mode == game.MODE_CLEAR,
		"legitimate trial jump ends on the pad, not in water")

func _run() -> void:
	_check(TRIALS.NAMES.size() == 6 and TRIALS.PERIOD == 6,
		"all six environments have predictable precision objectives")
	_check(not TRIALS.eligible(3, -1, false, false, false, false, false),
		"tutorial hops remain free of trials")
	_check(TRIALS.eligible(4, -1, false, false, false, false, false),
		"first opportunity appears on fourth primary pad")
	for excluded in range(5):
		var flags := [false, false, false, false, false]
		flags[excluded] = true
		_check(not TRIALS.eligible(4, -1, flags[0], flags[1], flags[2], flags[3], flags[4]),
			"trial cannot overlap hazards, moving pads, harmony, fragile or guardian")
	_check(not TRIALS.eligible(4, 0, false, false, false, false, false),
		"Firefly Festival never gains an extra skill penalty")
	_check(TRIALS.reward(-1).is_empty() and TRIALS.reward(6).is_empty(),
		"invalid biomes never grant bonuses")
	var reward_names := {}
	for biome in range(6):
		var reward: Dictionary = TRIALS.reward(biome)
		reward_names[reward["name"]] = true
		_check(int(reward["score"]) > 0 and not reward.has("leaves"),
			"challenge rewards are meaningful but never mint persistent leaves")
		_check(float(reward["wave_relief"]) >= 0 and float(reward["flow_seconds"]) >= 0,
			"skill effects never secretly increase wave pressure")
	_check(reward_names.size() == 6, "six recognizable mechanic rewards")
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.chapters.unlocked_count = 6
	for biome in range(6):
		game._start_chapter(biome)
		var original_course: Array = []
		for pad in game.pads:
			original_course.append([pad["id"], pad["x"], pad["m"], pad["r"]])
		var opportunity: Dictionary = {}
		for pad in game.pads:
			if int(pad["id"]) == 4:
				opportunity = pad
				break
		_check(not opportunity.is_empty() and bool(opportunity.get("trial", false)),
			"every chapter provides an early, visible optional trial")
		_check(int(opportunity.get("trial_biome", -1)) == biome,
			"trial effects reflect the river's biome")
		for ident in range(1, 5):
			var landing: Dictionary = {}
			for pad in game.pads:
				if int(pad["id"]) == ident:
					landing = pad
					break
			_check(not landing.is_empty(), "sequential main route retains all platforms")
			if landing.is_empty():
				break
			_hop(game, landing)
			if game.mode != game.MODE_PLAY:
				break
		_check(game.run_hops >= 4 and game.run_perfects >= 4,
			"real perfectly aimed hops complete trial without bypassing collisions")
		_check(not bool(opportunity.get("trial", true)),
			"success consumes trial on the pad itself")
		var marker := false
		for msg in game.float_texts:
			if String(msg["text"]).contains(String(TRIALS.NAMES[biome])):
				marker = true
		_check(marker, "each biome announces its own reward on landing")
		var still_generated: Array = []
		for pad in game.pads:
			if int(pad["id"]) <= 4:
				still_generated.append([pad["id"], pad["x"], pad["m"], pad["r"]])
		var expected: Array = []
		for record in original_course:
			if int(record[0]) <= 4:
				expected.append(record)
		_check(still_generated == expected or game.cam_m > 75.0,
			"trials leave main route geometry unchanged")
	# An imprecise yet safe arrival consumes the optional skill marker with no reward.
	game._start_chapter(0)
	for ident in range(1, 5):
		var pad: Dictionary = {}
		for item in game.pads:
			if int(item["id"]) == ident:
				pad = item
				break
		if pad.is_empty():
			break
		_hop(game, pad, float(pad["r"]) * 0.45 if ident == 4 else 0.0)
		if game.mode != game.MODE_PLAY:
			break
	_check(game.run_hops >= 4 and game.run_perfects == 3,
		"safe edge landing does not accidentally earn a perfect")
	var consumed := true
	for pad in game.pads:
		if int(pad["id"]) == 4:
			consumed = not bool(pad.get("trial", true))
	_check(consumed, "failed skill trial is also consumed, preventing repeat farming")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: six biome-specific trials, authentic landings, reward economy, anti-farming and fair collision")
	else:
		printerr("FAIL: biome trial checks %d" % failures)
	quit(0 if failures == 0 else 1)
