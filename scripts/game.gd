extends Node2D
## A complete endless-runner prototype driven by touch (and mouse emulation).
const ART = preload("res://scripts/art.gd")
const AUDIO = preload("res://scripts/audio.gd")
const DAILY = preload("res://scripts/daily.gd")
const SAVE_STORE = preload("res://scripts/save_store.gd")
const RUN_REPORT = preload("res://scripts/run_report.gd")
const MONETIZATION = preload("res://scripts/monetization.gd")
const CHAPTERS = preload("res://scripts/chapters.gd")
const RIVER_SHADER = preload("res://shaders/river_surface.gdshader")
const PLATFORM_MOTION = preload("res://scripts/platform_motion.gd")
const PAD_DANGER = preload("res://scripts/pad_danger.gd")
const ROUTE_DIRECTOR = preload("res://scripts/route_director.gd")
const ENDLESS_PACING = preload("res://scripts/endless_pacing.gd")
const JUMP_FEEDBACK = preload("res://scripts/jump_feedback.gd")
const RIVER_FESTIVAL = preload("res://scripts/river_festival.gd")
const TIDE_REFUGE = preload("res://scripts/tide_refuge.gd")
const PRECISION_SPRINT = preload("res://scripts/precision_sprint.gd")
const DEVICE_DIAGNOSTICS = preload("res://scripts/device_diagnostics.gd")
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
const MODE_DIAGNOSTICS := 10
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
var last_danger_id := -99
var route_director := ROUTE_DIRECTOR.new()
var best_endless_m := 0
var distance_banner_seconds := 0.0
var distance_banner_mark := 0
var run_landmarks := 0
var precision_sprint := PRECISION_SPRINT.new()
# Lifetime challenge victories persist across new runs (no bonus currency).
var lifetime_challenge_wins := [0, 0, 0, 0]
var lifetime_best_challenge_streak := 0
var challenge_banner: Dictionary = {}
var challenge_banner_seconds := 0.0
var run_new_distance_record := false
var festival := RIVER_FESTIVAL.new()
var festival_banner_seconds := 0.0
var standing_pad_id := 0
var pets: int = 0
var score: int = 0
var best_score: int = 0
var combo: int = 0
var _active_touch_index := -1
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
var android_tones_enabled := false
var resume_mode := MODE_PLAY
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
# The chapter clock counts live gameplay only, not pause or menu time.
var chapter_elapsed := 0.0
var clear_new_time_record := false
var last_biome := 0
var biome_banner := 0.0
var monetization: Node
var rewarded_this_run := false
var run_hops := 0
var run_perfects := 0
var run_peak_combo := 0
var run_friends := 0
var run_new_record := false
var best_run_perfects := 0
var best_run_combo := 0
var best_run_friends := 0
var perfect_streak := 0
var jump_is_perfect := false
# Rare, free safety pickup. A charge saves one missed landing per collection.
var guardian_charge := false
# Crumbling pads appear only in the Golden Reeds and Stormy Rapids biomes.
# The clock runs while standing/aiming, not in midair or while paused.
const FRAGILE_LILY_DURATION := 5.5
const FRAGILE_GUARDIAN_GRACE := 3.0
var fragile_pad_id := -1
var fragile_seconds := 0.0
# Earned skill bonus: four precise landings trigger a brief FLOW window.
# Never purchases, never stacks indefinitely, and freezes on pause.
const FLOW_DURATION := 7.0
const FLOW_SCORE_MULTIPLIER := 1.35
const FLOW_WAVE_SCALE := 0.68
var flow_seconds := 0.0
var flow_triggers := 0
var flight_trail: Array[Dictionary] = []
var _trail_clock := 0.0
var run_leaves: int = 0
var body_tilt := 0.0
var body_squash := 0.0
var stack_sway := 0.0
var blink_clock := 2.2
var blink_amount := 0.0
var landing_impact := 0.0
# Short-lived, purely visual pulse for centered landings.
var precision_pulse := 0.0
var horizontal_velocity := 0.0
var previous_x := 270.0
var pad_impacts: Dictionary = {}
var celebration := 0.0
var float_texts: Array[Dictionary] = []
var ripples: Array[Dictionary] = []
var shake_strength := 0.0
var impact_flash := 0.0
var wave_warned := false
## Adaptive rendering quality never alters simulation or collision rules.
var graphics_quality := 2
var performance_sampler := DEVICE_DIAGNOSTICS.new()
var _frame_budget_accum := 0.0
var _frame_budget_sum := 0.0
var _frame_budget_samples := 0
var _quality_recovery_windows := 0
var _quality_downgrade_windows := 0
var river_shader_rect: ColorRect
var river_shader_material: ShaderMaterial
var _last_shader_quality := -1
var _last_shader_biome := -1
var _shader_frame_skip := 0

func _ready() -> void:
	# A 60 Hz cap avoids unnecessary GPU/CPU heat on 90/120 Hz handsets.
	# The simulation still uses real frame delta to preserve gameplay speed.
	if OS.has_feature("android"):
		Engine.max_fps = 60
	_initialize_river_shader()
	rng.randomize()
	sound = AUDIO.new()
	add_child(sound)
	monetization = MONETIZATION.new()
	add_child(monetization)
	monetization.rewarded_leaves_granted.connect(_on_rewarded_leaves)
	var save := ConfigFile.new()
	if SAVE_STORE.read_into(save) == OK:
		best_score = int(save.get_value("progress", "best_score", 0))
		saved_muted = bool(save.get_value("progress", "muted", false))
		android_tones_enabled = bool(save.get_value("progress", "android_system_tones", false))
		haptics_enabled = bool(save.get_value("progress", "haptics", true))
		leaves = maxi(0, int(save.get_value("progress", "leaves", 0)))
		unlocked_skins = maxi(1, int(save.get_value("progress", "unlocked_skins", 1))) & 255
		selected_skin = clampi(int(save.get_value("progress", "selected_skin", 0)), 0, 7)
		if not _is_unlocked(selected_skin):
			selected_skin = 0
		total_runs = maxi(0, int(save.get_value("progress", "total_runs", 0)))
		best_run_perfects = maxi(0, int(save.get_value("records", "perfects", 0)))
		best_run_combo = maxi(0, int(save.get_value("records", "combo", 0)))
		best_run_friends = maxi(0, int(save.get_value("records", "friends", 0)))
		best_endless_m = maxi(0, int(save.get_value("records", "best_endless_m", 0)))
		lifetime_best_challenge_streak = clampi(int(save.get_value("records", "best_challenge_streak", 0)), 0, 100000000)
		# Safely upgrade old saves; reject corrupt and negative counters.
		var raw_mastery = save.get_value("records", "challenge_wins", [0, 0, 0, 0])
		if raw_mastery is Array and raw_mastery.size() == 4:
			for i in range(4):
				lifetime_challenge_wins[i] = clampi(int(raw_mastery[i]), 0, 100000000)
	daily.load_from(save)
	chapters.load_from(save)
	muted = saved_muted or OS.has_feature("android")
	sound.set_muted(muted)
	sound.set_haptics(haptics_enabled)
	if OS.has_feature("android") and android_tones_enabled:
		# Fail closed if JNI/system tone output cannot be constructed.
		android_tones_enabled = sound.set_android_system_tones(true)
	_reset_game()

