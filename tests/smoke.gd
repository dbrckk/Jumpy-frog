extends SceneTree
## Exit code 1 on *any* failed assertion; CI must never report a false pass.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("SMOKE STAGE: load scene")
	var scene: Node2D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	print("SMOKE STAGE: first frame")
	_check(scene.mode == 0, "opens on the title screen")
	# Prevent a native libwilhelm / OpenSL ES regression on Android 15.
	_check(String(ProjectSettings.get_setting("audio/driver/driver.android", "")) == "Dummy", "Android must use Dummy audio driver until native callback is verified safe")
	_check(scene.sound.mobile_safe_mode == OS.has_feature("android"), "audio compatibility mode follows Android feature")
	if OS.has_feature("android"):
		_check(scene.muted, "Android compatibility mode starts muted")
		_check(scene.sound.voices.is_empty(), "Android never creates AudioStreamPlayer voices")
		_check(scene.sound.ambience == null, "Android never starts looping WAV background")
		_check(scene.sound.samples.is_empty(), "Android skips PCM synthesis")

	_check(scene.pads.size() >= 4, "generates platforms")
	_check(scene.pads[0]["m"] == 0.0, "starts on a lily")
	print("SMOKE STAGE: progression")
	# Production meta-progression: wardrobe prices, persistence, and locked choices.
	_check(scene.selected_skin >= 0 and scene.selected_skin <= 3, "selected skin validated")
	_check(scene._is_unlocked(0), "starter skin always owned")
	var prior_leaves: int = scene.leaves
	scene._reset_game()
	_check(scene.leaves == prior_leaves, "run reset retains earned leaves")
	scene.mode = 0
	scene._down(Vector2(255, 733))
	_check(scene.mode == 6, "title opens wardrobe")
	scene.leaves = 200
	scene._down(Vector2(360, 396))
	_check(scene._is_unlocked(1), "wardrobe can buy a skin")
	_check(scene.selected_skin == 1, "purchased skin equipped")
	_check(scene.leaves == 188, "purchase deducts exact leaf price")
	scene._down(Vector2(361, 565))
	_check(scene._is_unlocked(3), "wardrobe can unlock fourth skin")
	_check(scene.leaves == 123, "second purchase deducted")
	scene._down(Vector2(260, 806))
	_check(scene.mode == 0, "wardrobe back button works")
	var saved_skin: int = scene.selected_skin
	var saved_leaves: int = scene.leaves
	scene._save_progress()
	var persistent := ConfigFile.new()
	_check(persistent.load("user://jumpy_frog.cfg") == OK, "save file is readable")
	_check(int(persistent.get_value("progress", "selected_skin", -1)) == saved_skin, "selected skin persisted")
	_check(int(persistent.get_value("progress", "leaves", -1)) == saved_leaves, "leaf balance persisted")
	scene._reset_game()

	if not OS.has_feature("android"):
		# Every original sound is generated offline once and cached for reuse.
		_check(scene.sound.samples.size() == 11, "eleven independent original sound effects are cached")
		_check(scene.sound.voices.size() == 6, "six simultaneous audio voices are available")
		_check(scene.sound.ambience.stream is AudioStreamWAV, "ambient river sound has a real audio stream")
		_check(scene.sound.music != null and scene.sound.music.stream is AudioStreamWAV, "original melodic backing track is available")
		_check(scene.sound.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "original melody loops")
		var distinct_lengths: Dictionary = {}
		for event_name in scene.sound.samples.keys():
			var stream: AudioStreamWAV = scene.sound.samples[event_name]
			_check(stream.data.size() > 2000, "cached effect contains nonempty PCM: " + str(event_name))
			_check(stream.mix_rate == 22050, "effect sample rate is consistent")
			distinct_lengths[stream.data.size()] = true
		_check(distinct_lengths.size() >= 6, "events have varied durations and audible identities")
		scene.sound.set_muted(false)
		var voice_cursor: int = scene.sound.next_voice
		scene.sound.play_event("coin")
		_check(scene.sound.next_voice != voice_cursor, "audio playback uses pooled voice")
		scene.sound.set_paused(true)
		voice_cursor = scene.sound.next_voice
		scene.sound.play_event("land")
		_check(scene.sound.next_voice == voice_cursor, "pausing prevents new sound effects")
		scene.sound.set_paused(false)
		scene.sound.set_muted(true)
		scene.sound.play_event("friend")
		_check(scene.sound.next_voice == voice_cursor, "muting prevents new sound effects")
		scene.sound.set_muted(false)

	var first: Dictionary = scene.pads[1]
	var predicted: Dictionary = scene._landing_target(float(first["x"]), float(first["m"]))
	_check(not predicted.is_empty() and int(predicted.get("id", -1)) == int(first["id"]), "landing preview predicts actual platform")
	_check(scene._landing_target(70.0, 2000.0).is_empty(), "empty water is marked unsafe")
	
	print("SMOKE STAGE: jumping")
	# A direct hop reproduces a future touch release and tests score/collision.
	scene.mode = 1
	scene.aim_x = first["x"]
	scene.aim_m = first["m"]
	scene._start_jump()
	_check(scene.mode == 3, "starts a hop")
	_check(scene.jump_pad_id == first["id"], "flight uses same preview target")
	for i in range(75):
		scene._process(0.02)
	_check(scene.mode == 1, "lands on lily")
	_check(absf(scene.player_m - float(first["m"])) < 0.01, "player moves forward")
	_check(scene.score > 0, "landing earns score")
	
	scene.aim_x = 270.0
	scene.aim_m = scene.player_m + 3000.0
	scene._start_jump()
	_check(scene.jump_pad_id == -1, "missing platform predicts splash")
	for i in range(75):
		scene._process(0.02)
	_check(scene.mode == 4, "missing platform ends run")
	
	scene._reset_game()
	scene.mode = 1
	scene._down(Vector2(494, 99))
	_check(scene.mode == 5, "pause button suspends")
	_check(scene.sound.paused, "pause also suspends ambience")
	var pause_wave: float = scene.wave_m
	scene._process(1.0)
	_check(scene.wave_m == pause_wave, "pause freezes wave")
	var previous_mute: bool = scene.muted
	scene._down(Vector2(260, 575))
	if OS.has_feature("android"):
		_check(scene.muted == previous_mute, "Android safe mode cannot be re-enabled from pause")
	else:
		_check(scene.muted != previous_mute, "sound setting works")
	scene._down(Vector2(260, 490))
	_check(scene.mode == 1, "resume returns to play")
	_check(not scene.sound.paused, "resuming restores ambience")
	
	# Real swipe: pull down and sideways to land on the first lily.
	scene._reset_game()
	scene.mode = 1
	var next_pad: Dictionary = scene.pads[1]
	var down := Vector2(250, 410)
	var swipe := Vector2(
		(scene.player_x - float(next_pad["x"])) / 1.2,
		(float(next_pad["m"]) - scene.player_m) * 8.0 / 1.35
	)
	scene._down(down)
	scene._move(down + swipe)
	_check(scene.mode == 2, "starts gesture aim")
	_check(not scene._landing_target(scene.aim_x, scene.aim_m).is_empty(), "gesture predicts a valid landing")
	scene._up(down + swipe)
	_check(scene.mode == 3 and scene.jump_pad_id == int(next_pad["id"]), "release launches predicted target")
	for i in range(75):
		scene._process(0.02)
	_check(scene.mode == 1, "touch gesture lands correctly")
	
	print("SMOKE STAGE: procedural layouts")
	# Generated runs must never demand a physically impossible next jump.
	for seed_index in range(64):
		scene.rng.seed = seed_index * 173 + 11
		scene._reset_game()
		for index in range(1, scene.pads.size()):
			var prev: Dictionary = scene.pads[index - 1]
			var curr: Dictionary = scene.pads[index]
			var dx: float = (float(curr["x"]) - float(prev["x"])) / 1.2
			var dy: float = (float(curr["m"]) - float(prev["m"])) * 8.0 / 1.35
			_check(Vector2(dx, dy).length() <= 215.0, "random platform gap reachable")
	
	print("SMOKE STAGE: animation / VFX")
	# Animation state must respond to jumping/landing and reset predictably.
	scene._reset_game()
	scene.mode = 1
	var animate_pad: Dictionary = scene.pads[1]
	scene.aim_x = animate_pad["x"]
	scene.aim_m = animate_pad["m"]
	scene._start_jump()
	_check(scene.body_squash > 0.2, "takeoff squash activated")
	var saw_impact := false
	var saw_lily := false
	var saw_ripple := false
	var lily_relaxed := false
	var prior_lily := 0.0
	for frame in range(75):
		scene._process(0.02)
		if scene.ripples.size() > 0:
			saw_ripple = true
		if scene.landing_impact > 0.0:
			saw_impact = true
		var lily: float = float(scene.pad_impacts.get(int(animate_pad["id"]), 0.0))
		if lily > 0.0:
			saw_lily = true
		if saw_lily and lily < prior_lily:
			lily_relaxed = true
		prior_lily = lily
	_check(saw_impact, "landing triggers impact animation")
	_check(saw_lily, "lily impact animation triggered")
	_check(saw_ripple, "water ripple spawned at landing")
	var existing_ripples: int = scene.ripples.size()
	scene._add_float_text("TEST", Vector2(270, 320), Color.WHITE)
	_check(scene.float_texts.size() == 1, "floating reward created")
	for step in range(65):
		scene._process(0.02)
	_check(scene.float_texts.is_empty(), "floating reward expires")
	# Impact VFX must remain bounded even under deliberately excessive spawning.
	for index in range(20):
		scene._add_ripple(Vector2(250, 500), 1.0)
		scene._add_float_text("BONUS", Vector2(250, 420), Color.WHITE)
		scene._burst(Vector2(250, 500), 20, "water")
	_check(scene.ripples.size() <= 12, "ripple allocation is bounded")
	_check(scene.float_texts.size() <= 8, "reward allocation is bounded")
	_check(scene.particles.size() <= 110, "particle allocation is bounded")
	for index in range(70):
		scene._process(0.02)
	_check(scene.ripples.is_empty(), "ripples expire after spawning stress")
	_check(scene.float_texts.is_empty(), "reward labels expire after spawning stress")
	_check(scene.particles.is_empty(), "particles expire after spawning stress")
	_check(scene.ripples.size() <= existing_ripples, "water ripples expire")
	_check(lily_relaxed, "lily spring relaxes")
	scene._reset_game()
	_check(scene.body_tilt == 0.0 and scene.stack_sway == 0.0 and scene.landing_impact == 0.0, "animation reset")
	_check(scene.mode == 0 and scene.score == 0, "retry resets run")
	_check(scene.pads.size() >= 4, "retry generates platforms")
	if failures == 0:
		print("PASS: 9 cached SFX, looped ambience, voice pool, mute/pause, spawning, prediction, gestures, collision, scoring, VFX stress, 64 layouts, retry")
	else:
		printerr("FAILED: %d gameplay assertions" % failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
