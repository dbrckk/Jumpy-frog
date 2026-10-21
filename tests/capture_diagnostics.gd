extends SceneTree
const OUTPUT := "res://build/qa"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sound.set_muted(true)
	for i in range(120):
		game.performance_sampler.record(1.0 / 60.0)
	game.mode = game.MODE_PAUSED
	game.sound.set_paused(true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await _save(game, "pause.png")
	game.mode = game.MODE_DIAGNOSTICS
	await _save(game, "device_diagnostics.png")
	game.queue_free()
	await process_frame
	print("PASS: two real pause/device diagnostics UI captures")
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