func _initialize_river_shader() -> void:
	river_shader_rect = ColorRect.new()
	river_shader_rect.name = "RiverSurfaceCaustics"
	# Crop GPU work to the river corridor: banks and UI stay unshaded.
	river_shader_rect.position = Vector2(76.0, 0.0)
	river_shader_rect.size = Vector2(W - 152.0, H)
	river_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	river_shader_rect.z_index = 1
	river_shader_rect.visible = false
	river_shader_material = ShaderMaterial.new()
	river_shader_material.shader = RIVER_SHADER
	river_shader_rect.material = river_shader_material
	add_child(river_shader_rect)

func _update_graphics_quality(frame_delta: float) -> void:
	if mode not in [MODE_PLAY, MODE_AIM, MODE_FLY] or frame_delta <= 0.0:
		return
	# Ignore background/app-switch stalls: these are not GPU bottlenecks.
	if frame_delta > 0.12:
		return
	_frame_budget_accum += frame_delta
	_frame_budget_sum += frame_delta
	_frame_budget_samples += 1
	if _frame_budget_accum < 2.0:
		return
	var average: float = _frame_budget_sum / maxf(float(_frame_budget_samples), 1.0)
	_frame_budget_accum = 0.0
	_frame_budget_sum = 0.0
	_frame_budget_samples = 0
	if average > 0.025:
		_quality_downgrade_windows += 1
		_quality_recovery_windows = 0
		if _quality_downgrade_windows >= 2:
			graphics_quality = maxi(graphics_quality - 1, 0)
			_quality_downgrade_windows = 0
	elif average < 0.018:
		_quality_recovery_windows += 1
		_quality_downgrade_windows = 0
		if _quality_recovery_windows >= 5:
			graphics_quality = mini(graphics_quality + 1, 2)
			_quality_recovery_windows = 0
	else:
		_quality_downgrade_windows = 0
		_quality_recovery_windows = 0

func _reset_game() -> void:
	_active_touch_index = -1
	mode = MODE_TITLE
	resume_mode = MODE_PLAY
	campaign_stage = -1
	clear_medal = 0
	clear_reward = 0
	chapter_elapsed = 0.0
	clear_new_time_record = false
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
	last_danger_id = -99
	distance_banner_seconds = 0.0
	distance_banner_mark = 0
	run_landmarks = 0
	route_director.reset()
	festival.reset()
	precision_sprint.reset()
	challenge_banner.clear()
	challenge_banner_seconds = 0.0
	festival_banner_seconds = 0.0
	standing_pad_id = 0
	pets = 0
	score = 0
	combo = 0
	run_leaves = 0
	run_hops = 0
	run_perfects = 0
	run_peak_combo = 0
	run_friends = 0
	run_new_record = false
	run_new_distance_record = false
	perfect_streak = 0
	jump_is_perfect = false
	guardian_charge = false
	fragile_pad_id = -1
	fragile_seconds = 0.0
	flow_seconds = 0.0
	flow_triggers = 0
	flight_trail.clear()
	_trail_clock = 0.0
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
	precision_pulse = 0.0
	horizontal_velocity = 0.0
	previous_x = player_x
	pads.append({"id":0, "x":270.0, "m":0.0, "r":55.0, "kind":0, "coin":false, "pet":false})
	_generate_pads()

