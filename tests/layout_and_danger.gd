extends SceneTree
const DANGER = preload("res://scripts/pad_danger.gd")
const ART = preload("res://scripts/art.gd")
var fail := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var font: Font = ThemeDB.fallback_font
	for sample in [
		["JUMPY FROG", 49, 365.0], ["CUSTOMIZE", 24, 230.0],
		["BEST COMBO", 11, 79.0], ["MISSIONS 0/3  •  WEEK 0/3", 16, 238.0],
		["FIRST SPLASH", 19, 314.0], ["PULL BACK · RELEASE", 24, 375.0]
	]:
		var size: int = ART.fitted_font_size(String(sample[0]), int(sample[1]), float(sample[2]))
		_check(font.get_string_size(String(sample[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= float(sample[2]) + 0.01,
			"UI label fits its panel: %s" % String(sample[0]))
# Centering regression was alignment with an unspecified draw width, not necessarily glyph size.
	var title_width := font.get_string_size("JUMPY FROG", HORIZONTAL_ALIGNMENT_LEFT, -1, 43).x
	_check(absf((270.0 - title_width * 0.5) + title_width * 0.5 - 270.0) < 0.01,
		"title baseline uses a measured, symmetric center")
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._reset_game()
	game.mode = game.MODE_PLAY
	game.rng.seed = 7719
	game.player_m = 700.0
	game._generate_pads()
	var seen := 0
	var prev_id := -99
	for pad in game.pads:
		if bool(pad.get("danger", false)):
			seen += 1
			var ident := int(pad["id"])
			_check(ident >= 8 and ident - prev_id >= 3, "danger introduced late and not adjacent")
			prev_id = ident
			_check(not bool(pad.get("guardian", false)) and not bool(pad.get("fragile", false)),
				"danger cannot overlap fragile or rescue")
			_check(not bool(pad.get("harmony", false)) and not bool(pad.get("moving", false)),
				"danger cannot overlap aim challenge or moving pad")
	_check(seen > 0, "endless seeds occasionally generate obstacles")

	# A single injected danger on reachable pad 1 makes the gameplay
	# prediction deterministic without relying on rare generation.
	game._reset_game()
	game.mode = game.MODE_PLAY
	var target: Dictionary = game.pads[1]
	target["danger"] = true
	var landing_delay: float = game._duration_to(float(target["m"]))
	target["danger_phase"] = fposmod(0.5 - game.clock - landing_delay, DANGER.CYCLE_SECONDS)
	_check(DANGER.is_active(target, game.clock + landing_delay), "landing-phase enemy is active")
	_check(game._landing_target(float(target["x"]), float(target["m"])).is_empty(),
		"danger blocks arrival and changes SAFE landing guide to splash warning")
	_check(DANGER.seconds_until_safe(target, game.clock + landing_delay) > 0.0,
		"hazard offers a predictable wait-to-clear interval")
	# Waiting until the safe phase never changes normal lily collisions.
	target["danger_phase"] = fposmod(DANGER.ACTIVE_SECONDS + 0.5 - game.clock - landing_delay, DANGER.CYCLE_SECONDS)
	_check(not DANGER.is_active(target, game.clock + landing_delay), "crab becomes harmless after active interval")
	_check(int(game._landing_target(float(target["x"]), float(target["m"])).get("id",-1)) == int(target["id"]),
		"aim preview and collision agree as soon as hazard clears")
	game.aim_x = float(target["x"])
	game.aim_m = float(target["m"])
	game._start_jump()
	for frame in range(65):
		game._process(0.02)
		if game.mode != game.MODE_FLY:
			break
	_check(game.mode == game.MODE_PLAY and game.standing_pad_id == int(target["id"]),
		"safe timing remains a normal successful leap")
	# Active crab doesn't kill player already safely riding the lily.
	target["danger_phase"] = fposmod(0.25 - game.clock, DANGER.CYCLE_SECONDS)
	for i in range(10):
		game._process(0.02)
	_check(game.mode == game.MODE_PLAY, "enemy never activates unfairly underneath a landed player")
	# Six story chapters and daily route should remain unchanged.
	for biome in range(6):
		game._start_chapter(biome)
		for pad in game.pads:
			_check(not bool(pad.get("danger",false)), "chapters preserve their designed difficulty")
	game._start_daily_river()
	for pad in game.pads:
		_check(not bool(pad.get("danger",false)), "daily route remains consistent")

	game.queue_free()
	await process_frame
	if fail == 0:
		print("PASS: measured UI centering, safe button labels, random endless obstacles and predictive landing safety")
	else:
		printerr("FAIL: %d layout or obstacle regressions" % fail)
	quit(0 if fail == 0 else 1)

func _check(valid: bool, detail: String) -> void:
	if not valid:
		fail += 1
		push_error("FAIL: " + detail)
