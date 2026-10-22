extends SceneTree
## Real frame rendering used by Play Store QA; no mockups.
const OUTPUT := "res://build/qa"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game._reset_game()
	game.mode = game.MODE_PLAY
	game.wave_m = -45.0
	game.highest_m = 250.0
	game.player_m = 250.0
	game.cam_m = 250.0
	game.distance_banner_mark = 250
	game.distance_banner_seconds = 2.4
	game.impact_flash = 0.18
	game.precision_pulse = 1.25
	game.leaves = 2
	game.score = 4800
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await _save(game, "10-250m-milestone.png")
	game.distance_banner_mark = 1000
	game.distance_banner_seconds = 2.1
	game.score = 21500
	game.graphics_quality = 0
	await _save(game, "11-low-quality-milestone.png")
	game.queue_free()
	await process_frame
	print("PASS: two authentic milestone celebrations rendered at high and low graphics quality")
	quit(0)
func _save(game: Node2D, file: String) -> void:
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	assert(not img.is_empty())
	img.resize(1080, 1920, Image.INTERPOLATE_LANCZOS)
	assert(img.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(file))) == OK)