func _generate_pads() -> void:
	while last_generated_m < player_m + 190.0:
		var biome := chapters.biome_at(last_generated_m, campaign_stage)
		var modifier: Dictionary = chapters.chapter(biome)
		var progression := minf(highest_m / 1750.0, 1.0) if campaign_stage == -1 else 0.0
		# Each chapter has its own rhythmic hop spacing, not just a recolored river.
		var gap_min: float = [14.6, 15.4, 16.0, 16.8, 17.4, 18.0][biome]
		var gap_max: float = [19.3, 20.3, 21.0, 21.6, 22.1, 22.6][biome]
		var festival_info: Dictionary = festival.decorate_primary(next_pad_id, rng) if campaign_stage == -1 else {"festival_group": -1, "festival_step": -1}
		var festival_step: int = int(festival_info["festival_step"])
		var gap := rng.randf_range(gap_min, gap_max)
		# The three rare celebration hops are a gentler, visually distinct
		# breathing space, not a surprise difficulty spike.
		if festival_step >= 0:
			gap *= 0.91
		last_generated_m += gap
		var lateral: float = float(modifier["drift"])
		var dx := rng.randf_range(-lateral, lateral)
		# Four shuffled motifs in Endless, while campaign and daily keep
		# their proven layouts, reachability and seeded daily generation.
		if campaign_stage == -1:
			dx = route_director.lateral_delta(next_pad_id, dx, lateral, rng, festival_step >= 0)
		else:
			if biome in [3, 5] and next_pad_id % 4 == 0:
				dx = (lateral * 0.85) * (-1.0 if next_pad_id % 8 == 0 else 1.0)
			var phrase_step := (next_pad_id - 1) % 16
			if phrase_step in [0, 1]:
				dx *= 0.28
			elif phrase_step in [5, 6, 7]:
				dx = lateral * (0.67 if phrase_step % 2 == 1 else -0.67)
		last_pad_x = clampf(last_pad_x + dx, 116.0, 421.0)
		var ident := next_pad_id
		next_pad_id += 1
		# Biome-specific lily silhouettes make each stage visually recognizable.
		var kind: int = (rng.randi_range(0, 3) + biome) % 4
		var radius_scale := float(modifier["radius"]) - progression * 0.08
		var motion := PLATFORM_MOTION.create_fields(biome, ident)
		if festival_step >= 0:
			motion["moving"] = false
		# Harmony lilies are optional precision objectives. Keep the standard
		# landing collision exactly as before; no forced perfect aim or paywall.
		# Exclude moving / fragile / Guardian pads to keep the objective readable.
		var harmony := ident >= 6 and ident % 8 == 6 and ident % 13 != 0
		harmony = harmony and festival_step < 0 and not bool(motion["moving"])
		harmony = harmony and not (biome in [2, 5] and ident % 7 == 5)
		# Rare red water sprites make some landings temporarily dangerous.
		# Never put two close together, overlap a timed/moving collectible, or
		# force a hazard in the tutorial. Other reachable pads remain safe.
		var dangerous := campaign_stage == -1 and ident >= 8 and ident - last_danger_id >= 3
		dangerous = dangerous and festival_step < 0 and not bool(motion["moving"]) and not harmony
		dangerous = dangerous and ident % 13 != 0 and not (biome in [2, 5] and ident % 7 == 5)
		dangerous = dangerous and rng.randf() < ENDLESS_PACING.hazard_probability(last_generated_m)
		var danger_phase := rng.randf_range(0.0, PAD_DANGER.CYCLE_SECONDS) if dangerous else 0.0
		if dangerous:
			last_danger_id = ident
		pads.append({
			"id": ident,
			"x": last_pad_x,
			"m": last_generated_m,
			"r": 57.0 if festival_step >= 0 else clampf(rng.randf_range(43.0, 53.0) * radius_scale, 37.0, 62.0),
			"kind": kind,
			"coin": festival_step < 0 and ident % 2 == 0,
			"pet": festival_step < 0 and ident % 3 == 0,
			"boost": festival_step < 0 and ident % 7 == 0 and biome >= 1,
			"guardian": festival_step < 0 and ident % 13 == 0,
			"harmony": harmony,
			"festival_group": int(festival_info["festival_group"]),
			"festival_step": festival_step,
			"festival_collected": false,
			"danger": dangerous,
			"danger_phase": danger_phase,
			"moving": bool(motion["moving"]),
			"motion_speed": float(motion["motion_speed"]),
			"motion_amplitude": float(motion["motion_amplitude"]),
			# A timed hazard is always clearly marked; it never changes
			# generated collision size, and never coincides with a Guardian.
			"fragile": festival_step < 0 and biome in [2, 5] and ident > 4 and ident % 7 == 5 and ident % 13 != 0
		})
		# Two distinct, occasional optional lanes keep Endless decisions
		# meaningful: GOLD yields currency, TIDE REFUGE buys time against
		# the pursuing wave. Every fork retains its ordinary primary lily.
		# They have mutually exclusive id schedules and never obstruct play.
		var split_path := campaign_stage == -1 and ident >= 9 and ident % 12 == 9
		split_path = split_path and festival_step < 0 and not dangerous and not bool(motion["moving"])
		split_path = split_path and not harmony and ident % 13 != 0
		split_path = split_path and not (biome in [2, 5] and ident % 7 == 5)
		var tide_path: bool = TIDE_REFUGE.eligible(ident, campaign_stage == -1, festival_step,
			dangerous, bool(motion["moving"]), harmony,
			bool(pads.back().get("fragile", false)), ident % 13 == 0)
		if split_path or tide_path:
			var optional_x := TIDE_REFUGE.branch_x(last_pad_x, rng) if tide_path else clampf(
				last_pad_x + (-1.0 if last_pad_x > 270.0 else 1.0) * rng.randf_range(88.0, 104.0),
				95.0, 445.0)
			if TIDE_REFUGE.is_clear_fork(last_pad_x, optional_x):
				pads.append({
					"id": 1000000 + ident,
					"x": optional_x,
					"m": last_generated_m,
					"r": TIDE_REFUGE.ROUTE_RADIUS if tide_path else 37.0,
					"kind": 3 if tide_path else 1,
					"coin": false,
					"pet": false,
					"boost": false,
					"guardian": false,
					"harmony": false,
					"moving": false,
					"fragile": false,
					"danger": false,
					"branch_bonus": split_path,
					"tide_refuge": tide_path
				})

