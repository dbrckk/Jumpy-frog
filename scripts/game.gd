extends Node2D
## A complete endless-runner prototype driven by touch (and mouse emulation).
const ART = preload("res://scripts/art.gd")
const AUDIO = preload("res://scripts/audio.gd")
const DAILY = preload("res://scripts/daily.gd")
const MONETIZATION = preload("res://scripts/monetization.gd")
const CHAPTERS = preload("res://scripts/chapters.gd")
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
const MODE_WARDROBE := 6
const MODE_GOALS := 7
const MODE_CHAPTERS := 8
const MODE_CLEAR := 9
const SKIN_COSTS := [0, 12, 30, 65, 110, 175, 260, 380]

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
var sound: Node
var muted: bool = false
var saved_muted: bool = false
var haptics_enabled := true
var leaves: int = 0
var unlocked_skins: int = 1
var selected_skin: int = 0
var wardrobe_page: int = 0
var total_runs: int = 0
var daily := DAILY.new()
var chapters := CHAPTERS.new()
var campaign_stage := -1
var clear_medal := 0
var clear_reward := 0
var last_biome := 0
var biome_banner := 0.0
var monetization: Node
var rewarded_this_run := false
var run_hops := 0
var run_leaves: int = 0
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
var shake_strength := 0.0
var impact_flash := 0.0
var wave_warned := false

func _ready() -> void:
	rng.randomize()
	sound = AUDIO.new()
	add_child(sound)
	monetization = MONETIZATION.new()
	add_child(monetization)
	monetization.rewarded_leaves_granted.connect(_on_rewarded_leaves)
	var save := ConfigFile.new()
	if save.load("user://jumpy_frog.cfg") == OK:
		best_score = int(save.get_value("progress", "best_score", 0))
		saved_muted = bool(save.get_value("progress", "muted", false))
		haptics_enabled = bool(save.get_value("progress", "haptics", true))
		leaves = maxi(0, int(save.get_value("progress", "leaves", 0)))
		unlocked_skins = maxi(1, int(save.get_value("progress", "unlocked_skins", 1))) & 255
		selected_skin = clampi(int(save.get_value("progress", "selected_skin", 0)), 0, 7)
		if not _is_unlocked(selected_skin):
			selected_skin = 0
		total_runs = maxi(0, int(save.get_value("progress", "total_runs", 0)))
	daily.load_from(save)
	chapters.load_from(save)
	muted = saved_muted or OS.has_feature("android")
	sound.set_muted(muted)
	sound.set_haptics(haptics_enabled)
	_reset_game()

func _reset_game() -> void:
	mode = MODE_TITLE
	campaign_stage = -1
	clear_medal = 0
	clear_reward = 0
	last_biome = 0
	biome_banner = 0.0
	sound.set_biome(0)
	if sound != null:
		sound.set_paused(false)
	pads.clear()
	particles.clear()
	float_texts.clear()
	ripples.clear()
	shake_strength = 0.0
	impact_flash = 0.0
	wave_warned = false
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
	run_leaves = 0
	run_hops = 0
	rewarded_this_run = false
	daily.refresh_day()
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
		var biome := chapters.biome_at(last_generated_m, campaign_stage)
		var modifier: Dictionary = chapters.chapter(biome)
		var progression := minf(highest_m / 1750.0, 1.0) if campaign_stage == -1 else 0.0
		var gap := rng.randf_range(15.2, 21.0)
		last_generated_m += gap
		var lateral: float = float(modifier["drift"])
		var dx := rng.randf_range(-lateral, lateral)
		if biome in [3, 5] and next_pad_id % 4 == 0:
			dx = (lateral * 0.85) * (-1.0 if next_pad_id % 8 == 0 else 1.0)
		last_pad_x = clampf(last_pad_x + dx, 116.0, 421.0)
		var ident := next_pad_id
		next_pad_id += 1
		var kind: int = rng.randi_range(0, 3)
		var radius_scale := float(modifier["radius"]) - progression * 0.08
		pads.append({
			"id": ident,
			"x": last_pad_x,
			"m": last_generated_m,
			"r": clampf(rng.randf_range(43.0, 53.0) * radius_scale, 37.0, 62.0),
			"kind": kind,
			"coin": ident % 2 == 0,
			"pet": ident % 3 == 0,
			"boost": ident % 7 == 0 and biome >= 1
		})

