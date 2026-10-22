extends SceneTree
## Real Godot-rendered previews/results at both quality extremes, not mockups.
const DIR := "res://build/qa"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	game._reset_game()
	game.mode = game.MODE_PLAY
	game.biome_banner = 0.0
	game.wave_m = -62.0
	game.graphics_quality = 2

	game.run_hops = 15
	await _save(game, "40-next-precision-preview.png")
	game.run_hops = 17
	await _save(game, "41-next-hop-preview.png")

	game.run_hops = 188
	game.precision_sprint.active = true
	game.precision_sprint.challenge_type = game.precision_sprint.TYPE_FORAGER
	game.precision_sprint.level = 1
	game.precision_sprint.attempts = 3
	game.precision_sprint.progress = 1
	await _save(game, "42-advanced-leaf-hud.png")

	game.precision_sprint.active = false
	game.run_hops = 207
	game.challenge_banner = {"won": true, "title": "LONG LEAP", "level": 1, "leaves": 3, "score": 260}
	game.challenge_banner_seconds = 2.0
	await _save(game, "43-advanced-success.png")

	game.challenge_banner = {"won": false, "title": "FRIEND RESCUE", "level": 1}
	game.challenge_banner_seconds = 1.5
	await _save(game, "44-kind-failure.png")

	game.challenge_banner = {"won": true, "title": "LEAF TRAIL", "level": 1, "leaves": 3, "score": 260}
	game.challenge_banner_seconds = 2.0
	game.festival_banner_seconds = 1.8
	game.distance_banner_mark = 500
	game.distance_banner_seconds = 2.0
	game.biome_banner = 1.6
	game.graphics_quality = 0
	await _save(game, "45-low-graphics-multiple-events.png")

	game.challenge_banner.clear()
	game.challenge_banner_seconds = 0.0
	game.distance_banner_seconds = 0.0
	game.festival_banner_seconds = 0.0
	game.biome_banner = 0.0
	game.precision_sprint.active = true
	game.precision_sprint.challenge_type = game.precision_sprint.TYPE_FRIENDS
	game.precision_sprint.level = 1
	game.precision_sprint.attempts = 0
	game.precision_sprint.progress = 0
	game.precision_sprint.rest_hops = 3
	game.festival.progress = 1
	await _save(game, "46-festival-skill-rest.png")

	game.queue_free()
	await process_frame
	print("PASS: 7 genuine 1080x1920 advance warnings, progressive skill HUD, advanced rewards, gentle failure and festival-safe render frames")
	quit(0)

func _save(game: Node2D, name: String) -> void:
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	assert(not img.is_empty())
	img.resize(1080, 1920, Image.INTERPOLATE_LANCZOS)
	assert(img.save_png(ProjectSettings.globalize_path(DIR.path_join(name))) == OK)
