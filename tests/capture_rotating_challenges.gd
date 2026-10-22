extends SceneTree
## Rasterize actual Gameplay HUD for each of the four challenge categories.
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
	game.mode = game.MODE_PLAY
	game.wave_m = -50.0
	game.biome_banner = 0.0
	game.graphics_quality = 2
	for t in range(4):
		game.precision_sprint.active = true
		game.precision_sprint.challenge_type = t
		game.precision_sprint.progress = 1
		game.precision_sprint.attempts = 3
		game.precision_sprint.perfects = 1
		await _save(game, "30-challenge-%d.png" % t)
	# Priority shift: never obscure celebration banner / wave messages.
	game.precision_sprint.active = true
	game.precision_sprint.challenge_type = 2
	game.precision_sprint.progress = 1
	game.precision_sprint.attempts = 4
	game.distance_banner_mark = 250
	game.distance_banner_seconds = 1.8
	game.biome_banner = 2.0
	await _save(game, "31-challenge-banner-safe.png")
	game.distance_banner_seconds = 0.0
	game.biome_banner = 0.0
	game.graphics_quality = 0
	game.precision_sprint.challenge_type = 1
	game.precision_sprint.progress = 0
	game.precision_sprint.attempts = 2
	await _save(game, "32-challenge-quality-low.png")
	game.queue_free()
	await process_frame
	print("PASS: six authentic 1080x1920 rotating challenges, priority-safe HUD and tier-zero screenshots")
	quit(0)

func _save(game: Node2D, filename: String) -> void:
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	assert(not img.is_empty())
	img.resize(1080, 1920, Image.INTERPOLATE_LANCZOS)
	assert(img.save_png(ProjectSettings.globalize_path(OUT.path_join(filename))) == OK)
