extends SceneTree
## Screenshots rendered by the real Godot game, not marketing mockups.
const OUTPUT := "res://build/store"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene: Node2D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.sound.set_muted(true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	# Title: the actual home screen, including the new customize button.
	scene.mode = 0
	await _save(scene, "01-title.png")
	# Gameplay: the same artwork and HUD players actually see.
	scene.mode = 1
	scene.player_m = 42.0
	scene.cam_m = 42.0
	scene.highest_m = 42.0
	scene.wave_m = 16.0
	scene.pets = 4
	scene.score = 1320
	scene.leaves = 25
	scene.run_leaves = 7
	scene._generate_pads()
	await _save(scene, "02-gameplay.png")
	# Wardrobe: actual UI with four unlocked looks for illustration only.
	scene.mode = 6
	scene.leaves = 200
	scene.unlocked_skins = 15
	scene.selected_skin = 3
	await _save(scene, "03-wardrobe.png")
	# End screen: actual overlay and earned-leaf feedback.
	scene.mode = 4
	scene.score = 2760
	scene.best_score = 3150
	scene.run_leaves = 10
	await _save(scene, "04-game-over.png")
	# A real rendering of the daily goals board, not an invented menu image.
	scene.mode = 7
	scene.daily.today_hops = 4
	scene.daily.today_distance = 70
	await _save(scene, "05-daily-goals.png")
	scene.queue_free()
	await process_frame
	print("PASS: five real 1080x1920 PNG store captures")
	quit(0)

func _save(scene: Node2D, filename: String) -> void:
	scene.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.is_empty():
		push_error("Capture failed: empty frame " + filename)
		quit(1)
		return
	img.resize(1080, 1920, Image.INTERPOLATE_LANCZOS)
	var path := ProjectSettings.globalize_path(OUTPUT.path_join(filename))
	var error := img.save_png(path)
	if error != OK:
		push_error("Failed writing " + path + ": " + str(error))
		quit(1)
