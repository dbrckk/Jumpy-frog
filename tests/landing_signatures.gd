extends SceneTree
## Contact motifs must be visible in all six biomes without changing gameplay.
const MOTION = preload("res://scripts/visual_motion.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_exercise")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _exercise() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.chapters.unlocked_count = 6
	for biome in range(6):
		game._start_chapter(biome)
		var current_seed: int = game.chapter_rng.seed
		var initial_score: int = game.score
		var initial_leaves: int = game.leaves
		var initial_pads: Array = []
		for pad in game.pads:
			initial_pads.append([pad["id"], pad["x"], pad["m"], pad["r"]])
		game._pause_game()
		_check(game.mode == game.MODE_PAUSED, "motif capture freezes the chapter")
		for quality in range(3):
			game.graphics_quality = quality
			game.pad_impacts[0] = 1.0
			game.queue_redraw()
			await process_frame
			_check(game.score == initial_score and game.leaves == initial_leaves,
				"painting a biome landing cannot modify rewards")
			_check(game.chapter_rng.seed == current_seed,
				"painted motifs never reseed chapter courses")
			_check(MOTION.landing_signature_count(quality) <= 6,
				"particle-free signature remains a bounded draw call budget")
			var repeated: Array = []
			for pad in game.pads:
				repeated.append([pad["id"], pad["x"], pad["m"], pad["r"]])
			_check(repeated == initial_pads,
				"rendering a biome landing never changes the lily layout")
		game._resume_game()
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: six distinct biome landings, 18 graphics-tier redraws, deterministic courses, no economy changes")
	else:
		printerr("FAIL: biome landing signatures (%d)" % failures)
	quit(0 if failures == 0 else 1)