func _process(delta: float) -> void:
	delta = minf(delta, 0.08)
	if mode == MODE_PAUSED:
		queue_redraw()
		return
	clock += delta
	biome_banner = maxf(0.0, biome_banner - delta)
	var current_biome := chapters.biome_at(player_m, campaign_stage)
	if current_biome != last_biome:
		last_biome = current_biome
		sound.set_biome(current_biome)
		biome_banner = 2.2
		if mode in [MODE_PLAY, MODE_AIM, MODE_FLY]:
			sound.play_event("combo")
	shake_strength = maxf(0.0, shake_strength - delta * 21.0)
	impact_flash = maxf(0.0, impact_flash - delta * 1.6)
	if mode in [MODE_PLAY, MODE_AIM, MODE_FLY]:
		var biome_modifier: Dictionary = chapters.chapter(chapters.biome_at(player_m, campaign_stage))
		var pressure := 2.4 + minf(highest_m * 0.013, 4.5) + float(biome_modifier["wave"])
		wave_m += delta * pressure
		if wave_m > player_m - 14.0 and not wave_warned:
			wave_warned = true
			sound.play_event("warning")
		elif wave_m < player_m - 22.0:
			wave_warned = false
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
		if particle.get("kind", "spark") == "water":
			particle["velocity"] = Vector2(particle["velocity"]) + Vector2(0, 175.0) * delta
		else:
			particle["velocity"] = Vector2(particle["velocity"]) * exp(-delta * 1.5)
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
	var shake := Vector2(sin(clock * 89.0) * shake_strength, sin(clock * 113.0 + 1.1) * shake_strength * 0.6)
	ART.scene(self, clock, cam_m, pads, at, jump_z, pets, wave_m, mode == MODE_AIM, preview, aim_valid, mode, score, best_score, combo, particles, int(highest_m), muted, selected_skin, leaves, unlocked_skins, SKIN_COSTS, run_leaves, daily, monetization, rewarded_this_run, wardrobe_page, body_tilt, body_squash, stack_sway, blink_amount, landing_impact, pad_impacts, celebration, float_texts, ripples, shake, impact_flash, chapters, campaign_stage, biome_banner, clear_medal, clear_reward, haptics_enabled)

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
			if mode in [MODE_WARDROBE, MODE_GOALS, MODE_CHAPTERS, MODE_CLEAR]:
				mode = MODE_TITLE
			elif mode == MODE_PAUSED:
				mode = MODE_PLAY
				sound.set_paused(false)
			elif mode in [MODE_AIM, MODE_PLAY]:
				mode = MODE_PAUSED
				sound.set_paused(true)