func _process(delta: float) -> void:
	performance_sampler.record(delta, mode in [MODE_PLAY, MODE_AIM, MODE_FLY])
	_update_graphics_quality(delta)
	# Raw frame delta preserves an honest time trial even when physics caps stalls.
	if campaign_stage >= 0 and mode in [MODE_PLAY, MODE_AIM, MODE_FLY]:
		chapter_elapsed += maxf(0.0, delta)
	delta = minf(delta, 0.08)
	if river_shader_rect != null:
		river_shader_rect.visible = mode in [MODE_PLAY, MODE_AIM, MODE_FLY] and graphics_quality > 0
		if graphics_quality != _last_shader_quality:
			river_shader_material.set_shader_parameter("strength", 0.48 if graphics_quality == 2 else (0.26 if graphics_quality == 1 else 0.0))
			_last_shader_quality = graphics_quality
		# The color only changes at chapter boundaries, not on every frame.
		var shader_biome: int = chapters.biome_at(player_m, campaign_stage)
		if shader_biome != _last_shader_biome:
			var water_colors := [
				Color("#b8f9e5"), Color("#b0f4e0"), Color("#f9e7bb"),
				Color("#c5f2f5"), Color("#d7e3ff"), Color("#ffe1c9")
			]
			river_shader_material.set_shader_parameter("highlight_color", water_colors[shader_biome])
			river_shader_material.set_shader_parameter("current_speed", 0.82 + float(shader_biome) * 0.11)
			_last_shader_biome = shader_biome
	if mode in [MODE_PAUSED, MODE_DIAGNOSTICS]:
		queue_redraw()
		return
	clock += delta
	# Stay attached to a shifting pad until takeoff. This shared world-time
	# position also powers the drawn platform and the landing prediction.
	if mode in [MODE_PLAY, MODE_AIM]:
		for standing in pads:
			if int(standing["id"]) == standing_pad_id:
				if bool(standing.get("moving", false)):
					player_x = PLATFORM_MOTION.x_at(standing, clock)
				break
	biome_banner = maxf(0.0, biome_banner - delta)
	festival_banner_seconds = maxf(0.0, festival_banner_seconds - delta)
	distance_banner_seconds = maxf(0.0, distance_banner_seconds - delta)
	challenge_banner_seconds = maxf(0.0, challenge_banner_seconds - delta)
	var current_biome := chapters.biome_at(player_m, campaign_stage)
	if current_biome != last_biome:
		last_biome = current_biome
		sound.set_biome(current_biome)
		biome_banner = 2.2
		if mode in [MODE_PLAY, MODE_AIM, MODE_FLY]:
			sound.play_event("combo")
	shake_strength = maxf(0.0, shake_strength - delta * 21.0)
	# The platform cracks only while the player can choose to jump.
	# Menus, app interruptions and an already launched jump are safe.
	if mode in [MODE_PLAY, MODE_AIM] and fragile_pad_id >= 0:
		fragile_seconds = maxf(0.0, fragile_seconds - delta)
		if fragile_seconds <= 0.0:
			if guardian_charge:
				guardian_charge = false
				fragile_seconds = FRAGILE_GUARDIAN_GRACE
				impact_flash = 0.24
				shake_strength = maxf(shake_strength, 6.0)
				_add_float_text("GUARDIAN SAVED YOU!", _player_screen() + Vector2(0, -116), Color("#fff4b9"))
				_burst(_player_screen(), 14, "spark")
				sound.play_event("boost")
			else:
				_add_ripple(_player_screen(), 1.6)
				_burst(_player_screen(), 19, "water")
				sound.play_event("splash")
				_die()
	impact_flash = maxf(0.0, impact_flash - delta * 1.6)
	if mode in [MODE_PLAY, MODE_AIM, MODE_FLY]:
		var biome_modifier: Dictionary = chapters.chapter(chapters.biome_at(player_m, campaign_stage))
		var pressure := 2.4 + minf(highest_m * 0.013, 4.5) + float(biome_modifier["wave"])
		# Skill reward gives breathing room but never freezes the danger.
		if flow_seconds > 0.0:
			pressure *= FLOW_WAVE_SCALE
			flow_seconds = maxf(flow_seconds - delta, 0.0)
		# A rare festival is a restful interlude, not another timed obstacle.
		if campaign_stage == -1 and festival.progress > 0:
			pressure *= 0.85
		wave_m += delta * pressure
		if wave_m > player_m - 14.0 and not wave_warned:
			wave_warned = true
			sound.play_event("warning")
		elif wave_m < player_m - 22.0:
			wave_warned = false
		if wave_m >= player_m - 0.25 and mode != MODE_FLY:
			_die()
	for i in range(flight_trail.size() - 1, -1, -1):
		flight_trail[i]["age"] = float(flight_trail[i]["age"]) + delta
		if float(flight_trail[i]["age"]) > 0.34:
			flight_trail.remove_at(i)
	if mode == MODE_FLY:
		_trail_clock += delta
		if _trail_clock >= (0.045 if graphics_quality >= 2 else 0.075):
			_trail_clock = 0.0
			if flight_trail.size() >= 9:
				flight_trail.pop_front()
			flight_trail.append({"x": player_x, "m": player_m, "z": jump_z, "age": 0.0})
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
	precision_pulse = maxf(0.0, precision_pulse - delta * 2.3)
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
	# Look ahead while aiming and flying without altering the world simulation.
	var cam_target := player_m + (4.0 if mode in [MODE_AIM, MODE_FLY] else 0.0)
	cam_m = lerpf(cam_m, cam_target, 1.0 - exp(-delta * 4.7))
	# Reclaim every platform behind the camera after large frame jumps,
	# without allowing the procedural array to grow indefinitely.
	while pads.size() > 1 and float(pads[0]["m"]) < cam_m - 75.0:
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
	var aim_perfect := false
	var aim_danger_seconds := 0.0
	if mode == MODE_AIM:
		var pad := _landing_target(aim_x, aim_m)
		if not pad.is_empty():
			preview = Vector2(_predicted_pad_x(pad), PLAYER_ANCHOR - (float(pad["m"]) - cam_m) * PX_PER_M)
			aim_valid = true
			aim_perfect = JUMP_FEEDBACK.is_perfect(pad, aim_x, aim_m, _predicted_pad_x(pad), PX_PER_M)
		else:
			var warning := _danger_aim_warning(aim_x, aim_m)
			if not warning.is_empty():
				var candidate: Dictionary = warning["pad"]
				preview = Vector2(_predicted_pad_x(candidate), PLAYER_ANCHOR - (float(candidate["m"]) - cam_m) * PX_PER_M)
				aim_danger_seconds = float(warning["wait"])

	var shake := Vector2(sin(clock * 89.0) * shake_strength, sin(clock * 113.0 + 1.1) * shake_strength * 0.6)
	ART.scene(self, clock, cam_m, pads, at, jump_z, pets, wave_m, mode == MODE_AIM, preview, aim_valid, mode, score, best_score, combo, particles, int(highest_m), muted, selected_skin, leaves, unlocked_skins, SKIN_COSTS, run_leaves, daily, monetization, rewarded_this_run, wardrobe_page, body_tilt, body_squash + JUMP_FEEDBACK.windup(aim_m, player_m) * 0.16 if mode == MODE_AIM else body_squash, stack_sway, blink_amount, landing_impact, pad_impacts, celebration, float_texts, ripples, shake, impact_flash, chapters, campaign_stage, biome_banner, clear_medal, clear_reward, haptics_enabled, android_tones_enabled, graphics_quality, guardian_charge, flight_trail, flow_seconds, fragile_pad_id, fragile_seconds, precision_pulse, run_hops, run_perfects, run_peak_combo, run_friends, run_new_record, RUN_REPORT.grade(run_hops, run_perfects, run_friends, flow_triggers) if mode == MODE_LOST else "", RUN_REPORT.next_weekly_goal(daily) if mode == MODE_LOST else {}, performance_sampler.snapshot() if mode == MODE_DIAGNOSTICS else {}, aim_danger_seconds, festival.progress, festival_banner_seconds, perfect_streak, best_endless_m, distance_banner_mark, distance_banner_seconds, aim_perfect,
		precision_sprint.snapshot(run_hops + 1), challenge_banner, challenge_banner_seconds, lifetime_challenge_wins, lifetime_best_challenge_streak,
		chapter_elapsed, clear_new_time_record)

