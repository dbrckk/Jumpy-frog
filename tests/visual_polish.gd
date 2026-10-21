extends SceneTree
## Scenic quality is deterministic and separate from the collision/simulation.
const ART = preload("res://scripts/art.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(ART._biome_blend(0.0, -1) == 1.0, "first biome is fully saturated")
	_check(ART._biome_blend(139.99, -1) == 1.0, "no color flicker before boundary")
	_check(is_zero_approx(ART._biome_blend(140.0, -1)), "new biome starts with outgoing colors")
	_check(absf(ART._biome_blend(148.0, -1) - 0.5) < 0.01, "center of 16m palette crossfade")
	_check(is_equal_approx(ART._biome_blend(156.0, -1), 1.0), "full destination palette after 16m")
	_check(is_zero_approx(ART._biome_blend(280.0, -1)), "subsequent sectors blend too")
	for chapter in [-2, 0, 1, 2, 3, 4, 5]:
		for distance in [0.0, 140.0, 148.0, 280.0, 560.0]:
			_check(is_equal_approx(ART._biome_blend(distance, chapter), 1.0), "chapter/daily palette never mixes unrelated biomes")
	for sector in range(1, 20):
		var last := -0.01
		for offset in range(17):
			var fraction: float = ART._biome_blend(float(sector * 140 + offset), -1)
			_check(fraction >= last and fraction <= 1.0, "palette blending is smooth and monotone")
			last = fraction
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.mode = 1
	game.campaign_stage = -1
	for quality in range(3):
		game.graphics_quality = quality
		for biome in range(6):
			game.player_m = float(biome * 140 + 12)
			game.cam_m = game.player_m
			game._process(0.016)
			_check(game.mode != game.MODE_LOST, "visual tier and biome don't force failure")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: seamless sector transitions, chapter palettes, six biome atmospheres and three quality tiers")
	else:
		printerr("FAIL: %d visual transition regressions" % failures)
	quit(0 if failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
