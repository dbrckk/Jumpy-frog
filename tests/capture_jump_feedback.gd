extends SceneTree
## Actual Godot-rendered Android-portrait frames for spring and grade feedback.
const DIR := "res://build/qa"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game._reset_game()
	game.mode = game.MODE_AIM
	game.wave_m = -42.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var target: Dictionary = game.pads[1]
	game.aim_x = float(target["x"])
	game.aim_m = float(target["m"])
	await _save(game, "12-perfect-landing-preview.png")

	# Green edge landing without claiming the PERFECT bonus.
	game.aim_x = float(target["x"]) + float(target["r"]) * 0.41
	await _save(game, "13-safe-edge-preview.png")

	# The same score-grade remains available at quality zero.
	game.aim_x = float(target["x"])
	game.graphics_quality = 0
	await _save(game, "14-perfect-preview-low-graphics.png")
	game.queue_free()
	await process_frame
	print("PASS: three authentic Godot touch-preview frames: perfect, safe and Android low-quality")
	quit(0)

func _save(game: Node2D, filename: String) -> void:
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(not image.is_empty())
	image.resize(1080, 1920, Image.INTERPOLATE_LANCZOS)
	assert(image.save_png(ProjectSettings.globalize_path(DIR.path_join(filename))) == OK)
