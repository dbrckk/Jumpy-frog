extends Node2D
## A complete endless-runner prototype driven by touch (and mouse emulation).
const ART = preload("res://scripts/art.gd")
const W := 540.0
const H := 960.0
const PX_PER_M := 8.0
const PLAYER_ANCHOR := 700.0
const MODE_TITLE := 0
const MODE_PLAY := 1
const MODE_AIM := 2
const MODE_FLY := 3
const MODE_LOST := 4
const MODE_PAUSED := 5

var mode: int = MODE_TITLE
var rng := RandomNumberGenerator.new()
var pads: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var clock: float = 0.0
var player_x: float = 270.0
var player_m: float = 0.0
var cam_m: float = 0.0
var wave_m: float = -32.0
var highest_m: float = 0.0
var last_generated_m: float = 0.0
var last_pad_x: float = 270.0
var next_pad_id: int = 1
var pets: int = 0
var score: int = 0
var best_score: int = 0
var combo: int = 0
var aim_start := Vector2.ZERO
var aim_current := Vector2.ZERO
var aim_x: float = 270.0
var aim_m: float = 0.0
var jump_start := Vector2.ZERO
var jump_end := Vector2.ZERO
var jump_elapsed: float = 0.0
var jump_duration: float = 0.6
var jump_z: float = 0.0
var jump_pad_id: int = -1
var sound: AudioStreamPlayer
var muted: bool = false
var body_tilt := 0.0
var body_squash := 0.0
var stack_sway := 0.0
var blink_clock := 2.2
var blink_amount := 0.0
var landing_impact := 0.0
var horizontal_velocity := 0.0
var previous_x := 270.0
var pad_impacts: Dictionary = {}
var celebration := 0.0
var float_texts: Array[Dictionary] = []
var ripples: Array[Dictionary] = []

func _ready() -> void:
	rng.randomize()
	sound = AudioStreamPlayer.new()
	sound.bus = "Master"
	sound.volume_db = -11.0
	add_child(sound)
	var save := ConfigFile.new()
	if save.load("user://jumpy_frog.cfg") == OK:
		best_score = int(save.get_value("progress", "best_score", 0))
		muted = bool(save.get_value("progress", "muted", false))
	sound.volume_db = -80.0 if muted else -11.0
	_reset_game()

func _reset_game() -> void:
	mode = MODE_TITLE
	pads.clear()
	particles.clear()
	float_texts.clear()
	ripples.clear()
	pad_impacts.clear()
	celebration = 0.0
	player_x = 270.0
	player_m = 0.0
	cam_m = 0.0
	wave_m = -32.0
	highest_m = 0.0
	last_generated_m = 0.0
	last_pad_x = 270.0
	next_pad_id = 1
	pets = 0
	score = 0
	combo = 0
	aim_x = 270.0
	aim_m = 0.0
	jump_z = 0.0
	jump_pad_id = -1
	body_tilt = 0.0
	body_squash = 0.0
	stack_sway = 0.0
	blink_clock = rng.randf_range(1.4, 3.3)
	blink_amount = 0.0
	landing_impact = 0.0
	horizontal_velocity = 0.0
	previous_x = player_x
	pads.append({"id":0, "x":270.0, "m":0.0, "r":55.0, "kind":0, "coin":false, "pet":false})
	_generate_pads()

func _generate_pads() -> void:
	while last_generated_m < player_m + 190.0:
		last_generated_m += rng.randf_range(15.2, 21.7)
		var dx := rng.randf_range(-110.0, 110.0)
		last_pad_x = clampf(last_pad_x + dx, 116.0, 421.0)
		var ident := next_pad_id
		next_pad_id += 1
		var kind: int = rng.randi_range(0, 3)
		pads.append({
			"id": ident,
			"x": last_pad_x,
			"m": last_generated_m,
			"r": rng.randf_range(42.0, 55.0),
			"kind": kind,
			"coin": ident % 2 == 0,
			"pet": ident % 3 == 0
		})