func _player_screen() -> Vector2:
	return Vector2(player_x, PLAYER_ANCHOR - (player_m - cam_m) * PX_PER_M)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _active_touch_index >= 0:
				return # A second finger must never steal or cancel an aim.
			_down(touch.position)
			if mode == MODE_AIM:
				_active_touch_index = touch.index
		elif _active_touch_index == touch.index:
			_active_touch_index = -1
			_up(touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _active_touch_index:
			_move(drag.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_R, KEY_SPACE, KEY_ENTER] and mode == MODE_LOST:
			_reset_game()
		elif event.keycode == KEY_ESCAPE:
			if mode == MODE_DIAGNOSTICS:
				mode = MODE_PAUSED
			elif mode in [MODE_WARDROBE, MODE_GOALS, MODE_CHAPTERS, MODE_CLEAR]:
				mode = MODE_TITLE
			elif mode == MODE_PAUSED:
				_resume_game()
			elif mode in [MODE_AIM, MODE_PLAY, MODE_FLY]:
				_pause_game()

func _pause_game() -> void:
	if mode not in [MODE_PLAY, MODE_AIM, MODE_FLY]:
		return
	# Never force an interrupted flight into the grounded PLAY state.
	resume_mode = MODE_PLAY if mode == MODE_AIM else mode
	_active_touch_index = -1
	mode = MODE_PAUSED
	sound.set_paused(true)
	_save_progress()

func _resume_game() -> void:
	if mode != MODE_PAUSED:
		return
	mode = resume_mode
	sound.set_paused(false)

func _notification(what: int) -> void:
	# Android app switch / incoming calls: freeze the river and keep the run.
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if mode in [MODE_PLAY, MODE_AIM, MODE_FLY]:
			_pause_game()
		elif is_node_ready():
			_save_progress()

func _down(pos: Vector2) -> void:
	if mode == MODE_DIAGNOSTICS:
		if Rect2(100, 716, 340, 74).has_point(pos):
			mode = MODE_PAUSED
		return
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
		if campaign_stage == -2:
			if Rect2(72, 633, 195, 66).has_point(pos):
				_start_daily_river()
			elif Rect2(285, 633, 190, 66).has_point(pos):
				_reset_game()
			return
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
		if Rect2(100, 831, 340, 55).has_point(pos):
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
		if Rect2(108, 374, 324, 60).has_point(pos):
			mode = MODE_DIAGNOSTICS
			return
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
			_resume_game()
		elif Rect2(108, 544, 324, 66).has_point(pos):
			if OS.has_feature("android"):
				if pos.x < 270.0:
					android_tones_enabled = sound.set_android_system_tones(not android_tones_enabled)
				else:
					haptics_enabled = not haptics_enabled
					sound.set_haptics(haptics_enabled)
			else:
				saved_muted = not saved_muted
				muted = saved_muted
				sound.set_muted(muted)
			_save_progress()
		return
	if mode in [MODE_PLAY, MODE_AIM] and Rect2(473, 78, 63, 59).has_point(pos):
		_pause_game()
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
		if retry_chapter == -2:
			_start_daily_river()
			return
		if retry_chapter >= 0:
			_start_chapter(retry_chapter)
			return
		_reset_game()
		mode = MODE_PLAY
		total_runs += 1
		daily.begin_run()
		_save_progress()
	elif mode == MODE_TITLE:
		if Rect2(281, 470, 197, 62).has_point(pos):
			_start_daily_river()
			return
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

func _start_daily_river() -> void:
	_reset_game()
	campaign_stage = -2
	daily.refresh_day()
	daily.start_river()
	# Reset RNG after the generic initialization so this day's lily route,
	# bonuses and animal placements are reproducible on every attempt.
	rng.seed = daily.river_seed()
	pads.resize(1)
	last_generated_m = 0.0
	last_pad_x = 270.0
	next_pad_id = 1
	_generate_pads()
	mode = MODE_PLAY
	total_runs += 1
	daily.begin_run()
	biome_banner = 2.2
	_save_progress()
	queue_redraw()

func _finish_daily_river() -> void:
	if campaign_stage != -2 or mode != MODE_PLAY:
		return
	clear_medal = 0
	clear_reward = daily.finish_river(score)
	leaves += clear_reward
	run_leaves += clear_reward
	mode = MODE_CLEAR
	monetization.on_run_finished()
	daily.on_finish(score)
	celebration = 1.0
	impact_flash = 0.42
	sound.play_event("victory")
	if score > best_score:
		best_score = score
	_save_progress()

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
	clear_new_time_record = chapters.record_time(campaign_stage, chapter_elapsed)
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

func _duration_to(target_m: float) -> float:
	return clampf(0.40 + (target_m - player_m) * 0.012, 0.48, 0.87)

func _predicted_pad_x(pad: Dictionary) -> float:
	return PLATFORM_MOTION.x_at(pad, clock + _duration_to(float(pad["m"])))

func _danger_aim_warning(desired_x: float, desired_m: float) -> Dictionary:
	# The label uses the same future-time and elliptical collision calculation
	# as _landing_target(), so the player is never shown a stale safe cue.
	for candidate in pads:
		if not bool(candidate.get("danger", false)) or float(candidate["m"]) <= player_m + 3.0:
			continue
		var duration := _duration_to(float(candidate["m"]))
		if not PAD_DANGER.is_active(candidate, clock + duration):
			continue
		var dx: float = _predicted_pad_x(candidate) - desired_x
		var dy: float = (float(candidate["m"]) - desired_m) * PX_PER_M
		var rx: float = float(candidate["r"]) + 14.0
		var ry: float = float(candidate["r"]) * 0.78 + 14.0
		if Vector2(dx / rx, dy / ry).length_squared() <= 1.0:
			return {"pad": candidate, "wait": PAD_DANGER.seconds_until_safe(candidate, clock + duration)}
	return {}


## Preview and flight share this exact landing rule, so a green guide cannot miss.
func _landing_target(desired_x: float, desired_m: float) -> Dictionary:
	var winner: Dictionary = {}
	if desired_m <= player_m + 3.0:
		return winner
	var closest := INF
	for pad in pads:
		if float(pad["m"]) <= player_m + 3.0:
			continue
		# Shared future-time warning and collision rule: a red landing guide
		# cannot incorrectly promise safety at the predicted landing time.
		if PAD_DANGER.is_active(pad, clock + _duration_to(float(pad["m"]))):
			continue
		var radius: float = float(pad["r"])
		var delta := Vector2(_predicted_pad_x(pad) - desired_x, (float(pad["m"]) - desired_m) * PX_PER_M)
		var normalized := Vector2(delta.x / (radius + 14.0), delta.y / (radius * 0.78 + 14.0))
		var d := normalized.length()
		if d <= 1.0 and d < closest:
			winner = pad
			closest = d
	return winner

func _start_jump() -> void:
	var target := _landing_target(aim_x, aim_m)
	jump_pad_id = -1 if target.is_empty() else int(target["id"])
	jump_is_perfect = false
	if not target.is_empty():
		jump_is_perfect = JUMP_FEEDBACK.is_perfect(target, aim_x, aim_m, _predicted_pad_x(target), PX_PER_M)
	jump_start = Vector2(player_x, player_m)
	jump_end = Vector2(aim_x, aim_m)
	if not target.is_empty():
		# Subtle magnetism produces consistent, legible landings on touchscreens.
		jump_end = Vector2(_predicted_pad_x(target), float(target["m"]))
	jump_elapsed = 0.0
	_trail_clock = 0.0
	flight_trail.clear()
	jump_duration = _duration_to(jump_end.y)
	body_squash = 0.23
	# A bounded takeoff pulse gives tactile weight without altering physics.
	_add_ripple(_player_screen() + Vector2(0, 12), 0.45)
	if graphics_quality > 0:
		_burst(_player_screen() + Vector2(0, 10), 5 if graphics_quality == 1 else 8, "spark")
	mode = MODE_FLY
	sound.play_event("jump")

func _finish_jump() -> void:
	jump_z = 0.0
	if jump_pad_id == -1:
		if guardian_charge:
			_rescue_from_splash()
			return
		perfect_streak = 0
		shake_strength = 11.0
		impact_flash = 0.20
		sound.play_event("splash")
		_add_ripple(_player_screen(), 1.5)
		_burst(_player_screen(), 22, "water")
		_die()
		return
	for pad in pads:
		if int(pad["id"]) == jump_pad_id:
			standing_pad_id = jump_pad_id
			# Align with actual moving-pad position at touchdown. At 60 FPS
			# the predicted and actual centers differ by well under one pixel.
			player_x = PLATFORM_MOTION.x_at(pad, clock)
			fragile_pad_id = int(pad["id"]) if bool(pad.get("fragile", false)) else -1
			fragile_seconds = FRAGILE_LILY_DURATION if fragile_pad_id >= 0 else 0.0
			if fragile_pad_id >= 0:
				_add_float_text("FRAGILE LILY - KEEP MOVING!", _player_screen() + Vector2(0, -157), Color("#ffdda2"))
				sound.play_event("warning")
			var festival_complete: bool = festival.land(pad) if campaign_stage == -1 else false
			if int(pad.get("festival_step", -1)) >= 0:
				_add_float_text("FIREFLY %d/3" % (int(pad["festival_step"]) + 1), _player_screen() + Vector2(0, -142), Color("#e8d7ff"))
				_burst(_player_screen() + Vector2(0, -10), 8, "spark")
			var previous_height := highest_m
			var new_height: float = float(pad["m"])
			var distance_mark := ENDLESS_PACING.crossed_landmark(previous_height, new_height) if campaign_stage == -1 else 0
			var gain := maxi(12, int((new_height - highest_m) * 13.0))
			if distance_mark > 0:
				run_landmarks += 1
				distance_banner_mark = distance_mark
				distance_banner_seconds = 2.5
				leaves += ENDLESS_PACING.LANDMARK_LEAVES
				run_leaves += ENDLESS_PACING.LANDMARK_LEAVES
				gain += ENDLESS_PACING.LANDMARK_SCORE
				wave_m -= ENDLESS_PACING.LANDMARK_WAVE_RELIEF
				celebration = 1.0
				precision_pulse = 1.25
				impact_flash = maxf(impact_flash, 0.22)
				_add_float_text("%d m! +2 LEAVES" % distance_mark, _player_screen() + Vector2(0, -179), Color("#f3f9bc"))
				_burst(_player_screen() + Vector2(0, -17), 24, "spark")
				sound.play_event("victory")
			if festival_complete:
				leaves += RIVER_FESTIVAL.LEAVES
				run_leaves += RIVER_FESTIVAL.LEAVES
				gain += RIVER_FESTIVAL.SCORE
				wave_m -= 5.0
				festival_banner_seconds = 2.4
				celebration = 1.0
				precision_pulse = 1.25
				shake_strength = maxf(shake_strength, 6.0)
				_add_float_text("FESTIVAL +3 LEAVES!", _player_screen() + Vector2(0, -182), Color("#fff4bb"))
				_burst(_player_screen() + Vector2(0, -14), 24, "spark")
				sound.play_event("victory")
			if jump_is_perfect:
				run_perfects += 1
				precision_pulse = 1.0
				perfect_streak += 1
				gain += 35 + mini(perfect_streak, 12) * 4
				_add_float_text("PERFECT x%d!" % perfect_streak, _player_screen() + Vector2(0, -120), Color("#fff3ac"))
				if perfect_streak % 4 == 0:
					flow_seconds = FLOW_DURATION
					flow_triggers += 1
					celebration = 1.0
					_add_float_text("FLOW RUSH!", _player_screen() + Vector2(0, -174), Color("#b5faff"))
					_burst(_player_screen() + Vector2(0, -10), 17, "spark")
					sound.play_event("combo")
				if perfect_streak % 5 == 0:
					leaves += 1
					run_leaves += 1
					_add_float_text("STREAK +1 LEAF", _player_screen() + Vector2(0, -159), Color("#e7fbb4"))
					sound.play_event("combo")
			else:
				perfect_streak = 0
			# A Harmony blossom is resolved exactly once, even when a player
			# lands off-center or revisits an already used lily.
			if bool(pad.get("harmony", false)):
				pad["harmony"] = false
				if jump_is_perfect:
					gain += 160
					leaves += 1
					run_leaves += 1
					celebration = 1.0
					precision_pulse = 1.25
					_add_float_text("HARMONY BLOOM! +1 LEAF", _player_screen() + Vector2(0, -170), Color("#fff0ba"))
					_burst(_player_screen() + Vector2(0, -16), 15, "spark")
					sound.play_event("victory")
			var collected_leaf: bool = bool(pad["coin"])
			var rescued_pet: bool = bool(pad["pet"])
			if bool(pad["coin"]):
				leaves += 1
				run_leaves += 1
				# Persist once with the completed landing and all mission payouts.
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
			if bool(pad.get("guardian", false)):
				guardian_charge = true
				gain += 180
				wave_m -= 5.0
				pad["guardian"] = false
				celebration = 1.0
				_add_float_text("GUARDIAN READY!", _player_screen() + Vector2(0, -153), Color("#fff3b9"))
				_burst(_player_screen() + Vector2(0, -16), 15, "spark")
				sound.play_event("victory")
			if TIDE_REFUGE.claim(pad):
				# Relief, not money: a second valid route with a different
				# strategic benefit. Never retrigger on the same lily.
				wave_m -= TIDE_REFUGE.WAVE_RELIEF_METERS
				gain += TIDE_REFUGE.SCORE_BONUS
				celebration = maxf(celebration, 0.75)
				precision_pulse = maxf(precision_pulse, 0.8)
				_add_float_text("TIDE REFUGE! +9m BREATHING ROOM",
					_player_screen() + Vector2(0, -158), Color("#b4fff0"))
				if graphics_quality > 0:
					_burst(_player_screen() + Vector2(0, -12), 9 if graphics_quality == 1 else 14, "spark")
				sound.play_event("boost")
			if bool(pad.get("branch_bonus", false)):
				pad["branch_bonus"] = false
				leaves += 2
				run_leaves += 2
				gain += 225
				celebration = 1.0
				precision_pulse = 1.25
				_add_float_text("GOLD ROUTE! +2 LEAVES", _player_screen() + Vector2(0, -152), Color("#fff6b0"))
				_burst(_player_screen() + Vector2(0, -12), 20, "spark")
				sound.play_event("victory")
			if bool(pad["pet"]):
				run_friends += 1
				pets = mini(pets + 1, 8)
				celebration = 1.0
				_add_float_text("FRIEND +1", _player_screen() + Vector2(0, -99), Color("#fff1cc"))
				gain += 55
				pad["pet"] = false
				sound.play_event("friend")
			else:
				sound.play_event("land")
			# Optional Endless challenge director counts only genuine landing
			# events. Collectible flags are captured BEFORE being consumed.
			# No new obstacles, timers or forced detours are introduced.
			if campaign_stage == -1:
				var challenge: Dictionary = precision_sprint.on_landing(
					run_hops + 1, jump_is_perfect, collected_leaf,
					float(pad["m"]) - jump_start.y, rescued_pet,
					int(pad.get("festival_step", -1)) < 0)
				if bool(challenge.get("won", false)):
					var mastered_kind := int(challenge.get("type", -1))
					if mastered_kind >= 0 and mastered_kind < 4:
						lifetime_challenge_wins[mastered_kind] = mini(100000000, lifetime_challenge_wins[mastered_kind] + 1)
					lifetime_best_challenge_streak = maxi(lifetime_best_challenge_streak,
						mini(100000000, int(challenge.get("win_streak", 0))))
					leaves += int(challenge["leaves"])
					run_leaves += int(challenge["leaves"])
					gain += int(challenge["score"])
					celebration = 1.0
					precision_pulse = maxf(precision_pulse, 1.0)
					challenge_banner = challenge
					challenge_banner_seconds = 2.3
					_add_float_text("%s +%d LEAVES!" % [String(challenge["title"]), int(challenge["leaves"])],
						_player_screen() + Vector2(0, -189), Color("#fff1b1"))
					if int(challenge.get("streak_bonus", 0)) > 0:
						_add_float_text("CHALLENGE STREAK x%d! +1 LEAF" % int(challenge["win_streak"]),
							_player_screen() + Vector2(0, -205), Color("#fff1a0"))
					if graphics_quality > 0:
						_burst(_player_screen() + Vector2(0, -14), 12 if graphics_quality == 1 else 18, "spark")
					sound.play_event("victory")
				elif challenge.has("won") and not bool(challenge["won"]):
					challenge_banner = challenge
					challenge_banner_seconds = 1.5
				elif bool(challenge.get("started", false)):
					challenge_banner = {"started": true, "title": precision_sprint.title(),
						"level": precision_sprint.level}
					challenge_banner_seconds = 1.25
			run_hops += 1
			var daily_bonus: int = daily.on_landing(int(float(pad["m"])), collected_leaf, rescued_pet, combo + 1, absf(jump_end.x - jump_start.x) >= 80.0, jump_is_perfect)
			if daily_bonus > 0:
				leaves += daily_bonus
				_add_float_text("GOAL +%d" % daily_bonus, _player_screen() + Vector2(0, -138), Color("#e6ffc5"))
				celebration = 1.0
			combo += 1
			run_peak_combo = maxi(run_peak_combo, combo)
			if combo >= 3 and combo % 3 == 0:
				sound.play_event("combo")
			var landing_points := maxi(gain, 0) + maxi(combo - 2, 0) * 10
			if flow_seconds > 0.0:
				landing_points = roundi(float(landing_points) * FLOW_SCORE_MULTIPLIER)
			score += landing_points
			highest_m = maxf(highest_m, player_m)
			if campaign_stage == -1 and int(player_m) > best_endless_m:
				best_endless_m = int(player_m)
				run_new_distance_record = true
			_save_progress()
			_add_ripple(_player_screen() + Vector2(0, 10), 1.0)
			pad_impacts[jump_pad_id] = 1.0
			landing_impact = 1.0
			shake_strength = 4.2 if pets < 1 else 5.1
			impact_flash = 0.10 if pets < 1 else 0.15
			body_squash = 0.28
			_burst(_player_screen() + Vector2(0, 14), 11, "water")
			_burst(_player_screen() + Vector2(0, -5), 7, "spark")
			mode = MODE_PLAY
			if campaign_stage == -2 and player_m >= daily.RIVER_TARGET:
				_finish_daily_river()
				return
			if campaign_stage >= 0 and player_m >= float(chapters.chapter(campaign_stage)["target"]):
				_finish_chapter()
				return
			if wave_m >= player_m - 0.25:
				_die()
			return
	_die()

func _rescue_from_splash() -> void:
	guardian_charge = false
	perfect_streak = 0
	combo = 0
	flow_seconds = 0.0
	# A Guardian rescue on a missed jump returns to the previously
	# confirmed lily. Preserve at least three seconds to make the next hop.
	if fragile_pad_id >= 0:
		fragile_seconds = maxf(fragile_seconds, FRAGILE_GUARDIAN_GRACE)
	player_x = jump_start.x
	player_m = jump_start.y
	for standing in pads:
		if int(standing["id"]) == standing_pad_id:
			player_x = PLATFORM_MOTION.x_at(standing, clock)
			break
	previous_x = player_x
	jump_z = 0.0
	jump_pad_id = -1
	mode = MODE_PLAY
	wave_m = minf(wave_m, player_m - 22.0)
	body_squash = 0.32
	landing_impact = 0.90
	shake_strength = 6.5
	impact_flash = 0.26
	celebration = 0.45
	_add_ripple(_player_screen() + Vector2(0, 12), 1.8)
	_burst(_player_screen(), 20, "spark")
	_add_float_text("GUARDIAN SAVE!", _player_screen() + Vector2(0, -113), Color("#fff6c9"))
	sound.play_event("boost")


func _die() -> void:
	if mode == MODE_LOST:
		return
	flow_seconds = 0.0
	fragile_seconds = 0.0
	fragile_pad_id = -1
	mode = MODE_LOST
	# Keep the result visible; do not interrupt the end screen with a timer ad.
	monetization.on_run_finished()
	shake_strength = maxf(shake_strength, 7.0)
	jump_z = 0.0
	sound.play_event("lose")
	run_new_record = run_new_distance_record or score > best_score or run_perfects > best_run_perfects or run_peak_combo > best_run_combo or run_friends > best_run_friends
	best_score = maxi(best_score, score)
	best_run_perfects = maxi(best_run_perfects, run_perfects)
	best_run_combo = maxi(best_run_combo, run_peak_combo)
	best_run_friends = maxi(best_run_friends, run_friends)
	daily.on_finish(score)
	_save_progress()

func _on_rewarded_leaves(amount: int) -> void:
	# Only the monetization provider emits this after its verified reward event.
	# The callback can arrive after the player has returned Home or retried;
	# never discard an earned reward just because the result screen closed.
	if amount <= 0:
		return
	if mode == MODE_LOST and rewarded_this_run:
		return
	leaves += amount
	if mode == MODE_LOST:
		rewarded_this_run = true
		run_leaves += amount
		_add_float_text("+%d LEAVES" % amount, Vector2(270, 265), Color("#e6ffc5"))
	_save_progress()

func _is_unlocked(index: int) -> bool:
	return index >= 0 and index < SKIN_COSTS.size() and (unlocked_skins & (1 << index)) != 0

func _save_progress() -> void:
	var save := ConfigFile.new()
	SAVE_STORE.read_into(save)
	save.set_value("progress", "best_score", best_score)
	save.set_value("progress", "muted", saved_muted)
	save.set_value("progress", "android_system_tones", android_tones_enabled)
	save.set_value("progress", "haptics", haptics_enabled)
	save.set_value("progress", "leaves", leaves)
	save.set_value("progress", "unlocked_skins", unlocked_skins)
	save.set_value("progress", "selected_skin", selected_skin)
	save.set_value("progress", "total_runs", total_runs)
	save.set_value("records", "perfects", best_run_perfects)
	save.set_value("records", "combo", best_run_combo)
	save.set_value("records", "friends", best_run_friends)
	save.set_value("records", "best_endless_m", best_endless_m)
	save.set_value("records", "challenge_wins", lifetime_challenge_wins.duplicate())
	save.set_value("records", "best_challenge_streak", lifetime_best_challenge_streak)
	daily.write_to(save)
	chapters.write_to(save)
	var error: Error = SAVE_STORE.write(save)
	if error != OK:
		push_warning("Progress save failed: %s" % error_string(error))

func _add_float_text(value: String, pos: Vector2, color: Color) -> void:
	if float_texts.size() >= 8:
		float_texts.pop_front()
	var placed: Vector2 = JUMP_FEEDBACK.place_message(pos, float_texts)
	float_texts.append({"text": value, "pos": placed, "life": 1.0, "color": color})

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