func _down(pos: Vector2) -> void:
	if mode == MODE_CHAPTERS:
		if Rect2(105, 790, 330, 75).has_point(pos):
			mode = MODE_TITLE
			return
		for i in range(6):
			var x := 65.0 + float(i % 2) * 215.0
			var y := 335.0 + float(i / 2) * 138.0
			if Rect2(x, y, 192, 123).has_point(pos) and chapters.can_play(i):
				_start_chapter(i)
				return
		return
	if mode == MODE_CLEAR:
		if Rect2(72, 633, 195, 66).has_point(pos):
			var next_stage := campaign_stage + 1
			if chapters.can_play(next_stage):
				_start_chapter(next_stage)
			else:
				_reset_game()
			return
		if Rect2(285, 633, 190, 66).has_point(pos):
			_reset_game()
			return
		return
	if mode == MODE_GOALS:
		if Rect2(100, 815, 340, 67).has_point(pos):
			mode = MODE_TITLE
		return
	if mode == MODE_WARDROBE:
		if Rect2(139, 694, 262, 58).has_point(pos):
			wardrobe_page = 1 - wardrobe_page
			return
		if Rect2(100, 770, 340, 74).has_point(pos):
			mode = MODE_TITLE
			return
		for i in range(4):
			var index := i + wardrobe_page * 4
			var px := 66.0 + float(i % 2) * 216.0
			var py := 340.0 + float(i / 2) * 162.0
			if Rect2(px, py, 192, 146).has_point(pos):
				if _is_unlocked(index):
					selected_skin = index
					sound.play_event("ui")
					_save_progress()
				elif leaves >= SKIN_COSTS[index]:
					leaves -= SKIN_COSTS[index]
					unlocked_skins |= 1 << index
					selected_skin = index
					_save_progress()
					celebration = 1.0
					sound.play_event("friend")
				return
		return
	if mode == MODE_PAUSED:
		if Rect2(108, 781, 324, 54).has_point(pos) and monetization.billing != null and not monetization.premium:
			monetization.restore_purchase()
			return
		if Rect2(108, 633, 324, 62).has_point(pos) and monetization.purchase_ready and not monetization.premium:
			monetization.purchase_remove_ads()
			return
		if Rect2(108, 704, 324, 56).has_point(pos) and monetization.ads != null:
			monetization.ads.show_privacy_options()
			return
		if Rect2(108, 460, 324, 66).has_point(pos):
			mode = MODE_PLAY
			sound.set_paused(false)
		elif Rect2(108, 544, 324, 66).has_point(pos):
			if OS.has_feature("android"):
				haptics_enabled = not haptics_enabled
				sound.set_haptics(haptics_enabled)
			else:
				saved_muted = not saved_muted
				muted = saved_muted
				sound.set_muted(muted)
			_save_progress()
		return
	if mode in [MODE_PLAY, MODE_AIM] and Rect2(473, 78, 63, 59).has_point(pos):
		mode = MODE_PAUSED
		sound.set_paused(true)
		return
	if mode == MODE_LOST:
		var retry_chapter := campaign_stage
		if not rewarded_this_run and Rect2(80, 651, 390, 62).has_point(pos) and monetization.can_watch_rewarded():
			monetization.request_rewarded_leaves()
			return
		if Rect2(293, 565, 182, 65).has_point(pos):
			# Ads are requested only at an intentional between-run transition.
			if not rewarded_this_run:
				monetization.request_break_interstitial()
			_reset_game()
			return
		if Rect2(70, 565, 213, 65).has_point(pos) and not rewarded_this_run:
			monetization.request_break_interstitial()
		if retry_chapter >= 0:
			_start_chapter(retry_chapter)
			return
		_reset_game()
		mode = MODE_PLAY
		total_runs += 1
		daily.begin_run()
		_save_progress()
	elif mode == MODE_TITLE:
		if Rect2(139, 550, 262, 66).has_point(pos):
			mode = MODE_CHAPTERS
			return
		if Rect2(139, 403, 262, 58).has_point(pos) and monetization.purchase_ready and not monetization.premium:
			monetization.purchase_remove_ads()
			return
		if Rect2(139, 634, 262, 58).has_point(pos):
			mode = MODE_GOALS
			return
		if Rect2(139, 710, 262, 58).has_point(pos):
			mode = MODE_WARDROBE
			return
		mode = MODE_PLAY
		total_runs += 1
		daily.begin_run()
		_save_progress()
	if mode != MODE_PLAY:
		return
	aim_start = pos
	aim_current = pos
	aim_x = player_x
	aim_m = player_m
	mode = MODE_AIM

func _start_chapter(index: int) -> void:
	if not chapters.can_play(index):
		return
	_reset_game()
	campaign_stage = index
	last_biome = index
	sound.set_biome(index)
	biome_banner = 2.5
	chapters.record_attempt(index)
	mode = MODE_PLAY
	total_runs += 1
	daily.begin_run()
	# Replace initial pads with biome-aware geometry and chapter pacing.
	pads.resize(1)
	last_generated_m = 0.0
	last_pad_x = 270.0
	next_pad_id = 1
	_generate_pads()
	_save_progress()
	queue_redraw()

func _finish_chapter() -> void:
	if campaign_stage < 0 or mode != MODE_PLAY:
		return
	var completion: Dictionary = chapters.complete(campaign_stage, score, run_leaves)
	clear_medal = int(completion["stars"])
	clear_reward = int(completion["reward"])
	leaves += clear_reward
	run_leaves += clear_reward
	mode = MODE_CLEAR
	monetization.on_run_finished()
	daily.on_finish(score)
	celebration = 1.0
	impact_flash = 0.55
	sound.play_event("victory")
	if score > best_score:
		best_score = score
	_add_float_text("CHAPTER COMPLETE", _player_screen() + Vector2(0, -115), Color("#fff3bd"))
	_save_progress()

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
	sound.play_event("jump")