func _process(delta: float) -> void:
	delta = minf(delta, 0.08)
	if mode == MODE_PAUSED:
		queue_redraw()
		return
	clock += delta
	if mode in [MODE_PLAY, MODE_AIM, MODE_FLY]:
		var pressure := 2.4 + minf(highest_m * 0.013, 4.5)
		wave_m += delta * pressure
		if wave_m >= player_m - 0.25 and mode != MODE_FLY:
			_die()
	if mode == MODE_FLY:
		jump_elapsed += delta
		var t := clampf(jump_elapsed / jump_duration, 0.0, 1.0)
		var smooth := t * t * (3.0 - 2.0 * t)
		player_x = lerpf(jump_start.x, jump_end.x, smooth)
		player_m = lerpf(jump_start.y, jump_end.y, smooth)
		jump_z = sin(t * PI) * 53.0
		if t >= 1.0:
			_finish_jump()
	# Exponential damping is stable across varying Android frame rates.
	var damping := 1.0 - exp(-delta * 9.0)
	horizontal_velocity = (player_x - previous_x) / maxf(delta, 0.001)
	previous_x = player_x
	var target_tilt := clampf(horizontal_velocity * 0.0024, -0.28, 0.28) if mode == MODE_FLY else 0.0
	body_tilt = lerpf(body_tilt, target_tilt, damping)
	stack_sway = lerpf(stack_sway, -body_tilt * 1.8, 1.0 - exp(-delta * 4.1))
	landing_impact = maxf(0.0, landing_impact - delta * 3.4)
	celebration = maxf(0.0, celebration - delta * 1.8)
	for pad_id in pad_impacts.keys():
		pad_impacts[pad_id] = maxf(0.0, float(pad_impacts[pad_id]) - delta * 2.8)
		if float(pad_impacts[pad_id]) <= 0.0:
			pad_impacts.erase(pad_id)
	var squash_target := 0.13 if mode == MODE_AIM else 0.0
	body_squash = lerpf(body_squash, squash_target, 1.0 - exp(-delta * 12.0))
	blink_clock -= delta
	if blink_clock <= 0.0:
		blink_clock = rng.randf_range(2.1, 4.2)
		blink_amount = 1.0
	blink_amount = maxf(0.0, blink_amount - delta * 7.5)
	cam_m = lerpf(cam_m, player_m, minf(1.0, delta * 4.7))
	if not pads.is_empty() and float(pads[0]["m"]) < cam_m - 75.0:
		pads.pop_front()
	if mode in [MODE_PLAY, MODE_AIM, MODE_FLY]:
		_generate_pads()
	for i in range(float_texts.size() - 1, -1, -1):
		var item: Dictionary = float_texts[i]
		item["life"] = float(item["life"]) - delta
		item["pos"] = Vector2(item["pos"]) + Vector2(0, -44) * delta
		float_texts[i] = item
		if float(item["life"]) <= 0.0:
			float_texts.remove_at(i)
	for i in range(ripples.size() - 1, -1, -1):
		var ripple: Dictionary = ripples[i]
		ripple["age"] = float(ripple["age"]) + delta
		ripples[i] = ripple
		if float(ripple["age"]) >= 0.78:
			ripples.remove_at(i)
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		particle["life"] = float(particle["life"]) - delta * 1.85
		particle["pos"] = Vector2(particle["pos"]) + Vector2(particle["velocity"]) * delta
		particles[i] = particle
		if float(particle["life"]) <= 0.0:
			particles.remove_at(i)
	queue_redraw()

func _draw() -> void:
	var at := _player_screen()
	var preview := Vector2(aim_x, PLAYER_ANCHOR - (aim_m - cam_m) * PX_PER_M)
	var aim_valid := false
	if mode == MODE_AIM:
		var pad := _landing_target(aim_x, aim_m)
		if not pad.is_empty():
			preview = Vector2(float(pad["x"]), PLAYER_ANCHOR - (float(pad["m"]) - cam_m) * PX_PER_M)
			aim_valid = true
	ART.scene(self, clock, cam_m, pads, at, jump_z, pets, wave_m, mode == MODE_AIM, preview, aim_valid, mode, score, best_score, combo, particles, int(highest_m), muted, body_tilt, body_squash, stack_sway, blink_amount, landing_impact, pad_impacts, celebration, float_texts, ripples)

