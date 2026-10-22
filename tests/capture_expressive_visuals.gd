extends SceneTree
## Authentic rasterized Godot frames used for review on all six river biomes.
const PATH := "res://build/qa"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH))
	for biome in range(6):
		game._start_chapter(biome)
		game.mode = game.MODE_PLAY
		game.wave_m = -45.0
		game.graphics_quality = 2
		await _save(game, "20-biome-%d-high.png" % biome)
	for biome in [3, 5]:
		game._start_chapter(biome)
		game.mode = game.MODE_PLAY
		game.wave_m = -45.0
		game.graphics_quality = 0
		await _save(game, "21-biome-%d-low.png" % biome)
	game._reset_game()
	game.mode = game.MODE_AIM
	game.wave_m = -40.0
	game.graphics_quality = 2
	var target: Dictionary = game.pads[1]
	game.aim_x = float(target["x"])
	game.aim_m = float(target["m"])
	await _save(game, "22-frog-perfect-expression.png")
	target["danger"] = true
	var duration: float = game._duration_to(float(target["m"]))
	target["danger_phase"] = fposmod(0.72 - game.clock - duration, 4.8)
	await _save(game, "23-frog-worried-crab.png")
	game.queue_free()
	await process_frame
	print("PASS: 10 real 1080x1920 high/low biomes and expressive frog preview screenshots")
	quit(0)

func _save(game: Node2D, name: String) -> void:
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	assert(not img.is_empty())
	img.resize(1080, 1920, Image.INTERPOLATE_LANCZOS)
	assert(img.save_png(ProjectSettings.globalize_path(PATH.path_join(name))) == OK)
