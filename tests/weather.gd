extends SceneTree
## Weather must look different yet never influence gameplay, seeds or the economy.
const WEATHER = preload("res://scripts/weather.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	_check(WEATHER.TYPES == 6, "six distinct day/cloud/rain/wind/night presets")
	_check(WEATHER.raindrop_budget(0) < WEATHER.raindrop_budget(1) and
		WEATHER.raindrop_budget(1) < WEATHER.raindrop_budget(2),
		"rain drawing budgets respect mobile rendering tiers")
	_check(WEATHER.gust_budget(0) < WEATHER.gust_budget(2),
		"low-end phones avoid unnecessary wind streak commands")
	var unique := {}
	for index in range(18):
		var distance: float = (float(index) + 0.5) * WEATHER.FRONT_METERS
		var current: Dictionary = WEATHER.at(distance, 0)
		unique[current["label"]] = true
		_check(current == WEATHER.at(distance, 0), "weather selection is repeatable")
		for key in ["clouds", "rain", "wind", "night"]:
			_check(float(current[key]) >= 0.0 and float(current[key]) <= 1.0,
				"weather intensities remain bounded")
	_check(unique.size() == 6, "long river visibly cycles all six weather conditions")
	_check(float(WEATHER.at(4.0 * WEATHER.FRONT_METERS + 35.0, 0)["night"]) == 1.0,
		"clear night reaches full intended intensity")
	_check(float(WEATHER.at(2.0 * WEATHER.FRONT_METERS + 35.0, 0)["rain"]) > 0.8,
		"rainfront produces actual animated-rain state")
	for index in range(1, 6):
		var border: float = float(index) * WEATHER.FRONT_METERS
		var before: Dictionary = WEATHER.at(border - 0.001, 3)
		var after: Dictionary = WEATHER.at(border + 0.001, 3)
		for key in ["clouds", "rain", "wind", "night"]:
			_check(absf(float(before[key]) - float(after[key])) < 0.002,
				"weather fronts crossfade without sudden change")
	_check(WEATHER.at(0.0, 2) == WEATHER.at(-123.0, 2), "negative position safely clamps")
	_check(WEATHER.at(110.0, 2) != WEATHER.at(110.0, 3),
		"changing a run seed changes the forecast without changing river geometry")

	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.chapters.unlocked_count = 6
	game._start_chapter(4)
	var chapter_seed: int = game.weather_seed
	var course: Array = []
	for pad in game.pads:
		course.append([pad["id"], pad["x"], pad["m"]])
	var original_score: int = game.score
	var original_leaves: int = game.leaves
	# The SceneTree keeps calling _process() on alive gameplay between frames.
	# Pause the world while rendering weather at synthetic distant coordinates:
	# otherwise lily streaming/pruning is expected, not a weather regression.
	game._pause_game()
	for type_index in range(6):
		game.weather_seed = type_index
		game.graphics_quality = type_index % 3
		game.cam_m = float(type_index) * WEATHER.FRONT_METERS
		game.player_m = game.cam_m
		game.queue_redraw()
		await process_frame
		_check(game.score == original_score and game.leaves == original_leaves,
			"weather-only redraws do not modify score or leaves")
		_check(game.pads.size() == course.size(),
			"weather cannot generate or remove physical lily pads")
	game._start_chapter(4)
	_check(game.weather_seed == chapter_seed, "same chapter always restores its own forecast")
	var repeated: Array = []
	for pad in game.pads:
		repeated.append([pad["id"], pad["x"], pad["m"]])
	_check(repeated == course, "chapter lily route unchanged across weather redraws")
	game._pause_game()
	var snapshot: Dictionary = WEATHER.at(game.player_m, game.weather_seed)
	game._process(3.0)
	_check(WEATHER.at(game.player_m, game.weather_seed) == snapshot,
		"pause and background stalls preserve exact weather state")
	game._resume_game()
	game._start_daily_river()
	var daily_seed: int = game.weather_seed
	game._start_daily_river()
	_check(game.weather_seed == daily_seed,
		"today's Daily River forecast is stable across retry")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: six day/night/rain/wind fronts, smooth fades, all graphics tiers, stable chapters and daily forecast")
	else:
		printerr("FAIL: weather assertions %d" % failures)
	quit(0 if failures == 0 else 1)
