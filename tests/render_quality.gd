extends SceneTree
## Rendering quality and gameplay consistency. Headless tests check correctness
## and safety; they do not claim physical-device FPS measurements.
const FRAME_PACING = preload("res://scripts/frame_pacing.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	_check(game.river_shader_rect != null, "water caustics node exists")
	_check(game.river_shader_material != null, "water shader material installed")
	_check(game.river_shader_material.shader != null, "GL-compatible water shader loads")
	_check(not game.river_shader_rect.visible, "water shader off on title screen")
	_check(game.river_shader_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "shader cannot steal touch events")
	_check(game.graphics_quality == 2, "full quality is initial default")
	_check(FRAME_PACING.target_fps(game.MODE_PLAY) == 60
		and FRAME_PACING.target_fps(game.MODE_AIM) == 60
		and FRAME_PACING.target_fps(game.MODE_FLY) == 60,
		"Android gameplay retains responsive 60 FPS target across jump states")
	_check(FRAME_PACING.target_fps(game.MODE_TITLE) == 30
		and FRAME_PACING.target_fps(game.MODE_LOST) == 30
		and FRAME_PACING.target_fps(game.MODE_CHAPTERS) == 30
		and FRAME_PACING.target_fps(game.MODE_CLEAR) == 30,
		"noninteractive Android result and menu scenes reduce drawing cadence")
	_check(FRAME_PACING.target_fps(game.MODE_PAUSED) == 24
		and FRAME_PACING.target_fps(game.MODE_DIAGNOSTICS) == 24,
		"Android pause/diagnostics screens use a low-power cadence")
	_check(game._android_fps_cap == -1 or OS.has_feature("android"),
		"desktop CI does not silently change global frame cap")

	game.mode = 1
	for i in range(140):
		game._update_graphics_quality(0.033)
	_check(game.graphics_quality == 1, "sustained slow frames reduce decorative quality")
	for i in range(140):
		game._update_graphics_quality(0.033)
	_check(game.graphics_quality == 0, "second sustained slow period reaches minimal quality")
	for i in range(1500):
		game._update_graphics_quality(0.016)
	_check(game.graphics_quality == 2, "sustained recovery restores high-quality rendering")
	game._reset_game()
	_check(game.mode == 0 and game.graphics_quality == 2, "reset preserves adaptive quality preference")
	game.mode = 1
	game._process(0.016)
	_check(game.river_shader_rect.visible, "shader visible during active gameplay")
	game.mode = 5
	game._process(0.016)
	_check(not game.river_shader_rect.visible, "shader hidden behind pause/menu overlays")
	_check(not game.river_shader_rect.visible or game.graphics_quality > 0, "shader obeys performance tier")
	game._reset_game()
	game.graphics_quality = 0
	game.mode = 1
	game._process(0.016)
	_check(not game.river_shader_rect.visible, "slow-tier shader is disabled")
	var pad: Dictionary = game.pads[1]
	game.aim_x = float(pad["x"])
	game.aim_m = float(pad["m"])
	game._start_jump()
	_check(game.jump_pad_id == int(pad["id"]), "lower graphics tier preserves collision targeting")
	for frame in range(60):
		game._process(0.016)
		if game.mode != 3:
			break
	_check(game.mode == 1, "low-tier jump still lands correctly")
	_check(game.player_m > 0 and game.score > 0, "low-tier jump still earns rewards")

	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: water shader, touch-through, adaptive 2->1->0->2 and gameplay consistency")
	else:
		printerr("FAIL: rendering and performance regression " + str(failures))
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
