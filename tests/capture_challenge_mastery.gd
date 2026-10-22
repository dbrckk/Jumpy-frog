extends SceneTree
## Authentic end-of-run achievement panel on both quality tiers.
const OUT := "res://build/qa"
func _initialize() -> void:
	call_deferred("_capture")
func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game._reset_game()
	game.mode = game.MODE_LOST
	game.campaign_stage = -1
	game.score = 2940
	game.best_score = 3110
	game.run_hops = 81
	game.run_perfects = 33
	game.run_peak_combo = 13
	game.run_friends = 4
	game.highest_m = 925.0
	game.best_endless_m = 1104
	game.lifetime_challenge_wins = [5, 2, 3, 1]
	game.lifetime_best_challenge_streak = 6
	game.graphics_quality = 2
	await _save(game, "47-lifetime-mastery.png")
	game.lifetime_challenge_wins = [0, 0, 0, 0]
	game.lifetime_best_challenge_streak = 0
	game.graphics_quality = 0
	await _save(game, "48-new-player-mastery.png")
	game.queue_free()
	await process_frame
	print("PASS: real 1080x1920 lifetime mastery and first-run result screenshots")
	quit(0)
func _save(game: Node2D, filename: String) -> void:
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	assert(not frame.is_empty())
	frame.resize(1080,1920,Image.INTERPOLATE_LANCZOS)
	assert(frame.save_png(ProjectSettings.globalize_path(OUT.path_join(filename))) == OK)
