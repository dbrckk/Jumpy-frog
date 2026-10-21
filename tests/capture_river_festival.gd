extends SceneTree
## Two unaltered Godot frames for QA. Uses real in-game UI and renderer.
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
	game.wave_m = -55.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	game.festival.progress = 2
	game.festival.active_group = 23
	var first: Dictionary = game.pads[1]
	var second: Dictionary = game.pads[2]
	var third: Dictionary = game.pads[3]
	for index in range(3):
		var pad: Dictionary = [first, second, third][index]
		pad["festival_step"] = index
		pad["festival_group"] = 23
		pad["festival_collected"] = index < 2
		pad["moving"] = false
		pad["danger"] = false
		pad["fragile"] = false
	await _save(game, "03-firefly-festival.png")
	game.festival.progress = 0
	game.festival.completions = 1
	game.festival_banner_seconds = 2.3
	game.precision_pulse = 1.2
	game.celebration = 1.0
	game.player_m = float(third["m"])
	game.player_x = float(third["x"])
	game.score = 5800
	game.leaves = 3
	game.wave_m = game.player_m - 34.0
	third["festival_collected"] = true
	game.mode = game.MODE_PLAY
	await _save(game, "04-firefly-reward.png")
	game.queue_free()
	await process_frame
	print("PASS: two authentic festival and reward-screen renders")
	quit(0)

func _save(game: Node2D, filename: String) -> void:
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(not image.is_empty())
	image.resize(1080, 1920, Image.INTERPOLATE_LANCZOS)
	assert(image.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(filename))) == OK)
