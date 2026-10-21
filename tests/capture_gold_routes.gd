extends SceneTree
## Capture the new decision gameplay with the actual Godot renderer.
const DANGER = preload("res://scripts/pad_danger.gd")
const OUT := "res://build/qa"
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
	game.wave_m = -60.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var original: Dictionary = game.pads[1]
	var gold := original.duplicate(true)
	gold["id"] = 1000000 + int(original["id"])
	gold["x"] = float(original["x"]) + 94.0
	gold["r"] = 37.0
	gold["branch_bonus"] = true
	gold["coin"] = false
	gold["pet"] = false
	gold["boost"] = false
	gold["guardian"] = false
	gold["fragile"] = false
	gold["harmony"] = false
	gold["moving"] = false
	gold["danger"] = false
	game.pads.append(gold)
	game.aim_x = float(gold["x"])
	game.aim_m = float(gold["m"])
	game.mode = game.MODE_AIM
	await _save(game, "01-gold-route-choice.png")
	game.pads.erase(gold)
	original["danger"] = true
	var arrival_delay: float = game._duration_to(float(original["m"]))
	original["danger_phase"] = fposmod(0.7 - game.clock - arrival_delay, DANGER.CYCLE_SECONDS)
	game.aim_x = float(original["x"])
	game.aim_m = float(original["m"])
	await _save(game, "02-crab-warning.png")
	game.queue_free()
	await process_frame
	print("PASS: authentic Godot gold route and future-time crab warning screenshots")
	quit(0)
func _save(game: Node2D, filename: String) -> void:
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	assert(not img.is_empty())
	img.resize(1080, 1920, Image.INTERPOLATE_LANCZOS)
	assert(img.save_png(ProjectSettings.globalize_path(OUT.path_join(filename))) == OK)
