extends SceneTree
## Real Godot-rasterized screenshots of the new Endless Tide Refuge.
## Capture high and minimal Android graphics tiers and a true rewarded landing.
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
	game.wave_m = -73.0
	game.graphics_quality = 2
	game.biome_banner = 0.0
	var first: Dictionary = game.pads[1]
	var tide := first.duplicate(true)
	tide["id"] = 1000000 + int(first["id"])
	tide["x"] = clampf(float(first["x"]) + 96.0, 95.0, 445.0)
	tide["r"] = 40.0
	tide["kind"] = 3
	tide["coin"] = false
	tide["pet"] = false
	tide["boost"] = false
	tide["guardian"] = false
	tide["moving"] = false
	tide["fragile"] = false
	tide["danger"] = false
	tide["harmony"] = false
	tide["branch_bonus"] = false
	tide["tide_refuge"] = true
	game.pads.append(tide)
	game.mode = game.MODE_AIM
	game.aim_x = float(tide["x"])
	game.aim_m = float(tide["m"])
	await _save(game, "51-tide-refuge-aim.png")
	game.graphics_quality = 0
	await _save(game, "52-tide-refuge-low-tier.png")
	game.graphics_quality = 2
	game.mode = game.MODE_PLAY
	game._start_jump()
	for frame in range(64):
		game._process(0.02)
		if game.mode != game.MODE_FLY:
			break
	assert(game.mode == game.MODE_PLAY)
	assert(not bool(tide.get("tide_refuge", false)))
	await _save(game, "53-tide-refuge-earned.png")
	game.queue_free()
	await process_frame
	print("PASS: 3 actual 1080x1920 rendered Tide Refuge aim, low-tier labeling and earned-wave-relief frames")
	quit(0)

func _save(game: Node2D, filename: String) -> void:
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(not image.is_empty())
	image.resize(1080, 1920, Image.INTERPOLATE_LANCZOS)
	assert(image.save_png(ProjectSettings.globalize_path(OUT.path_join(filename))) == OK)