func _finish_jump() -> void:
	jump_z = 0.0
	if jump_pad_id == -1:
		shake_strength = 11.0
		impact_flash = 0.20
		sound.play_event("splash")
		_add_ripple(_player_screen(), 1.5)
		_burst(_player_screen(), 22, "water")
		_die()
		return
	for pad in pads:
		if int(pad["id"]) == jump_pad_id:
			var gain := maxi(12, int((float(pad["m"]) - highest_m) * 13.0))
			var collected_leaf: bool = bool(pad["coin"])
			var rescued_pet: bool = bool(pad["pet"])
			if bool(pad["coin"]):
				leaves += 1
				run_leaves += 1
				_save_progress()
				_add_float_text("+1 LEAF", _player_screen() + Vector2(-25, -79), Color("#e8fbb8"))
				sound.play_event("coin")
				_add_float_text("+75", _player_screen() + Vector2(28, -55), Color("#fff3ad"))
				gain += 75
				pad["coin"] = false
			if bool(pad["boost"]):
				wave_m -= 4.0
				gain += 90
				_add_float_text("CURRENT BOOST!", _player_screen() + Vector2(0, -120), Color("#b9edff"))
				pad["boost"] = false
				sound.play_event("boost")
			if bool(pad["pet"]):
				pets = mini(pets + 1, 8)
				celebration = 1.0
				_add_float_text("FRIEND +1", _player_screen() + Vector2(0, -99), Color("#fff1cc"))
				gain += 55
				pad["pet"] = false
				sound.play_event("friend")
			else:
				sound.play_event("land")
			run_hops += 1
			var daily_bonus: int = daily.on_landing(int(float(pad["m"])), collected_leaf, rescued_pet, combo + 1, absf(jump_end.x - jump_start.x) >= 80.0)
			if daily_bonus > 0:
				leaves += daily_bonus
				_add_float_text("GOAL +%d" % daily_bonus, _player_screen() + Vector2(0, -138), Color("#e6ffc5"))
				celebration = 1.0
			_save_progress()
			combo += 1
			if combo >= 3 and combo % 3 == 0:
				sound.play_event("combo")
			score += maxi(gain, 0) + maxi(combo - 2, 0) * 10
			highest_m = maxf(highest_m, player_m)
			_add_ripple(_player_screen() + Vector2(0, 10), 1.0)
			pad_impacts[jump_pad_id] = 1.0
			landing_impact = 1.0
			shake_strength = 4.2 if pets < 1 else 5.1
			impact_flash = 0.10 if pets < 1 else 0.15
			body_squash = 0.28
			_burst(_player_screen() + Vector2(0, 14), 11, "water")
			_burst(_player_screen() + Vector2(0, -5), 7, "spark")
			mode = MODE_PLAY
			if campaign_stage >= 0 and player_m >= float(chapters.chapter(campaign_stage)["target"]):
				_finish_chapter()
				return
			if wave_m >= player_m - 0.25:
				_die()
			return
	_die()

func _die() -> void:
	if mode == MODE_LOST:
		return
	mode = MODE_LOST
	# Keep the result visible; do not interrupt the end screen with a timer ad.
	monetization.on_run_finished()
	shake_strength = maxf(shake_strength, 7.0)
	jump_z = 0.0
	sound.play_event("lose")
	if score > best_score:
		best_score = score
	daily.on_finish(score)
	_save_progress()

func _on_rewarded_leaves(amount: int) -> void:
	if mode != MODE_LOST or rewarded_this_run or amount <= 0:
		return
	rewarded_this_run = true
	leaves += amount
	run_leaves += amount
	_save_progress()
	_add_float_text("+%d LEAVES" % amount, Vector2(270, 265), Color("#e6ffc5"))

func _is_unlocked(index: int) -> bool:
	return index >= 0 and index < SKIN_COSTS.size() and (unlocked_skins & (1 << index)) != 0

func _save_progress() -> void:
	var save := ConfigFile.new()
	save.load("user://jumpy_frog.cfg")
	save.set_value("progress", "best_score", best_score)
	save.set_value("progress", "muted", saved_muted)
	save.set_value("progress", "haptics", haptics_enabled)
	save.set_value("progress", "leaves", leaves)
	save.set_value("progress", "unlocked_skins", unlocked_skins)
	save.set_value("progress", "selected_skin", selected_skin)
	save.set_value("progress", "total_runs", total_runs)
	daily.write_to(save)
	chapters.write_to(save)
	save.save("user://jumpy_frog.cfg")

func _add_float_text(value: String, pos: Vector2, color: Color) -> void:
	if float_texts.size() >= 8:
		float_texts.pop_front()
	float_texts.append({"text": value, "pos": pos, "life": 1.0, "color": color})

func _add_ripple(pos: Vector2, size: float) -> void:
	if ripples.size() >= 12:
		ripples.pop_front()
	ripples.append({"pos": pos, "age": 0.0, "size": size})

func _burst(pos: Vector2, amount: int, kind: String = "spark") -> void:
	# Bounded pool prevents spikes when several awards occur during one landing.
	for i in range(mini(amount, maxi(0, 110 - particles.size()))):
		var angle := -PI + PI * float(i) / maxf(float(amount - 1), 1.0)
		var speed := rng.randf_range(45.0, 145.0)
		particles.append({
			"pos": pos + Vector2(rng.randf_range(-8, 8), rng.randf_range(-6, 6)),
			"velocity": Vector2(cos(angle) * speed, sin(angle) * speed),
			"life": rng.randf_range(0.58, 0.96),
			"kind": kind
		})

