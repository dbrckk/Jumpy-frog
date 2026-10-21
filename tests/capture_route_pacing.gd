extends SceneTree
## Portrait captures from the actual game canvas, not mockups.
const OUTPUT := "res://build/qa"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	game._reset_game()
	game.best_endless_m = 2874
	game.mode = game.MODE_TITLE
	await _save(game, "07-endless-best-distance.png")
	game._reset_game()
	game.mode = game.MODE_PLAY
	game.best_endless_m = 2874
	game.perfect_streak = 3
	game.wave_m = -45.0
	await _save(game, "08-flow-progress-meter.png")
	game.mode = game.MODE_LOST
	game.best_score = 22450
	game.score = 9110
	game.run_new_record = false
	game.run_hops = 26
	game.run_perfects = 13
	game.run_peak_combo = 8
	game.run_friends = 7
	game.run_leaves = 28
	game.highest_m = 432.0
	await _save(game, "09-endless-run-summary.png")
	game.queue_free()
	await process_frame
	print("PASS: three authentic best-distance, FLOW meter and Endless summary screenshots")
	quit(0)

func _save(game: Node2D, filename: String) -> void:
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	assert(not img.is_empty())
	img.resize(1080, 1920, Image.INTERPOLATE_LANCZOS)
	assert(img.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(filename))) == OK)