func _player_screen() -> Vector2:
	return Vector2(player_x, PLAYER_ANCHOR - (player_m - cam_m) * PX_PER_M)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_down(touch.position)
		else:
			_up(touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_move(drag.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_R, KEY_SPACE, KEY_ENTER] and mode == MODE_LOST:
			_reset_game()
		elif event.keycode == KEY_ESCAPE:
			if mode == MODE_PAUSED:
				mode = MODE_PLAY
			elif mode in [MODE_AIM, MODE_PLAY]:
				mode = MODE_PAUSED

func _down(pos: Vector2) -> void:
	if mode == MODE_PAUSED:
		if Rect2(108, 460, 324, 66).has_point(pos):
			mode = MODE_PLAY
		elif Rect2(108, 544, 324, 66).has_point(pos):
			muted = not muted
			sound.volume_db = -80.0 if muted else -11.0
			_save_progress()
		return
	if mode in [MODE_PLAY, MODE_AIM] and Rect2(473, 78, 63, 59).has_point(pos):
		mode = MODE_PAUSED
		return
	if mode == MODE_LOST:
		_reset_game()
		mode = MODE_PLAY
	elif mode == MODE_TITLE:
		mode = MODE_PLAY
	if mode != MODE_PLAY:
		return
	aim_start = pos
	aim_current = pos
	aim_x = player_x
	aim_m = player_m
	mode = MODE_AIM

func _move(pos: Vector2) -> void:
	if mode != MODE_AIM:
		return
	aim_current = pos
	_update_aim()

func _up(pos: Vector2) -> void:
	if mode != MODE_AIM:
		return
	aim_current = pos
	_update_aim()
	if aim_m - player_m < 4.0:
		mode = MODE_PLAY
		return
	_start_jump()

func _update_aim() -> void:
	var delta := aim_current - aim_start
	var drag := delta.limit_length(215.0)
	# Pull DOWN to jump UP. Pull LEFT to launch RIGHT.
	aim_x = clampf(player_x - drag.x * 1.2, 83.0, 457.0)
	aim_m = player_m + maxf(drag.y, 0.0) * 1.35 / PX_PER_M

## Preview and flight share this exact landing rule, so a green guide cannot miss.
func _landing_target(desired_x: float, desired_m: float) -> Dictionary:
	var winner: Dictionary = {}
	if desired_m <= player_m + 3.0:
		return winner
	var closest := INF
	for pad in pads:
		if float(pad["m"]) <= player_m + 3.0:
			continue
		var radius: float = float(pad["r"])
		var delta := Vector2(float(pad["x"]) - desired_x, (float(pad["m"]) - desired_m) * PX_PER_M)
		var normalized := Vector2(delta.x / (radius + 14.0), delta.y / (radius * 0.78 + 14.0))
		var d := normalized.length()
		if d <= 1.0 and d < closest:
			winner = pad
			closest = d
	return winner

func _start_jump() -> void:
	var target := _landing_target(aim_x, aim_m)
	jump_pad_id = -1 if target.is_empty() else int(target["id"])
	jump_start = Vector2(player_x, player_m)
	jump_end = Vector2(aim_x, aim_m)
	if not target.is_empty():
		# Subtle magnetism produces consistent, legible landings on touchscreens.
		jump_end = Vector2(float(target["x"]), float(target["m"]))
	jump_elapsed = 0.0
	jump_duration = clampf(0.40 + (jump_end.y - jump_start.y) * 0.012, 0.48, 0.87)
	body_squash = 0.23
	mode = MODE_FLY
	_tone(520.0, 0.095, 0)

func _finish_jump() -> void:
	jump_z = 0.0
	if jump_pad_id == -1:
		_add_ripple(_player_screen(), 1.5)
		_burst(_player_screen(), 11)
		_die()
		return
	for pad in pads:
		if int(pad["id"]) == jump_pad_id:
			var gain := maxi(12, int((float(pad["m"]) - highest_m) * 13.0))
			if bool(pad["coin"]):
				_add_float_text("+75", _player_screen() + Vector2(28, -55), Color("#fff3ad"))
				gain += 75
				pad["coin"] = false
			if bool(pad["pet"]):
				pets = mini(pets + 1, 8)
				celebration = 1.0
				_add_float_text("FRIEND +1", _player_screen() + Vector2(0, -99), Color("#fff1cc"))
				gain += 55
				pad["pet"] = false
				_tone(830.0, 0.16, 1)
			else:
				_tone(650.0, 0.075, 1)
			combo += 1
			score += maxi(gain, 0) + maxi(combo - 2, 0) * 10
			highest_m = maxf(highest_m, player_m)
			_add_ripple(_player_screen() + Vector2(0, 10), 1.0)
			pad_impacts[jump_pad_id] = 1.0
			landing_impact = 1.0
			body_squash = 0.28
			_burst(_player_screen() + Vector2(0, 14), 15)
			mode = MODE_PLAY
			if wave_m >= player_m - 0.25:
				_die()
			return
	_die()

func _die() -> void:
	if mode == MODE_LOST:
		return
	mode = MODE_LOST
	jump_z = 0.0
	_tone(180, 0.28, 2)
	if score > best_score:
		best_score = score
	_save_progress()

func _save_progress() -> void:
	var save := ConfigFile.new()
	save.set_value("progress", "best_score", best_score)
	save.set_value("progress", "muted", muted)
	save.save("user://jumpy_frog.cfg")

func _add_float_text(value: String, pos: Vector2, color: Color) -> void:
	float_texts.append({"text": value, "pos": pos, "life": 1.0, "color": color})

func _add_ripple(pos: Vector2, size: float) -> void:
	ripples.append({"pos": pos, "age": 0.0, "size": size})

func _burst(pos: Vector2, amount: int) -> void:
	for i in range(amount):
		particles.append({
			"pos": pos + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8)),
			"velocity": Vector2(rng.randf_range(-84, 84), rng.randf_range(-126, -30)),
			"life": rng.randf_range(0.55, 1.0)
		})

func _tone(freq: float, duration: float, kind: int) -> void:
	# Embedded synthesis avoids any licensed or externally hosted audio files.
	if muted:
		return
	var wav := AudioStreamWAV.new()
	wav.mix_rate = 22050
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	var samples := int(duration * 22050.0)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / 22050.0
		var attack := minf(1.0, t * 100.0)
		var env := attack * pow(1.0 - float(i) / float(samples), 2.0)
		var f := freq * (1.0 + 0.15 * t / maxf(duration, 0.01)) if kind == 0 else freq
		if kind == 2:
			f = freq * (1.0 - t / duration * 0.45)
		var tone_value := sin(TAU * f * t) * 0.75 + sin(TAU * f * 2.0 * t) * 0.17
		var n := int(clampf(tone_value * env * 10000.0, -32767.0, 32767.0))
		if n < 0:
			n += 65536
		bytes[i * 2] = n & 255
		bytes[i * 2 + 1] = (n >> 8) & 255
	wav.data = bytes
	sound.stream = wav
	sound.play()
