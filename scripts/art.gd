extends RefCounted
const PLATFORM_MOTION = preload("res://scripts/platform_motion.gd")
const PAD_DANGER = preload("res://scripts/pad_danger.gd")
const VISUAL_MOTION = preload("res://scripts/visual_motion.gd")
## Hand-drawn, resolution-independent vector renderer. All illustrations are original.
const W := 540.0
const H := 960.0
const SCALE := 8.0
const ANCHOR := 700.0
const INK := Color("#424454")
const CREAM := Color("#fff1da")
const PALETTE := [
	Color("#a8cb65"), Color("#7ebf75"), Color("#d8b66b"), Color("#80bdad")
]

static func ellipse(c: CanvasItem, at: Vector2, radii: Vector2, color: Color, segments: int = 30) -> void:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		pts.append(at + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	c.draw_colored_polygon(pts, color)

static func line(c: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 2.0) -> void:
	c.draw_line(a, b, color, width, true)

static func rr(c: CanvasItem, rect: Rect2, r: float, fill: Color, stroke: Color = Color.TRANSPARENT, stroke_width: float = 0.0) -> void:
	if stroke_width > 0.0:
		rr(c, rect.grow(stroke_width), r + stroke_width, stroke)
	r = minf(r, minf(rect.size.x, rect.size.y) * 0.49)
	c.draw_rect(Rect2(rect.position + Vector2(r, 0), rect.size - Vector2(r * 2, 0)), fill)
	c.draw_rect(Rect2(rect.position + Vector2(0, r), rect.size - Vector2(0, r * 2)), fill)
	for x in [rect.position.x + r, rect.end.x - r]:
		for y in [rect.position.y + r, rect.end.y - r]:
			c.draw_circle(Vector2(x, y), r, fill)

static func fitted_font_size(value: String, proposed: int, max_width: float) -> int:
	# Measure the fallback font, not the number of characters. Text previously
	# used CENTER with width=-1, which did not center the actual glyph bounds.
	var font: Font = ThemeDB.fallback_font
	var size := proposed
	while size > 10 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
		size -= 1
	return size


static func text(c: CanvasItem, value: String, center: Vector2, size: int, color: Color = INK, shadow: bool = false, max_width: float = 0.0) -> void:
	var font: Font = ThemeDB.fallback_font
	# Without an explicit button width, stay within the viewport margins.
	var allowed_width := max_width if max_width > 0.0 else 2.0 * maxf(10.0, minf(center.x - 16.0, W - center.x - 16.0))
	var actual_size := fitted_font_size(value, size, allowed_width)
	var measured := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, actual_size)
	var origin := Vector2(center.x - measured.x * 0.5, center.y + float(actual_size) * 0.36)
	if shadow:
		c.draw_string(font, origin + Vector2(1.4, 2.2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, actual_size, Color("#655d6b"))
	c.draw_string(font, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1, actual_size, color)


static func scene(c: CanvasItem, time: float, cam: float, pads: Array, player_at: Vector2, jump_z: float, pets: int, wave_m: float, aiming: bool, aim_at: Vector2, aim_valid: bool, mode: int, score: int, best: int, combo: int, particles: Array, distance: int, muted: bool, skin: int, leaves: int, unlocked: int, prices: Array, run_leaves: int, daily: RefCounted, monetization: Node, rewarded_this_run: bool, wardrobe_page: int, tilt: float, squash: float, sway: float, blink: float, impact: float, pad_impacts: Dictionary, celebration: float, float_texts: Array, ripples: Array, shake: Vector2, flash: float, chapters: RefCounted, campaign_stage: int, biome_banner: float, clear_medal: int, clear_reward: int, haptics_enabled: bool, android_tones_enabled: bool, graphics_quality: int = 2, guardian_charge: bool = false, flight_trail: Array = [], flow_seconds: float = 0.0, fragile_pad_id: int = -1, fragile_seconds: float = 0.0, precision_pulse: float = 0.0, run_hops: int = 0, run_perfects: int = 0, run_peak_combo: int = 0, run_friends: int = 0, run_new_record: bool = false, run_grade: String = "", next_weekly: Dictionary = {}, performance_stats: Dictionary = {}, aim_danger_seconds: float = 0.0, festival_progress: int = 0, festival_banner_seconds: float = 0.0, perfect_streak: int = 0, best_endless_m: int = 0, distance_banner_mark: int = 0, distance_banner_seconds: float = 0.0, aim_perfect: bool = false, sprint_state: Dictionary = {}, challenge_banner: Dictionary = {}, challenge_banner_seconds: float = 0.0, lifetime_challenge_wins: Array = []) -> void:
	var biome: int = chapters.biome_at(cam, campaign_stage)
	# Shake is applied only to the illustrated world; HUD remains legible.
	c.draw_set_transform(shake)
	_river(c, time, cam, biome, graphics_quality, campaign_stage)
	_bank_landmarks(c, biome, time, cam, graphics_quality)
	# Sparse animated surface glints: stable world-space placement, zero textures.
	# Limited to 15 strokes so older Android GPUs are not overloaded.
	for i in range(15 if graphics_quality >= 2 else (6 if graphics_quality == 1 else 0)):
		var seed := float(i * 83 + 17)
		var x := 48.0 + fposmod(seed * 3.73, 448.0)
		var y := fposmod(seed * 9.7 + time * (8.0 + float(i % 4) * 2.0) + cam * 1.3, H + 36.0) - 18.0
		var shine := 0.20 + 0.16 * sin(time * 1.9 + seed)
		c.draw_line(Vector2(x - 7.0, y), Vector2(x + 7.0, y), Color(0.95, 1.0, 0.91, shine), 1.4, true)
		if i % 3 == 0:
			c.draw_line(Vector2(x - 3.0, y + 5.0), Vector2(x + 3.0, y + 5.0), Color(0.95, 1.0, 0.91, shine * 0.55), 1.0, true)
	c.draw_set_transform(Vector2.ZERO)
	for pad in pads:
		var screen := Vector2(PLATFORM_MOTION.x_at(pad, time), ANCHOR - (float(pad["m"]) - cam) * SCALE) + shake
		if screen.y < -125.0 or screen.y > H + 125.0:
			continue
		_lily(c, screen, float(pad["r"]), int(pad["kind"]), time, int(pad["id"]), float(pad_impacts.get(int(pad["id"]), 0.0)), chapters.biome_at(float(pad["m"]), campaign_stage), graphics_quality)
		if int(pad.get("festival_step", -1)) >= 0:
			_festival_lily(c, screen, float(pad["r"]), time, int(pad["festival_step"]), bool(pad.get("festival_collected", false)), graphics_quality)
		if bool(pad.get("branch_bonus", false)):
			_bonus_branch_lily(c, screen, float(pad["r"]), time, graphics_quality)
		if bool(pad.get("moving", false)):
			_moving_lily_cue(c, screen, float(pad["r"]), time, graphics_quality)
		if bool(pad.get("danger", false)):
			_danger_lily(c, screen, float(pad["r"]), time, PAD_DANGER.is_active(pad, time), graphics_quality)
		if bool(pad.get("fragile", false)):
			_fragile_lily(c, screen, float(pad["r"]), time, int(pad["id"]) == fragile_pad_id, fragile_seconds, graphics_quality)
		if bool(pad.get("harmony", false)):
			_harmony_lily(c, screen, float(pad["r"]), time, graphics_quality)
		if bool(pad.get("guardian", false)):
			_guardian_lily(c, screen, float(pad["r"]), time)
		if bool(pad.get("boost", false)):
			_boost(c, screen + Vector2(-20, -24 + sin(time * 3.7 + float(pad["id"])) * 2.4), time)
		if bool(pad["coin"]):
			_coin(c, screen + Vector2(11, -25 + sin(time * 3.0 + float(pad["id"])) * 3), time)
		if bool(pad["pet"]):
			_friend(c, screen + Vector2(0, -18), int(pad["id"]) % 4, 0.82, time)
	for ripple in ripples:
		var age: float = float(ripple["age"])
		var pos: Vector2 = Vector2(ripple["pos"]) + shake
		var radius: float = (15.0 + age * 88.0) * float(ripple["size"])
		c.draw_arc(pos, radius, 0.0, TAU, 56, Color(0.99, 1.0, 0.91, (1.0 - age / 0.78) * 0.65), 2.9 * (1.0 - age / 0.9), true)
	_wave(c, ANCHOR - (wave_m - cam) * SCALE + shake.y, time, graphics_quality)
	if graphics_quality > 0:
		_flight_ribbon(c, flight_trail, cam, shake, graphics_quality)
	if aiming:
		_aim_guide(c, player_at + shake, aim_at + shake, time, aim_valid, aim_danger_seconds, aim_perfect)
	if flow_seconds > 0.0:
		_flow_aura(c, player_at + shake, jump_z, time, flow_seconds, graphics_quality)
	if precision_pulse > 0.0:
		_precision_feedback(c, player_at + shake, jump_z, precision_pulse, graphics_quality)
	var gaze := VISUAL_MOTION.gaze(mode, player_at, aim_at, tilt)
	var expression := VISUAL_MOTION.mood(mode, aim_valid, aim_perfect, aim_danger_seconds > 0.0)
	_character(c, player_at + shake, jump_z, pets, time, mode == 3, tilt, squash, sway, blink, impact, celebration, skin, gaze, expression)
	if guardian_charge:
		c.draw_arc(player_at + shake + Vector2(0, -jump_z - 20), 43.0 + sin(time * 4.0) * 2.0, 0, TAU, 40, Color(1.0, 0.88, 0.43, 0.40), 2.5, true)
	for particle in particles:
		var p: Vector2 = Vector2(particle["pos"]) + shake
		var life: float = particle["life"]
		if particle.get("kind", "spark") == "water":
			var velocity: Vector2 = particle["velocity"]
			var direction := velocity.normalized() if velocity.length_squared() > 0.1 else Vector2.UP
			var tail := p - direction * (5.0 + life * 9.0)
			line(c, p, tail, Color(0.83, 0.97, 1.0, life * 0.55), 2.4 + life * 1.5)
			c.draw_circle(p, 2.0 + life * 2.1, Color(0.98, 1.0, 0.99, life))
		else:
			c.draw_circle(p, 2.3 + 4.0 * life, Color(0.99, 0.85, 0.46, life * 0.65))
			c.draw_circle(p, 1.1 + 1.6 * life, Color(1, 1, 0.91, life))
	for floating in float_texts:
		var life: float = float(floating["life"])
		var p: Vector2 = Vector2(floating["pos"]) + shake
		var ink: Color = floating["color"]
		ink.a = clampf(life * 1.45, 0.0, 1.0)
		text(c, String(floating["text"]), p, 22, ink, true)
	c.draw_set_transform(Vector2.ZERO)
	if flash > 0.0:
		c.draw_rect(Rect2(0, 0, W, H), Color(1.0, 0.97, 0.85, flash * 0.34))
	_hud(c, score, best, pets, distance, wave_m, cam, combo, mode, chapters, campaign_stage, biome, biome_banner)
	if guardian_charge and mode in [1, 2, 3, 5]:
		rr(c, Rect2(12, 72, 146, 30), 13, Color("#fff1ba"), Color("#a6894a"), 1.5)
		text(c, "GUARDIAN READY", Vector2(85, 87), 14, Color("#76572c"))
	if flow_seconds > 0.0 and mode in [1, 2, 3, 5]:
		_flow_hud(c, flow_seconds)
	if fragile_pad_id >= 0 and mode in [1, 2, 5]:
		_fragile_hud(c, fragile_seconds)
	if festival_progress > 0 and mode in [1, 2, 3]:
		_festival_hud(c, festival_progress)
	if campaign_stage == -1 and mode in [1, 2, 3]:
		# Important warning and celebration cards keep priority.
		var busy := biome_banner > 0.0 or festival_banner_seconds > 0.0 or distance_banner_seconds > 0.0 or fragile_pad_id >= 0
		var challenge_y := 332.0 if busy else 151.0
		if bool(sprint_state.get("active", false)):
			_endless_challenge_hud(c, sprint_state, challenge_y)
		elif bool(sprint_state.get("upcoming", false)):
			_upcoming_challenge_hud(c, sprint_state, challenge_y)
		if challenge_banner_seconds > 0.0 and not challenge_banner.is_empty():
			_challenge_result_banner(c, challenge_banner, challenge_banner_seconds, graphics_quality,
				348.0 if busy else 244.0)
	if festival_banner_seconds > 0.0 and mode in [1, 2, 3]:
		_festival_banner(c, festival_banner_seconds)
	if distance_banner_seconds > 0.0 and distance_banner_mark > 0 and mode in [1, 2, 3]:
		_distance_milestone_banner(c, distance_banner_mark, distance_banner_seconds, graphics_quality)
	if mode in [1, 2, 3]:
		_streak_progress(c, perfect_streak, flow_seconds)
	if mode == 0:
		_start_overlay(c, time, leaves, skin, daily, monetization, chapters, best_endless_m)
	if mode == 4:
		_lost_overlay(c, score, best, run_leaves, monetization, rewarded_this_run, run_hops, run_perfects, run_peak_combo, run_friends, run_new_record, run_grade, next_weekly, distance, best_endless_m, campaign_stage, lifetime_challenge_wins)
	if mode == 5:
		_pause_overlay(c, muted, monetization, haptics_enabled, android_tones_enabled)
	if mode == 6:
		_wardrobe_overlay(c, time, leaves, skin, unlocked, prices, wardrobe_page)
	if mode == 7:
		_goals_overlay(c, daily)
	if mode == 8:
		_chapter_select_overlay(c, chapters)
	if mode == 10:
		_device_diagnostics_overlay(c, performance_stats, graphics_quality, android_tones_enabled, haptics_enabled)
	if mode == 9:
		if campaign_stage == -2:
			_daily_clear_overlay(c, clear_reward, daily, score)
		else:
			_chapter_clear_overlay(c, campaign_stage, clear_medal, clear_reward, chapters)

static func _biome_blend(cam: float, campaign_stage: int) -> float:
	# Full palette in chapters, daily runs and before the first transition.
	if campaign_stage != -1 or cam < 140.0:
		return 1.0
	return smoothstep(0.0, 16.0, fposmod(cam, 140.0))


static func _river(c: CanvasItem, t: float, cam: float, biome: int, graphics_quality: int = 2, campaign_stage: int = -1) -> void:
	# Each chapter has its own original illustrated color script; no external textures.
	var earth := [Color("#a6c49e"), Color("#9cc69a"), Color("#d3bd91"), Color("#77879b"), Color("#9cbcc4"), Color("#7c8297")]
	var water_colors := [Color("#81abb9"), Color("#79b5a8"), Color("#b0b8b0"), Color("#647caa"), Color("#84b7cb"), Color("#627e9b")]
	var sand_colors := [Color("#f0e1b7"), Color("#e3e7c6"), Color("#f1d5a7"), Color("#afb4d0"), Color("#d9e5e5"), Color("#adb7c2")]
	var plants := [Color("#558765"), Color("#608c72"), Color("#947f57"), Color("#657c91"), Color("#668f92"), Color("#718078")]
	var b := clampi(biome, 0, 5)
	# In endless mode, crossfade each sector palette rather than snapping
	# abruptly at 140m boundaries. No state or GPU textures required.
	var old_b := posmod(b + 5, 6)
	var blend := _biome_blend(cam, campaign_stage)
	var ground_ink: Color = earth[old_b].lerp(earth[b], blend)
	var water_ink: Color = water_colors[old_b].lerp(water_colors[b], blend)
	var sand_ink: Color = sand_colors[old_b].lerp(sand_colors[b], blend)
	var plants_ink: Color = plants[old_b].lerp(plants[b], blend)
	c.draw_rect(Rect2(0, 0, W, H), ground_ink)
	var water := PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(58 if graphics_quality >= 2 else 40):
		var y := -34.0 + float(i) * (18.6 if graphics_quality >= 2 else 27.0)
		var offset := y + cam * SCALE
		var wiggle := sin(offset * 0.007) * 9.0 + sin(offset * 0.021 + 1.3) * 4.0
		left.append(Vector2(45.0 + wiggle, y))
		right.append(Vector2(494.0 + wiggle * 0.83, y))
	# Sandy outline adds separation against the banks.
	for i in range(left.size() - 1):
		line(c, left[i] + Vector2(-9, 0), left[i + 1] + Vector2(-9, 0), sand_ink, 18)
		line(c, right[i] + Vector2(9, 0), right[i + 1] + Vector2(9, 0), sand_ink.lightened(0.03), 18)
	water.append_array(left)
	for i in range(right.size() - 1, -1, -1):
		water.append(right[i])
	c.draw_colored_polygon(water, water_ink)
	# Broad drifting translucent current. Polygon edges never self-intersect.
	for band in range(5 if graphics_quality >= 2 else (3 if graphics_quality == 1 else 1)):
		var y := fposmod(float(band) * 193.0 + cam * SCALE * 0.62 + t * 13.0, 1350.0) - 190.0
		var band_poly := PackedVector2Array()
		for i in range(21):
			var x := float(i) * 27.0
			band_poly.append(Vector2(x, y + sin(x * 0.014 + band) * 12.0))
		for i in range(20, -1, -1):
			var x := float(i) * 27.0
			band_poly.append(Vector2(x, y + 40 + sin(x * 0.014 + band) * 12.0))
		c.draw_colored_polygon(band_poly, water_ink.darkened(0.28) * Color(1, 1, 1, 0.10))
	for i in range(left.size() - 1):
		line(c, left[i], left[i + 1], plants_ink, 3.5)
		line(c, right[i], right[i + 1], plants_ink.lightened(0.06), 3.5)
	# Low-contrast depth bands mimic watercolor washes without texture assets.
	for lane in range(7 if graphics_quality >= 2 else (4 if graphics_quality == 1 else 0)):
		var x := 91.0 + float(lane) * 41.0
		var width := 16.0 + 4.0 * sin(lane * 1.7)
		var tint := Color(0.17, 0.32, 0.48, 0.022 + 0.018 * (1.0 - absf(float(lane - 4)) / 4.0))
		rr(c, Rect2(x, -8, width, H + 16), 9, tint)
	# Soft animated caustic arcs and drifting surface glints.
	for i in range(14 if graphics_quality >= 2 else (7 if graphics_quality == 1 else 0)):
		var x := 94.0 + float((i * 67 + 41) % 350)
		var y := fposmod(float(i) * 103.0 + cam * SCALE * 0.53 + t * 14.0, 1240.0) - 150.0
		var swish := sin(t * 1.4 + i * 1.6)
		c.draw_arc(Vector2(x, y), 12.0 + float(i % 4) * 3.0, 0.3 + swish * 0.1, 2.4 + swish * 0.1, 16, Color(0.94, 0.98, 0.98, 0.11), 2.3, true)
		c.draw_circle(Vector2(x + 19, y + 8), 2.1 + 0.6 * swish, Color(1, 1, 0.94, 0.25))
	# Water speed lines tilt back with a hand-animated flow.
	for i in range(52 if graphics_quality >= 2 else (25 if graphics_quality == 1 else 8)):
		var x := 65.0 + float((i * 113 + 29) % 410)
		var y := fposmod(float(i) * 81.7 + cam * SCALE * 0.65 + t * 29.0, 1210.0) - 155.0
		var n := 10.0 + float(i % 5) * 7.0
		line(c, Vector2(x, y), Vector2(x + 6, y + n), Color(0.98, 1.0, 1.0, 0.36), 1.4 + float(i % 2) * 0.25)
	# Pebbles, reeds, small blossoms and flattened grasses.
	for i in range(34 if graphics_quality >= 2 else (20 if graphics_quality == 1 else 10)):
		var y := fposmod(float(i) * 79.0 + cam * SCALE, 1180.0) - 95.0
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var edge := 38.0 if side < 0.0 else 503.0
		var x := edge + side * float((i * 13) % 28)
		ellipse(c, Vector2(x + 2, y + 8), Vector2(10, 6), Color("#748b7e"))
		ellipse(c, Vector2(x, y + 5), Vector2(9, 5), Color("#c1aa9a"))
		if i % 4 == 0:
			ellipse(c, Vector2(x - 7 * side, y), Vector2(4, 3), Color("#887986"))
		for stalk in range(1 + i % 3):
			var origin := Vector2(x + float(stalk - 1) * 7, y + 14)
			var tip := origin + Vector2(float(stalk - 1) * 5.0 - side * 2.0, -14 - float(stalk % 2) * 9)
			line(c, origin, tip, plants_ink.darkened(0.10), 2.0)
			if (i + stalk) % 4 == 0:
				ellipse(c, tip, Vector2(3.2, 8.0), Color("#9d676d"))
			else:
				ellipse(c, tip + Vector2(0, -3), Vector2(2.2, 5.0), plants_ink.lightened(0.14))
	# Floating rings, bubbles and firefly-like glints.
	for i in range(27 if graphics_quality >= 2 else (13 if graphics_quality == 1 else 4)):
		var y := fposmod(float(i) * 73.0 + cam * SCALE * 0.83 + t * 5.0, 1160.0) - 100.0
		var x := 87.0 + float((i * 137 + 41) % 365)
		var alpha := 0.20 + float(i % 4) * 0.055
		c.draw_arc(Vector2(x, y), float(8 + i % 8), 0.35, 2.65, 16, Color(0.97, 1, 1, alpha), 1.5, true)
		c.draw_arc(Vector2(x + 7, y + 5), float(6 + i % 6), 3.35, 5.75, 15, Color(0.97, 1, 1, alpha), 1.3, true)
		if i % 3 == 0:
			var pulse := 1.5 + sin(t * 3 + float(i)) * 0.55
			c.draw_circle(Vector2(x - 20, y - 25), pulse, Color("#fff3b8"))
			c.draw_circle(Vector2(x - 20, y - 25), 4.5, Color(1, 0.96, 0.73, 0.09))

	if graphics_quality > 0:
		_biome_accents(c, b, t, cam, graphics_quality)
		_biome_atmosphere(c, b, t, cam, graphics_quality)
	# Tiny environmental stories: golden leaves, twilight fireflies and crystals.
	for i in range(12 if graphics_quality >= 2 else (6 if graphics_quality == 1 else 0)):
		var x := 70.0 + float((i * 79 + 31) % 394)
		var y := fposmod(float(i) * 117.0 + cam * SCALE * 0.68 + t * (9.0 if b == 5 else 3.0), 1250.0) - 145.0
		if b == 2:
			var petal := Color("#f7d38c") if i % 2 == 0 else Color("#b88662")
			ellipse(c, Vector2(x, y), Vector2(3.1, 6.6), petal)
			line(c, Vector2(x, y + 4), Vector2(x + 3, y + 9), petal.darkened(0.17), 1)
		elif b == 3 or b == 5:
			var halo := 4.0 + 2.0 * sin(t * 2.0 + i)
			c.draw_circle(Vector2(x, y), halo, Color(0.88, 0.92, 1.0, 0.07))
			c.draw_circle(Vector2(x, y), 1.9, Color(0.93, 0.94, 0.72, 0.73))
		elif b == 4:
			var crystal := PackedVector2Array([Vector2(x, y - 8), Vector2(x + 3, y), Vector2(x, y + 7), Vector2(x - 3, y)])
			c.draw_colored_polygon(crystal, Color(0.83, 0.96, 1.0, 0.56))
		elif b == 1:
			c.draw_circle(Vector2(x, y), 3.6, Color("#eedfa9"))
			c.draw_circle(Vector2(x, y), 1.5, Color("#fff7d8"))


static func _biome_atmosphere(c: CanvasItem, biome: int, time: float, cam: float, quality: int) -> void:
	# Restrained hand-illustrated weather. Fixed capped draw count with no
	# allocations outside the existing CanvasItem command buffer.
	var count := 12 if quality >= 2 else 5
	for i in range(count):
		var phase := float(i) * 1.618 + float(biome) * 2.31
		var x := 84.0 + fposmod(float(i * 117 + 53), 372.0)
		var y := fposmod(float(i * 149) + cam * SCALE * 0.27 + time * (5.0 if biome != 5 else 48.0), 1080.0) - 65.0
		match biome:
			0: # Sun motes slowly ascend through soft light.
				var at := Vector2(x + sin(time + phase) * 5.0, y)
				c.draw_circle(at, 2.3, Color("#fff6c9") * Color(1, 1, 1, 0.44))
			1: # Floating garden petals.
				var at := Vector2(x + sin(time * 1.4 + phase) * 13.0, y)
				ellipse(c, at, Vector2(3.0, 5.2), Color(0.98, 0.83, 0.89, 0.38))
			2: # Amber drifting autumn leaves.
				var p := Vector2(x + sin(time * 1.1 + phase) * 19.0, y)
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(4, 0), p + Vector2(0, 7), p + Vector2(-4, 0)]), Color(0.96, 0.77, 0.48, 0.40))
			3: # Tiny, breathing moonlit fireflies.
				var a := 0.3 + 0.15 * sin(time * 3.0 + phase)
				c.draw_circle(Vector2(x, y), 3.4, Color(0.92, 0.98, 1.0, a * 0.35))
				c.draw_circle(Vector2(x, y), 1.6, Color(0.92, 0.96, 0.77, a))
			4: # Light refractions in the crystal river.
				line(c, Vector2(x - 3, y - 7), Vector2(x + 3, y + 7), Color(0.83, 0.96, 1.0, 0.41), 1.5)
				line(c, Vector2(x + 3, y - 7), Vector2(x - 3, y + 7), Color(0.96, 1.0, 1.0, 0.34), 1.3)
			5: # Fast visible rain streaks, well clear of touch indicators.
				line(c, Vector2(x + 9, y - 12), Vector2(x - 5, y + 17), Color(0.92, 0.97, 1.0, 0.41), 1.8)


static func _flow_aura(c: CanvasItem, pos: Vector2, height: float, t: float, remaining: float, quality: int) -> void:
	# Soft skill-feedback aura; never overlaps the lily collision indicator.
	# At tier zero only the status HUD remains.
	if quality <= 0:
		return
	var center := pos + Vector2(0, -height - 23.0)
	var pulse := 2.0 + sin(t * 7.0) * 2.0
	c.draw_arc(center, 41.0 + pulse, 0.20, TAU - 0.20, 28 if quality == 1 else 42,
		Color(0.50, 0.94, 1.0, 0.34), 2.4, true)
	if quality >= 2:
		for i in range(6):
			var angle := t * 2.1 + float(i) * TAU / 6.0
			var at := center + Vector2(cos(angle) * 49.0, sin(angle) * 31.0)
			c.draw_circle(at, 2.0 + sin(angle) * 0.6, Color(0.93, 1.0, 0.89, 0.62))

static func _streak_progress(c: CanvasItem, streak: int, flow_remaining: float) -> void:
	# Four large, clear ticks for the next FLOW; fifth perfect awards a leaf.
	# Draw at the bottom edge, away from the top-biome/festival overlays and
	# always outside the frog's central playing area.
	var flow_count := streak % 4
	var leaf_count := streak % 5
	rr(c, Rect2(151, 897, 238, 55), 19, Color(0.18, 0.31, 0.36, 0.84), Color("#9dbab1"), 1.4)
	var description := "FLOW ACTIVE" if flow_remaining > 0.0 else "NEXT FLOW  %d/4" % flow_count
	text(c, description, Vector2(270, 913), 14, Color("#f0f7d5"), true, 205.0)
	for i in range(4):
		var x := 170.0 + float(i) * 34.0
		rr(c, Rect2(x, 928, 31, 7), 3.5, Color("#879ca1"))
		if flow_remaining > 0.0 or i < flow_count:
			rr(c, Rect2(x, 928, 31, 7), 3.5, Color("#b9f6e4"))
	text(c, "LEAF %d/5" % leaf_count, Vector2(351, 939), 11, Color("#fff0bc"), false, 69.0)


static func _flow_hud(c: CanvasItem, remaining: float) -> void:
	var progress := clampf(remaining / 7.0, 0.0, 1.0)
	rr(c, Rect2(365, 73, 161, 33), 13, Color("#d8fcf7"), Color("#68a6aa"), 1.4)
	text(c, "FLOW +35%", Vector2(445, 86), 15, Color("#3e737b"))
	rr(c, Rect2(377, 96, 137, 3), 1.5, Color("#a5d5d5"))
	if progress > 0.001:
		rr(c, Rect2(377, 96, 137.0 * progress, 3), 1.5, Color("#3abdc2"))


static func _distance_milestone_banner(c: CanvasItem, mark: int, seconds: float, quality: int) -> void:
	# Short-lived milestone card sits BELOW chapter/biome/festival banners.
	# Fixed low-cost CanvasItem primitives keep the scene responsive on Android.
	var fade := clampf(seconds * 2.0, 0.0, 1.0)
	var bg := Color("#fff2c9")
	bg.a = fade * 0.96
	rr(c, Rect2(121, 244, 298, 68), 23, bg, Color(0.72, 0.57, 0.34, fade * 0.9), 2.0)
	var ink := Color("#695f4b")
	ink.a = fade
	text(c, "%d METERS!" % mark, Vector2(270, 263), 24, ink, true, 275.0)
	text(c, "+2 LEAVES  •  +120 PTS", Vector2(270, 292), 16, ink, false, 275.0)
	if quality >= 1:
		for i in range(6 if quality == 1 else 10):
			var t := float(i) * TAU / (6.0 if quality == 1 else 10.0)
			var p := Vector2(270 + cos(t) * 168.0, 278 + sin(t) * 46.0)
			c.draw_circle(p, 2.3, Color(1.0, 0.96, 0.61, fade * 0.7))


static func _festival_lily(c: CanvasItem, pos: Vector2, radius: float, time: float, step: int, claimed: bool, quality: int) -> void:
	# Three lavender halos are readable even without optional particles.
	var base_alpha := 0.32 if claimed else 0.62
	var glow := 0.10 * sin(time * 3.8 + float(step))
	c.draw_arc(pos, radius + 8.0, 0.0, TAU, 32 if quality == 0 else 48, Color(0.87, 0.69, 1.0, base_alpha + glow), 3.5, true)
	var center := pos + Vector2(0, -17)
	c.draw_circle(center, 13.0, Color("#66567f"))
	c.draw_circle(center, 10.0, Color("#dbc1f8"))
	text(c, str(step + 1), center + Vector2(0, -2), 16, Color("#514c70"), true, 22.0)
	if quality >= 1 and not claimed:
		for i in range(4 if quality == 1 else 6):
			var angle := float(i) * TAU / (4.0 if quality == 1 else 6.0) + time * 0.8
			var at := pos + Vector2(cos(angle) * (radius + 17.0), sin(angle) * (radius + 10.0))
			c.draw_circle(at, 2.0, Color(0.96, 0.91, 1.0, 0.45))


static func _endless_challenge_hud(c: CanvasItem, challenge: Dictionary, y: float = 151.0) -> void:
	# One HUD for four different live objectives. It uses only cheap CanvasItem
	# shapes, stays legible on quality zero and never changes the simulation.
	var kind := clampi(int(challenge.get("type", 0)), 0, 3)
	var palette := [Color("#7bc7be"), Color("#a1d38b"), Color("#f1cc82"), Color("#c9ace8")]
	var accent: Color = palette[kind]
	var target := clampi(int(challenge.get("target", 3)), 1, 3)
	var completed := clampi(int(challenge.get("progress", 0)), 0, target)
	var remaining := clampi(int(challenge.get("remaining", 0)), 0, 6)
	var advanced := int(challenge.get("level", 0)) > 0
	var title_text := String(challenge.get("title", "RIVER CHALLENGE"))
	var description := String(challenge.get("description", "COMPLETE THE CHALLENGE"))
	rr(c, Rect2(112, y, 316, 77), 19,
		Color(0.10, 0.22, 0.28, 0.92), Color(accent.r, accent.g, accent.b, 0.85), 1.8)
	text(c, title_text, Vector2(270, y + 17), 17, Color("#f5f9ec"), true, 282.0)
	text(c, "ADVANCED  •  %s" % description if advanced else description,
		Vector2(270, y + 39), 12, Color("#d1e5df"), false, 282.0)
	text(c, "%d/%d" % [completed, target], Vector2(160, y + 61), 15, accent, true, 66.0)
	for i in range(target):
		var x := 235.0 + float(i) * 37.0
		c.draw_circle(Vector2(x, y + 61), 7.0, accent if i < completed else Color("#526e72"))
		if i < completed:
			c.draw_circle(Vector2(x - 1.5, y + 59.0), 2.5, Color(1, 1, 1, 0.54))
	text(c, "%d LEFT" % remaining, Vector2(377, y + 61), 12, Color("#e5f8f0"), false, 72.0)


static func _upcoming_challenge_hud(c: CanvasItem, info: Dictionary, y: float) -> void:
	# The player gets up to three jumps of warning before a new objective.
	# This is a read-only preview and cannot affect targets or RNG.
	var remaining := clampi(int(info.get("starts_in", 0)), 0, 2)
	var title_text := String(info.get("next_title", "RIVER CHALLENGE"))
	rr(c, Rect2(123, y, 294, 46), 15,
		Color(0.12, 0.25, 0.31, 0.87), Color(0.66, 0.88, 0.78, 0.54), 1.4)
	text(c, "UP NEXT  •  %s" % title_text, Vector2(270, y + 15), 15, Color("#f1fce9"), true, 266.0)
	text(c, "STARTS %s" % ("NEXT JUMP" if remaining == 0 else "IN %d JUMPS" % (remaining + 1)),
		Vector2(270, y + 34), 12, Color("#b6e8d8"), false, 260.0)


static func _challenge_result_banner(c: CanvasItem, result: Dictionary, seconds: float,
	quality: int, y: float) -> void:
	# A measured, fading single card instead of a pile of particle-heavy
	# overlays. Success, retry and entry have distinct readable designs.
	var success := bool(result.get("won", false))
	var started := bool(result.get("started", false))
	var alpha := clampf(seconds * 2.0, 0.0, 1.0)
	var tint := Color("#fff1bd") if success else (Color("#d8f4e9") if started else Color("#e8f0e9"))
	var ink := Color("#84633b") if success else Color("#38666b")
	tint.a = alpha * 0.95
	ink.a = alpha
	rr(c, Rect2(114, y, 312, 72), 19, tint)
	var title_text := String(result.get("title", "RIVER CHALLENGE"))
	text(c, title_text, Vector2(270, y + 20), 20, ink, true, 281.0)
	var subtitle := ""
	if success:
		subtitle = "+%d LEAVES  •  +%d POINTS" % [int(result.get("leaves", 2)), int(result.get("score", 180))]
	elif started:
		subtitle = "GO FOR IT!"
	else:
		subtitle = "NEXT CHALLENGE AHEAD"
	text(c, subtitle, Vector2(270, y + 48), 15, ink, false, 277.0)
	if success and quality >= 1:
		for i in range(5 if quality == 1 else 8):
			var angle := float(i) * TAU / (5.0 if quality == 1 else 8.0)
			var dot := Vector2(270.0 + cos(angle) * 171.0, y + 36.0 + sin(angle) * 37.0)
			c.draw_circle(dot, 2.0, Color(1.0, 0.91, 0.60, alpha * 0.68))


static func _festival_hud(c: CanvasItem, progress: int) -> void:
	rr(c, Rect2(170, 108, 200, 34), 14, Color("#f4e6ff"), Color("#9b7db1"), 1.5)
	text(c, "FIREFLY FESTIVAL  %d/3" % progress, Vector2(270, 125), 15, Color("#685884"), false, 181.0)


static func _festival_banner(c: CanvasItem, seconds: float) -> void:
	var alpha := clampf(seconds * 1.35, 0.0, 1.0)
	var fill := Color("#f6e4ff")
	fill.a = alpha * 0.97
	rr(c, Rect2(128, 168, 284, 62), 22, fill)
	var ink := Color("#6b5788")
	ink.a = alpha
	text(c, "FESTIVAL COMPLETE!", Vector2(270, 187), 20, ink, true, 260.0)
	text(c, "+3 LEAVES  •  +320 PTS", Vector2(270, 213), 16, ink, false, 260.0)


static func _bonus_branch_lily(c: CanvasItem, pos: Vector2, radius: float, time: float, quality: int) -> void:
	# Optional skill route. Gold ring and two leaves are readable at
	# quality zero; higher tiers get subtle glow, never costly shaders.
	var pulse := 0.55 + 0.45 * sin(time * 3.1)
	c.draw_arc(pos, radius + 9, 0.0, TAU, 36, Color(1.0, 0.82, 0.39, 0.49 + 0.25 * pulse), 3.2, true)
	var center := pos + Vector2(0, -16.0)
	c.draw_circle(center, 13, Color("#8e7045"))
	c.draw_circle(center, 10.5, Color("#ffe4a2"))
	text(c, "+2", center + Vector2(0, -2), 15, Color("#745031"), true, 29.0)
	if quality >= 1:
		for i in range(4):
			var angle := time * 0.3 + float(i) * TAU / 4.0
			c.draw_circle(pos + Vector2(cos(angle), sin(angle)) * (radius + 17),
				2.2 + float(quality - 1), Color(1.0, 0.94, 0.60, 0.5))


static func _danger_lily(c: CanvasItem, pos: Vector2, radius: float, time: float, active: bool, quality: int) -> void:
	# Readable at even the lowest quality tier, with no extra materials.
	# The red double ring means 'do not land while glowing'; inactive is
	# amber and the crab's harmless wait animation never damages a rider.
	var ink := Color("#f46c62") if active else Color("#d6b483")
	c.draw_arc(pos, radius + 7.0, 0.0, TAU, 32, ink, 4.0 if active else 2.0, true)
	var at := pos + Vector2(0, -14)
	c.draw_circle(at, 11.0, Color("#c65b52") if active else Color("#9d8c80"))
	for side in [-1, 1]:
		var x := float(side)
		line(c, at + Vector2(x * 8, 3), at + Vector2(x * 17, 9), Color("#b45750"), 2.8)
		c.draw_circle(at + Vector2(x * 5, -5), 4.0, Color("#fff6e1"))
		c.draw_circle(at + Vector2(x * 5, -5), 1.8, INK)
	if active:
		text(c, "!", at + Vector2(0, 16), 17, Color("#fff5de"), true, 24.0)
		if quality > 0:
			c.draw_arc(pos, radius + 12.0 + sin(time * 6.0) * 2.0, 0.0, TAU,
				34 if quality == 1 else 48, Color(1.0, 0.43, 0.38, 0.47), 2.0, true)


static func _moving_lily_cue(c: CanvasItem, position: Vector2, radius: float, time: float, quality: int) -> void:
	# Cyan cross-current arrows signal sideways motion even at graphics tier 0.
	var left := position + Vector2(-radius - 14.0, 0)
	var right := position + Vector2(radius + 14.0, 0)
	var ink := Color("#bff3ff")
	line(c, left + Vector2(8, -7), left, ink, 2.2)
	line(c, left, left + Vector2(8, 7), ink, 2.2)
	line(c, right + Vector2(-8, -7), right, ink, 2.2)
	line(c, right, right + Vector2(-8, 7), ink, 2.2)
	if quality >= 1:
		var shimmer := 3.0 + sin(time * 3.0) * 1.5
		c.draw_arc(position, radius + 6, 0.0, TAU, 28,
			Color(0.52, 0.92, 1.0, 0.30), shimmer, true)


static func _harmony_lily(c: CanvasItem, pos: Vector2, radius: float, time: float, quality: int) -> void:
	# Gold/cyan bloom clearly marks a centered-landing challenge, with no
	# change to collision radius or aim-assist behavior.
	var pulse := 0.5 + 0.5 * sin(time * 3.1)
	c.draw_arc(pos, radius + 7.0, 0.0, TAU, 30 if quality == 0 else 48,
		Color(1.0, 0.88, 0.55, 0.35 + pulse * 0.28), 2.8, true)
	var center := pos + Vector2(0, -8.0)
	c.draw_circle(center, 9.0, Color("#6d988a"))
	c.draw_circle(center, 6.0, Color("#fff2b1"))
	if quality >= 1:
		for i in range(4):
			var angle := float(i) * TAU / 4.0 + time * 0.2
			var point := center + Vector2(cos(angle) * 13.0, sin(angle) * 10.0)
			c.draw_circle(point, 2.6, Color("#fce8a0"))
	if quality >= 2:
		c.draw_arc(center, 15.0, -1.1, 2.1, 15, Color(1, 1, 0.9, 0.55), 1.5, true)


static func _precision_feedback(c: CanvasItem, player_at: Vector2, jump_height: float, pulse: float, quality: int) -> void:
	# Short, screen-space spring ring; its draw complexity is capped and does
	# not alter game state, score, trajectory or collision.
	var p := clampf(pulse, 0.0, 1.25)
	var center := player_at + Vector2(0, -jump_height - 17.0)
	var fade := clampf(p / 0.7, 0.0, 1.0)
	var radius := 26.0 + (1.25 - p) * 32.0
	c.draw_arc(center, radius, 0.10, TAU + 0.10,
		24 if quality == 0 else (36 if quality == 1 else 48),
		Color(1.0, 0.95, 0.67, fade * 0.55), 2.6 * fade + 0.6, true)
	if quality >= 2:
		for i in range(6):
			var angle := float(i) * TAU / 6.0
			c.draw_circle(center + Vector2(cos(angle), sin(angle)) * radius,
				2.0 + 1.2 * fade, Color(0.83, 1.0, 0.88, 0.40 * fade))


static func _fragile_lily(c: CanvasItem, pos: Vector2, radius: float, time: float, active: bool, remaining: float, quality: int) -> void:
	# Cracks remain legible even at quality zero: gameplay warnings are never
	# removed by adaptive graphics settings.
	var ink := Color("#a05e48")
	var cracks := 3 if quality == 0 else 5
	for i in range(cracks):
		var angle := float(i) * TAU / float(cracks) + 0.32
		var origin := pos + Vector2(cos(angle), sin(angle) * 0.76) * 7.0
		var split := pos + Vector2(cos(angle + 0.15), sin(angle + 0.15) * 0.76) * (radius * 0.65)
		line(c, origin, split, ink, 2.3 if active else 1.8)
		if quality > 0:
			var branch := origin.lerp(split, 0.70)
			line(c, branch, branch + Vector2(7.0, 5.0), ink.lightened(0.17), 1.4)
	if active:
		var portion := clampf(remaining / 5.5, 0.0, 1.0)
		c.draw_arc(pos, radius + 10.0, -PI * 0.5, PI * 1.5, 38, Color(0.47, 0.24, 0.17, 0.40), 4.0, true)
		if portion > 0.002:
			c.draw_arc(pos, radius + 10.0, -PI * 0.5, -PI * 0.5 + portion * TAU, 38,
				Color("#ffdb86") if portion > 0.35 else Color("#f77c6f"), 4.0, true)
	else:
		# The amber diamond explicitly signals a timed platform before landing.
		var marker := pos + Vector2(0, -19.0)
		c.draw_colored_polygon(PackedVector2Array([
			marker + Vector2(0, -8), marker + Vector2(6, 0),
			marker + Vector2(0, 8), marker + Vector2(-6, 0)]), Color("#ffe2a0"))
		line(c, marker + Vector2(0, -4), marker + Vector2(0, 2), Color("#985e3b"), 2.0)


static func _fragile_hud(c: CanvasItem, remaining: float) -> void:
	# Placed below chapter/biome notices and above the action area.
	rr(c, Rect2(153, 237, 234, 42), 17, Color("#fff0d6"), Color("#b97858"), 1.8)
	text(c, "FRAGILE LILY  %.1fs" % remaining, Vector2(270, 252), 16, Color("#925044"))
	rr(c, Rect2(173, 267, 194, 5), 2.5, Color("#eac5ac"))
	if remaining > 0.0:
		rr(c, Rect2(173, 267, 194.0 * clampf(remaining / 5.5, 0, 1), 5), 2.5,
			Color("#e5b254") if remaining >= 2.0 else Color("#e57563"))


static func _guardian_lily(c: CanvasItem, pos: Vector2, radius: float, time: float) -> void:
	var glow := 0.35 + 0.15 * sin(time * 3.0)
	c.draw_arc(pos, radius + 9.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.38, glow), 3.0, true)
	c.draw_circle(pos + Vector2(0, -7), 12.0, Color("#e4ba58"))
	text(c, "★", pos + Vector2(0, -8), 24, Color("#fffbea"))


static func _flight_ribbon(c: CanvasItem, points: Array, cam: float, shake: Vector2, quality: int) -> void:
	var step := 1 if quality >= 2 else 2
	for i in range(step, points.size(), step):
		var first: Dictionary = points[i - step]
		var second: Dictionary = points[i]
		var fade := clampf(1.0 - float(second["age"]) / 0.34, 0.0, 1.0)
		var a := Vector2(float(first["x"]), ANCHOR - (float(first["m"]) - cam) * SCALE - float(first["z"]) - 24) + shake
		var b := Vector2(float(second["x"]), ANCHOR - (float(second["m"]) - cam) * SCALE - float(second["z"]) - 24) + shake
		line(c, a, b, Color(1.0, 0.95, 0.68, 0.40 * fade), 1.0 + 4.0 * fade)


static func _biome_accents(c: CanvasItem, biome: int, time: float, cam: float, quality: int) -> void:
	for i in range(8 if quality >= 2 else 4):
		var x := 28.0 if i % 2 == 0 else 511.0
		var y := fposmod(float(i * 157 + biome * 97) + cam * SCALE, 1220.0) - 125.0
		var sway := sin(time + i * 2.0) * 3.0
		match biome:
			0:
				line(c, Vector2(x, y + 12), Vector2(x + sway, y - 15), Color("#59874f"), 2.2)
				c.draw_circle(Vector2(x + sway, y - 15), 6, Color("#fff5dc"))
				c.draw_circle(Vector2(x + sway, y - 15), 2.8, Color("#edc56d"))
			1:
				for blade in range(3):
					line(c, Vector2(x, y + 16), Vector2(x + sway + blade * 6 - 6, y - 24), Color("#397f65"), 3.0)
			2:
				line(c, Vector2(x, y + 20), Vector2(x + sway, y - 24), Color("#7a784d"), 3.0)
				ellipse(c, Vector2(x + sway, y - 24), Vector2(4, 10), Color("#c39153"))
			3:
				c.draw_circle(Vector2(x + sway, y), 16, Color(0.8, 0.89, 1.0, 0.08))
				ellipse(c, Vector2(x + sway, y), Vector2(6, 9), Color("#f9debc"))
			4:
				c.draw_colored_polygon(PackedVector2Array([Vector2(x, y - 22), Vector2(x + 9, y + 7), Vector2(x - 9, y + 7)]), Color("#a7e2ee"))
			5:
				line(c, Vector2(x, y - 20), Vector2(x - 10, y + 14), Color(0.86, 0.93, 1.0, 0.43), 2.0)


static func _bank_landmarks(c: CanvasItem, biome: int, time: float, cam: float, quality: int) -> void:
	# Original hand-drawn roadside silhouettes, world-locked (do not pop
	# when the camera pans); density scales with graphics quality.
	# All geometry is within x=0..36 or x=504..540, outside lily landings.
	for i in range(VISUAL_MOTION.bank_prop_count(quality)):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := 21.0 if side < 0 else 519.0
		var y := fposmod(float(i * 171 + biome * 41) + cam * SCALE, 1320.0) - 145.0
		if y < -95.0 or y > H + 70.0:
			continue
		var drift := VISUAL_MOTION.environmental_drift(time, i, biome)
		var root := Vector2(x, y)
		match biome:
			0: # Wildflower banks, stalks and pale yellow blossoms.
				line(c, root + Vector2(0, 22), root + Vector2(drift, -23), Color("#547a58"), 3.2)
				for p in range(5):
					var a := float(p) * TAU / 5.0
					c.draw_circle(root + Vector2(drift, -24) + Vector2(cos(a) * 7.0, sin(a) * 7.0), 5.0, Color("#f4e5b9"))
				c.draw_circle(root + Vector2(drift, -24), 4.0, Color("#d6a763"))
			1: # Tall garden cattails with simple alternating leaves.
				for stalk in range(2):
					var tip := root + Vector2(float(stalk * 11 - 7) + drift, -31 - float(stalk) * 11)
					line(c, root + Vector2(0, 20), tip, Color("#4e8060"), 3.0)
					ellipse(c, tip, Vector2(4.5, 11.0), Color("#8d7361"), 20)
			2: # Autumn reeds swaying around seed heads.
				for reed in range(3):
					var reach := root + Vector2(float(reed - 1) * 8.0 + drift, -25 - float(reed % 2) * 16.0)
					line(c, root + Vector2(0, 18), reach, Color("#97834b"), 2.6)
					c.draw_circle(reach, 3.4, Color("#dfb56e"))
			3: # Moon mushrooms with phosphorescent caps.
				line(c, root + Vector2(-5, 20), root + Vector2(drift, -5), Color("#a1acc7"), 5.2)
				ellipse(c, root + Vector2(drift, -8), Vector2(16.0, 8.5), Color("#dfc5ee"), 24)
				c.draw_circle(root + Vector2(drift - 5.0, -11.0), 2.0, Color("#f9f1db"))
				c.draw_circle(root + Vector2(drift + 5.0, -11.0), 2.0, Color("#f9f1db"))
			4: # Translucent shard clusters.
				for shard in range(3):
					var pos := root + Vector2(float(shard - 1) * 11.0, 0)
					var tip := pos + Vector2(drift * 0.45, -34.0 - float(shard % 2) * 11.0)
					c.draw_colored_polygon(PackedVector2Array([pos + Vector2(-6, 16), tip, pos + Vector2(7, 16)]),
						Color("#c8f1f1") if shard == 1 else Color("#7bbfc9"))
			5: # Wind-bent stormgrass; thinner when adaptive quality drops.
				for blade in range(4 if quality > 0 else 2):
					var sway := drift - 8.0 + float(blade) * 4.0
					line(c, root + Vector2(float(blade - 2) * 5.0, 17),
						root + Vector2(sway, -22.0 - float(blade % 2) * 14.0),
						Color(0.68, 0.81, 0.82, 0.74), 2.1)


static func _lily(c: CanvasItem, pos: Vector2, radius: float, kind: int, t: float, ident: int, impact: float = 0.0, biome: int = 0, graphics_quality: int = 2) -> void:
	var r := radius * (1.0 + sin(t * 1.5 + float(ident)) * 0.012)
	var wiggle := sin(t * 2.1 + float(ident) * 1.7) * 0.035 + sin((1.0 - impact) * 17.0) * impact * 0.075
	c.draw_set_transform(pos + Vector2(0, impact * 7.0), wiggle, Vector2(1.0 + impact * 0.10, 1.0 - impact * 0.13))
	var center := Vector2.ZERO
	ellipse(c, center + Vector2(3, 10), Vector2(r + 4, r * 0.69), Color(0.24, 0.48, 0.49, 0.33))
	c.draw_arc(center + Vector2(0, 3), r + 12.0, 0.1, PI - 0.1, 32, Color(1, 1, 1, 0.24), 1.8, true)
	var segments := 52 if graphics_quality >= 2 else (38 if graphics_quality == 1 else 24)
	var pts := PackedVector2Array([center + Vector2(2, -2)])
	var start := 0.38 + float(ident % 5) * 0.2
	for i in range(segments):
		var a := start + 0.55 + (TAU - 1.1) * float(i) / float(segments - 1)
		pts.append(center + Vector2(cos(a) * r, sin(a) * r * 0.78))
	var dark := Color("#547c57") if kind != 2 else Color("#9d8550")
	c.draw_colored_polygon(pts, dark)
	var inner := PackedVector2Array([center])
	for i in range(segments):
		var a := start + 0.55 + (TAU - 1.1) * float(i) / float(segments - 1)
		inner.append(center + Vector2(cos(a) * (r - 4), sin(a) * (r - 4) * 0.78))
	var fill: Color = PALETTE[kind % PALETTE.size()]
	if biome == 2:
		fill = fill.lerp(Color("#d9b975"), 0.34)
	elif biome == 3 or biome == 5:
		fill = fill.lerp(Color("#7595bc"), 0.32)
	elif biome == 4:
		fill = fill.lerp(Color("#96d6c6"), 0.30)
	c.draw_colored_polygon(inner, fill)
	# Leaf veins and subtle watercolor highlights.
	for i in range(5 if graphics_quality >= 2 else 3):
		var a := start + 1.35 + (TAU - 2.7) * float(i) / 4.0
		line(c, center, center + Vector2(cos(a) * r * 0.7, sin(a) * r * 0.55), fill.darkened(0.16), 1.5)
	ellipse(c, center + Vector2(-13, -12), Vector2(9, 4), Color(1, 1, 0.85, 0.13))
	if kind == 1:
		_flower(c, center + Vector2(15, 7), 0.9, t)
	elif kind == 2:
		for i in range(5):
			c.draw_circle(center + Vector2(float((i * 23) % 41) - 20, float((i * 17) % 29) - 14), 3.3, Color("#a98f58"))
	elif kind == 3:
		_flower(c, center + Vector2(-9, 8), 0.7, t)
	c.draw_set_transform(Vector2.ZERO)

static func _flower(c: CanvasItem, at: Vector2, scale: float, t: float) -> void:
	var p := at + Vector2(0, sin(t * 2.3 + at.x) * 1.5)
	for i in range(7):
		var angle := float(i) * TAU / 7.0
		var offset := Vector2(cos(angle), sin(angle)) * 11 * scale
		ellipse(c, p + offset, Vector2(8, 5) * scale, Color("#bc7697"))
		ellipse(c, p + offset * 0.82, Vector2(6, 4) * scale, Color("#f4c1cf"))
	c.draw_circle(p, 6.0 * scale, Color("#e5b553"))
	c.draw_circle(p + Vector2(-1, -1) * scale, 2.0 * scale, Color("#fff6c7"))

static func _coin(c: CanvasItem, pos: Vector2, time: float) -> void:
	ellipse(c, pos + Vector2(0, 4), Vector2(12, 5), Color(0.27, 0.53, 0.48, 0.27))
	c.draw_circle(pos, 12.0, Color("#966635"))
	c.draw_circle(pos, 10.0, Color("#edb645"))
	c.draw_arc(pos, 7.0, 0, TAU, 30, Color("#fff1a5"), 2.3, true)
	text(c, "+", pos + Vector2(0, -3), 16, Color("#936636"))

static func _boost(c: CanvasItem, at: Vector2, time: float) -> void:
	var radius := 9.0 + sin(time * 5.0) * 1.5
	c.draw_circle(at, radius + 5.0, Color(0.55, 0.91, 0.99, 0.18))
	c.draw_arc(at, radius, 0.25 + time * 2.0, 5.35 + time * 2.0, 26, Color("#a2f0fb"), 3.0, true)
	c.draw_circle(at, 3.4, Color("#f7ffef"))

static func _friend(c: CanvasItem, at: Vector2, kind: int, scale: float = 1.0, time: float = 0.0, energy: float = 0.0) -> void:
	# Four readable species; silhouettes remain distinct even when stacked.
	var species := posmod(kind, 4)
	var colors := [Color("#73acd0"), Color("#e6aa70"), Color("#aa90c8"), Color("#97be76")]
	var bellies := [Color("#d5ecf0"), Color("#ffe2c0"), Color("#f0d9eb"), Color("#e7ecb5")]
	var main: Color = colors[species]
	var belly: Color = bellies[species]
	var ink := Color("#504b58")
	var blink := fposmod(time * (0.83 + species * 0.07) + kind * 1.93, 4.7) < 0.12
	var bob := sin(time * (3.0 + species * 0.23) + kind * 1.4) * (0.9 + energy * 2.0)
	c.draw_set_transform(at + Vector2(0, bob), sin(time * 2.4 + kind) * (0.045 + energy * 0.09), Vector2(scale * (1.0 + energy * 0.07), scale * (1.0 - energy * 0.05)))
	# Species 0: blue bird with feather crest and side wings.
	if species == 0:
		ellipse(c, Vector2(-11 - energy * 3.0, 4 - energy * 2.0), Vector2(7, 9 + energy * 3.0), ink)
		ellipse(c, Vector2(-11 - energy * 3.0, 3 - energy * 2.0), Vector2(6, 8 + energy * 3.0), main.darkened(0.16))
		ellipse(c, Vector2(10 + energy * 3.0, 4 - energy * 2.0), Vector2(7, 9 + energy * 3.0), ink)
		ellipse(c, Vector2(10 + energy * 3.0, 3 - energy * 2.0), Vector2(6, 8 + energy * 3.0), main.darkened(0.16))
		for i in range(3):
			ellipse(c, Vector2(-3 + i * 4, -15 - (1 if i == 1 else 0)), Vector2(2.8, 6), main.lightened(0.12))
	# Species 1: fox ears and a golden tail.
	elif species == 1:
		ellipse(c, Vector2(10 + sin(time * 6.0) * energy * 4.0, 8), Vector2(7, 11), ink)
		ellipse(c, Vector2(11 + sin(time * 6.0) * energy * 4.0, 7), Vector2(5, 9), main)
		for side in [-1, 1]:
			var ear := PackedVector2Array([Vector2(side * 4, -6), Vector2(side * 12, -21), Vector2(side * 12, -3)])
			c.draw_colored_polygon(ear, ink)
			var inside := PackedVector2Array([Vector2(side * 5, -7), Vector2(side * 11, -18), Vector2(side * 10, -5)])
			c.draw_colored_polygon(inside, Color("#edc3a0"))
	# Species 2: floppy bunny ears.
	elif species == 2:
		for side in [-1, 1]:
			ellipse(c, Vector2(side * (7 + energy * 2.0), -18 + energy * 3.0), Vector2(4.4, 13), ink)
			ellipse(c, Vector2(side * (7 + energy * 2.0), -18 + energy * 3.0), Vector2(3, 11), main)
			ellipse(c, Vector2(side * (7 + energy * 2.0), -18 + energy * 3.0), Vector2(1.5, 8), Color("#ebbbd3"))
	# Species 3: frog eye bumps, without mistaken fox/bunny ears.
	else:
		for side in [-1, 1]:
			c.draw_circle(Vector2(side * 7, -10), 6.5, ink)
			c.draw_circle(Vector2(side * 7, -10), 5, main)
	ellipse(c, Vector2(0, 1), Vector2(11.2, 13), ink)
	ellipse(c, Vector2(0, 0), Vector2(9.8, 11.6), main)
	ellipse(c, Vector2(0, 5), Vector2(6.5, 6.4), belly)
	for side in [-1, 1]:
		var eye := Vector2(side * 4.3, -3.6)
		if blink:
			line(c, eye + Vector2(-1.8, 0), eye + Vector2(1.8, 0), ink, 1.3)
		else:
			c.draw_circle(eye, 1.85, ink)
			c.draw_circle(eye + Vector2(-0.4, -0.4), 0.58, Color.WHITE)
	ellipse(c, Vector2(0, 0.8), Vector2(2.5, 1.7), Color("#805861"))
	if species == 0:
		var beak := PackedVector2Array([Vector2(-3, 1), Vector2(3, 1), Vector2(0, 6)])
		c.draw_colored_polygon(beak, Color("#f5c56c"))
	elif species == 3:
		line(c, Vector2(-2, 4), Vector2(2, 4), ink, 0.9)
	c.draw_set_transform(Vector2.ZERO)


static func _character(c: CanvasItem, at: Vector2, height: float, pets: int, t: float, airborne: bool, tilt: float, squash: float, sway: float, blink: float, impact: float, celebration: float, skin: int = 0, gaze: Vector2 = Vector2.ZERO, expression: int = 0) -> void:
	# Animated vector puppet: springy takeoff, landing compression and follow-through.
	var flight := clampf(height / 53.0, 0.0, 1.0)
	var jump_stretch := flight * 0.19
	var limb_swing := sin(t * 14.0) * (0.6 + flight * 4.5)
	var compression := clampf(squash + impact * 0.14, 0.0, 0.34)
	var scale_y := clampf(1.0 + jump_stretch - compression, 0.78, 1.24)
	var scale_x := clampf(1.0 - jump_stretch * 0.4 + compression * 0.48, 0.88, 1.19)
	var breathing := sin(t * 2.5) * (0.8 if not airborne else 0.0)
	var bounce := -sin(impact * PI) * 7.0
	ellipse(c, at + Vector2(2, 13), Vector2(29.0 - flight * 8.0, 12.0 - flight * 3.0), Color(0.20, 0.39, 0.45, 0.29 - flight * 0.11))
	if not airborne:
		for i in range(2):
			c.draw_arc(at + Vector2(0, 8), 34.0 + float(i) * 10.0 + fposmod(t * 12, 12), 0.15, 3.0, 34, Color(1, 1, 1, 0.17 - i * 0.05), 1.5, true)
	var body := at + Vector2(tilt * 8.0, -18.0 - height + breathing + bounce)
	# Rotate and scale the character as one articulated group.
	c.draw_set_transform(body, tilt, Vector2(scale_x, scale_y))
	var darks := [Color("#604a43"), Color("#53586b"), Color("#886048"), Color("#52644f"), Color("#805463"), Color("#594a72"), Color("#8a626c"), Color("#8c7540")]
	var furs := [Color("#b48161"), Color("#a9b9d2"), Color("#e9b379"), Color("#99bd87"), Color("#d68da7"), Color("#9988b5"), Color("#e9a6a2"), Color("#d9be67")]
	var warms := [Color("#d6a680"), Color("#dde5ed"), Color("#f3d5a1"), Color("#c8dca4"), Color("#f1c3d3"), Color("#c7b8e3"), Color("#f9d2c7"), Color("#f1dfa0")]
	var id := clampi(skin, 0, 7)
	var dark: Color = darks[id]
	var fur: Color = furs[id]
	var warm: Color = warms[id]
	# Responsive frog hind legs: tuck in flight, splay on impact, and
	# rotate slightly with the leap. Webbed toes preserve the silhouette.
	for side in [-1, 1]:
		var sgn := float(side)
		var leg_x := sgn * (23.0 + flight * 6.0 + impact * 3.0)
		var leg_y := 16.0 - flight * 8.0 + limb_swing * sgn
		ellipse(c, Vector2(leg_x, leg_y), Vector2(13.5, 17.5), dark)
		ellipse(c, Vector2(leg_x, leg_y - 1), Vector2(11.0, 15.0), fur)
		var foot := Vector2(leg_x + sgn * (5.0 + flight * 4.0), 27.0 - flight * 10.0 + limb_swing * sgn)
		ellipse(c, foot, Vector2(10.0, 5.8), dark)
		for toe in range(3):
			c.draw_circle(foot + Vector2(sgn * (float(toe - 1) * 5.0), 4.0), 3.5, warm)
	ellipse(c, Vector2(0, 3), Vector2(30, 41), dark)
	ellipse(c, Vector2(0, 1), Vector2(28, 39), fur)
	ellipse(c, Vector2(-7, 11), Vector2(18, 24), fur.lightened(0.13))
	ellipse(c, Vector2(12, -3), Vector2(11, 25), fur.darkened(0.08))
	# Raised frog-eye domes replace generic animal ears. Both catch
	# moonlit highlights and move with the springy character body.
	for side in [-1, 1]:
		var dome := Vector2(15.5 * float(side), -39.0 + sin(t * 4.4 + side) * (0.6 + flight * 1.3))
		c.draw_circle(dome, 11.3, dark)
		c.draw_circle(dome + Vector2(0, -1), 9.0, fur.lightened(0.10))
		c.draw_circle(dome + Vector2(-2, -3), 2.4, Color(1, 1, 0.91, 0.32))
	# Distinctive frog face and readable muzzle.
	ellipse(c, Vector2(0, -23), Vector2(26, 23), dark)
	ellipse(c, Vector2(0, -23), Vector2(24, 21), fur.lightened(0.06))
	ellipse(c, Vector2(0, -14), Vector2(18, 12), warm)
	for side in [-1, 1]:
		var eye := Vector2(13.0 * side, -27.0)
		if blink > 0.48:
			line(c, eye + Vector2(-3, 0), eye + Vector2(3, 0), dark, 2.2)
		else:
			ellipse(c, eye, Vector2(3.6, 3.9), Color("#352f36"))
			var pupil_offset := Vector2(clampf(gaze.x, -2.8, 2.8), clampf(-0.7 - flight * 0.6 + gaze.y, -2.2, 1.6))
			c.draw_circle(eye + pupil_offset, 1.25, Color.WHITE)
		ellipse(c, Vector2(17.0 * side, -17), Vector2(4.4, 2.9), Color("#d58979"))
	ellipse(c, Vector2(0, -14), Vector2(7, 4), Color("#70544c"))
	line(c, Vector2(0, -11), Vector2(0, -7), Color("#70544c"), 1.5)
	# Expression tracks live aim grade: gold = delight, crab = concern,
	# ordinary safe aiming = quiet concentration, never a gameplay hint
	# hidden at lower quality settings.
	if expression < 0:
		c.draw_arc(Vector2(0, -5), 4.4, PI + 0.16, TAU - 0.16, 14, Color("#81574c"), 1.65, true)
		for side in [-1, 1]:
			line(c, Vector2(float(side) * 8.5, -36), Vector2(float(side) * 16.0, -38), dark, 1.7)
	elif expression == 2:
		ellipse(c, Vector2(0, -6), Vector2(5.2, 4.0), Color("#715049"), 14)
		c.draw_arc(Vector2(0, -6), 5.3, 0.15, PI - 0.15, 14, Color("#fff0db"), 1.6, true)
	elif expression == 1:
		line(c, Vector2(-4.0, -6.0), Vector2(4.0, -6.0), Color("#81574c"), 1.5)
	else:
		c.draw_arc(Vector2(0, -8), 4.1, 0.2, PI - 0.2, 14, Color("#81574c"), 1.2, true)
	line(c, Vector2(-17, 5), Vector2(-14, 11), Color("#d7a885"), 1.1)
	line(c, Vector2(-13, 4), Vector2(-10, 9), Color("#d7a885"), 1.1)
	# Gentle frog throat breathing, tucked under the chin.
	var throat := 5.6 + sin(t * 3.0) * (0.8 if not airborne else 0.25)
	ellipse(c, Vector2(0, 20.0), Vector2(throat + 3.0, throat * 0.8), warm * Color(1, 1, 1, 0.67), 18)
	# Small forearms reach forward in flight; palms spread when landing.
	for side in [-1, 1]:
		var arm := Vector2(float(side) * 25.0, 0.0 - flight * 11.0 - impact * 4.0)
		ellipse(c, arm, Vector2(7.0, 13.0), dark)
		ellipse(c, arm + Vector2(0, 2), Vector2(5.0, 10.0), fur.lightened(0.14))
	c.draw_set_transform(Vector2.ZERO)
	# Different phases and amplified inertia per passenger maintain an organic chain.
	var stack_top := body + Vector2(0, -52.0 * scale_y)
	for i in range(mini(pets, 8)):
		var level := float(i)
		var lag := sway * (8.0 + level * 5.0)
		var follow := sin(t * 3.6 - level * 0.65) * (1.1 + level * 0.3)
		var passenger := stack_top + Vector2(lag + follow, -level * 18.0 + sin(t * 4.5 - level * 0.6) * 1.6 - celebration * (4.0 + level * 1.2))
		_friend(c, passenger, i, 0.84 + celebration * 0.07, t, clampf(flight * 0.6 + celebration * 0.85, 0.0, 1.0))
	if pets > 0:
		c.draw_circle(stack_top + Vector2(-14, -pets * 17), 2.5, Color("#fff4ad"))

static func _wave(c: CanvasItem, wave_y: float, t: float, graphics_quality: int = 2) -> void:
	if wave_y > H + 70:
		return
	var pts := PackedVector2Array()
	var wave_steps := 45 if graphics_quality >= 2 else (31 if graphics_quality == 1 else 23)
	for i in range(wave_steps):
		var x := float(i) * W / float(wave_steps - 1)
		var y := wave_y + sin(x * 0.026 + t * 2.3) * 9.0 + sin(x * 0.074 - t) * 3.5
		pts.append(Vector2(x, y))
	pts.append(Vector2(W, H + 1000))
	pts.append(Vector2(0, H + 1000))
	c.draw_colored_polygon(pts, Color("#242c55"))
	var foam_steps := 33 if graphics_quality >= 2 else (19 if graphics_quality == 1 else 11)
	for i in range(foam_steps):
		var x := float(i) * W / float(foam_steps - 1)
		var y := wave_y + sin(x * 0.026 + t * 2.3) * 9.0 + sin(x * 0.074 - t) * 3.5
		c.draw_circle(Vector2(x, y), 6.4, Color("#fff1dd"))
		if i % 2 == 0:
			c.draw_circle(Vector2(x + 5, y + 6), 3.5, Color("#fff1dd"))
	var bubbles := PackedVector2Array()
	var bubble_steps := 36 if graphics_quality >= 2 else (20 if graphics_quality == 1 else 12)
	for i in range(bubble_steps):
		var x := float(i) * W / float(bubble_steps - 1)
		bubbles.append(Vector2(x, wave_y + 39 + sin(x * 0.018 + t * 1.4) * 15))
	bubbles.append(Vector2(W, H + 1000))
	bubbles.append(Vector2(0, H + 1000))
	c.draw_colored_polygon(bubbles, Color(0.32, 0.45, 0.65, 0.27))

static func _aim_guide(c: CanvasItem, from: Vector2, target: Vector2, t: float, valid: bool, danger_seconds: float = 0.0, perfect: bool = false) -> void:
	# Gold indicates a scored PERFECT landing; safe green and crab warning
	# remain separate. Preview grade uses the exact launch scoring function.
	var gold := valid and perfect
	var ink := Color("#ffe5a4") if gold else (Color("#dcfbc3") if valid else Color("#ffb5a3"))
	var accent := Color("#a77e32") if gold else (Color("#5f895f") if valid else Color("#ac5c63"))
	var pulse := sin(t * 7.5) * 3.0
	ellipse(c, target + Vector2(0, 6), Vector2(27, 13), Color(0.20, 0.30, 0.37, 0.25))
	c.draw_arc(target, 25.0 + pulse, 0.05, TAU + 0.05, 52, Color("#4e5954"), 6.5, true)
	c.draw_arc(target, 25.0 + pulse, 0.05, TAU + 0.05, 52, ink, 4.0, true)
	# The dotted parabola terminates on the actual resolved lily when valid.
	for i in range(1, 14):
		var portion := float(i) / 14.0
		var point := from.lerp(target, portion) + Vector2(0, -sin(portion * PI) * 64)
		c.draw_circle(point + Vector2(1.5, 2.0), 4.5 * (1.0 - portion * 0.35), Color(0.20, 0.30, 0.34, 0.35))
		c.draw_circle(point, 3.6 * (1.0 - portion * 0.35), ink)
	if valid:
		if gold:
			c.draw_arc(target, 33.0 + sin(t * 6.0) * 2.0, 0.0, TAU, 32,
				Color(1.0, 0.84, 0.42, 0.46), 2.0, true)
			rr(c, Rect2(target.x - 67, target.y - 70, 134, 28), 11, Color("#fff2c4"), accent, 1.5)
			text(c, "PERFECT!", target + Vector2(0, -56), 16, accent, true, 118.0)
		else:
			rr(c, Rect2(target.x - 67, target.y - 70, 134, 28), 11, CREAM, accent, 1.5)
			text(c, "SAFE LANDING", target + Vector2(0, -56), 14, accent)
	elif danger_seconds > 0.0:
		rr(c, Rect2(target.x - 85, target.y - 74, 170, 32), 12, Color("#fff1d9"), Color("#cd685e"), 1.8)
		text(c, "CRAB - WAIT %.1fs" % danger_seconds, target + Vector2(0, -57), 13, Color("#a34740"), false, 154.0)
	else:
		rr(c, Rect2(target.x - 50, target.y - 70, 100, 28), 11, CREAM, accent, 1.5)
		text(c, "SPLASH!", target + Vector2(0, -56), 14, accent)

static func _hud(c: CanvasItem, score: int, best: int, pets: int, distance: int, wave_m: float, cam: float, combo: int, mode: int, chapters: RefCounted, campaign_stage: int, biome: int, biome_banner: float) -> void:
	rr(c, Rect2(14, 17, 101, 35), 17, CREAM, Color("#8c806e"), 1.6)
	text(c, "★  x%d" % pets, Vector2(65, 34), 17, Color("#755b51"))
	rr(c, Rect2(138, 14, 259, 44), 21, CREAM, Color("#8c806e"), 1.7)
	text(c, "%s" % _commas(score), Vector2(267, 35), 25, INK)
	rr(c, Rect2(415, 17, 111, 35), 17, CREAM, Color("#8c806e"), 1.5)
	text(c, "%d m" % distance, Vector2(470, 34), 17, INK)
	if mode in [1, 2, 3]:
		rr(c, Rect2(476, 81, 48, 45), 14, CREAM, Color("#8c806e"), 1.5)
		line(c, Vector2(493, 92), Vector2(493, 113), Color("#6c6470"), 4.0)
		line(c, Vector2(507, 92), Vector2(507, 113), Color("#6c6470"), 4.0)
	if (campaign_stage >= 0 or campaign_stage == -2) and mode in [1, 2, 3, 4, 9]:
		var level: Dictionary = chapters.chapter(campaign_stage) if campaign_stage >= 0 else {"target": 180}
		var target := int(level["target"])
		var fraction := clampf(float(distance) / float(target), 0.0, 1.0)
		rr(c, Rect2(131, 111, 277, 36), 17, Color("#f7edda"), Color("#817e75"), 1.4)
		rr(c, Rect2(143, 139, 252, 4), 2, Color("#d2d1c0"))
		rr(c, Rect2(143, 139, 252.0 * fraction, 4), 2, Color("#92bd84"))
		var progress_title := "DAILY RIVER" if campaign_stage == -2 else "CHAPTER %d" % (campaign_stage + 1)
		text(c, "%s   %d/%d m" % [progress_title, distance, target], Vector2(270, 126), 15, INK)
	if biome_banner > 0.0 and mode in [1, 2, 3]:
		var names := ["SUNNY BANKS", "LILY GARDEN", "GOLDEN REEDS", "MOONLIT POND", "CRYSTAL RIVER", "STORMY RAPIDS"]
		var alpha := minf(1.0, biome_banner * 1.5)
		var bg := Color("#fff0d4")
		bg.a = alpha * 0.94
		rr(c, Rect2(121, 168, 298, 56), 22, bg)
		var ink := Color("#506368")
		ink.a = alpha
		text(c, names[clampi(biome, 0, 5)], Vector2(270, 195), 20, ink)
	if mode in [1, 2, 3] and wave_m > cam - 32:
		rr(c, Rect2(180, 67, 180, 31), 14, Color("#fff0d9"), Color("#c57e6e"), 1.5)
		text(c, "WAVE APPROACHING!", Vector2(270, 83), 13, Color("#a15c53"))
	elif combo >= 3 and mode in [1, 2, 3]:
		text(c, "COMBO x%d!" % combo, Vector2(270, 84), 19, Color("#f7f1b2"), true)

static func _start_overlay(c: CanvasItem, time: float, leaves: int, skin: int, daily: RefCounted, monetization: Node, chapters: RefCounted, best_endless_m: int = 0) -> void:
	rr(c, Rect2(62, 128, 416, 179), 34, Color("#fbedd6"), Color("#ae977d"), 3)
	text(c, "JUMPY FROG", Vector2(270, 186), 43, Color("#5b5868"), true, 365.0)
	text(c, "A RIVER ADVENTURE", Vector2(270, 244), 19, Color("#a17f74"))
	rr(c, Rect2(169, 321, 202, 44), 18, CREAM, Color("#a28f72"), 1.5)
	text(c, "LEAVES  %d" % leaves, Vector2(270, 341), 21, Color("#5c815c"))
	if best_endless_m > 0:
		text(c, "BEST ENDLESS   %d m" % best_endless_m, Vector2(270, 382), 16, Color("#f8f1ce"), true, 360.0)
	if monetization.premium:
		text(c, "AD-FREE FOREVER", Vector2(270, 416), 20, Color("#5a9462"))
	elif monetization.purchase_ready:
		rr(c, Rect2(139, 403, 262, 58), 23, Color("#f3dfba"), Color("#a88e68"), 2)
		var label: String = "REMOVE ADS " + (monetization.price_label if not monetization.price_label.is_empty() else "• PLAY STORE")
		text(c, label, Vector2(270, 429), 18, Color("#755d4f"))
	rr(c, Rect2(139, 549, 262, 67), 23, Color("#f2d79d"), Color("#92734d"), 2.1)
	text(c, "CHAPTERS  %d / 6" % chapters.completed_count(), Vector2(270, 579), 22, Color("#60533f"), false, 238.0)
	rr(c, Rect2(62, 470, 197, 62), 22, Color("#8fbc94"), Color("#658b75"), 2)
	text(c, "ENDLESS", Vector2(160, 499), 22, Color("#f7f6df"), true)
	rr(c, Rect2(281, 470, 197, 62), 22, Color("#aabedc"), Color("#717e9b"), 2)
	text(c, "DAILY RIVER", Vector2(379, 494), 19, Color("#fff5db"), true, 178.0)
	var today_status := "DONE" if daily.river_complete_today() else "+25 LEAVES"
	text(c, today_status, Vector2(379, 517), 13, Color("#506277"))
	rr(c, Rect2(139, 634, 262, 58), 23, Color("#c6e2ba"), Color("#748b6b"), 2.2)
	text(c, "MISSIONS %d/3  •  WEEK %d/3" % [daily.completion_count(), daily.weekly_completion_count()], Vector2(270, 660), 16, Color("#4b654b"), false, 238.0)
	rr(c, Rect2(139, 710, 262, 58), 23, Color("#a8d2aa"), Color("#668569"), 2.2)
	text(c, "CUSTOMIZE", Vector2(270, 736), 24, Color("#3c5543"), false, 230.0)
	rr(c, Rect2(64, 783, 412, 112), 29, Color("#fcf0d9"), Color("#907b69"), 2.0)
	text(c, "PULL BACK · RELEASE", Vector2(270, 816), 22, INK, false, 375.0)
	text(c, "Hop from lily to lily!", Vector2(270, 863), 19, Color("#947b6b"))
	c.draw_circle(Vector2(270 + sin(time * 3) * 16, 907), 5, Color("#fff6d0"))

static func _lost_overlay(c: CanvasItem, score: int, best: int, run_leaves: int, monetization: Node, rewarded_this_run: bool, run_hops: int, run_perfects: int, run_peak_combo: int, run_friends: int, run_new_record: bool, run_grade: String, next_weekly: Dictionary, distance: int = 0, best_endless_m: int = 0, campaign_stage: int = -1, lifetime_challenge_wins: Array = []) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color(0.16, 0.21, 0.32, 0.55))
	rr(c, Rect2(42, 197, 456, 581), 32, Color("#fff0d9"), Color("#8a716a"), 4)
	text(c, "SPLASH!", Vector2(270, 246), 42, Color("#5c668a"), true)
	text(c, "NEW PERSONAL RECORD!" if run_new_record else "YOUR RIVER JOURNEY", Vector2(270, 281), 17, Color("#548561") if run_new_record else Color("#927b70"))
	text(c, _commas(score), Vector2(270, 343), 50, INK, true)
	text(c, "BEST SCORE  %s" % _commas(best), Vector2(270, 374), 16, Color("#8c756c"))
	rr(c, Rect2(94, 394, 352, 37), 17, Color("#e3eccf"), Color("#93a485"), 1.2)
	text(c, run_grade, Vector2(270, 412), 19, Color("#526d5c"), false, 314.0)
	# All run stats are read from real landings, not displayed estimates.
	var captions := ["HOPS", "PERFECT", "BEST COMBO", "FRIENDS"]
	var values := [run_hops, run_perfects, run_peak_combo, run_friends]
	for i in range(4):
		var x := 75.0 + float(i) * 100.0
		rr(c, Rect2(x, 448, 91, 61), 13, Color("#f3e6ce"), Color("#bdab94"), 1.2)
		text(c, str(values[i]), Vector2(x + 45, 466), 22, INK, false, 78.0)
		text(c, captions[i], Vector2(x + 45, 491), 11, Color("#866e61"), false, 79.0)
	text(c, "LEAVES EARNED  +%d" % run_leaves, Vector2(270, 527), 17, Color("#5b865e"))
	if campaign_stage == -1:
		text(c, "RUN %d m   •   BEST %d m" % [distance, best_endless_m], Vector2(270, 550), 14, Color("#877467"), false, 360.0)
		# Lifetime mastery adds an objective beyond a single endless run;
		# four individual counters are always genuine paid completions.
		if lifetime_challenge_wins.size() == 4:
			var total_mastered := 0
			var mastered_categories := 0
			for value in lifetime_challenge_wins:
				var n := maxi(0, int(value))
				total_mastered += n
				if n > 0:
					mastered_categories += 1
			text(c, "CHALLENGE MASTERY  %d/4  •  %d WINS" % [mastered_categories, total_mastered],
				Vector2(270, 636), 15, Color("#567d65"), true, 394.0)
	if not next_weekly.is_empty():
		text(c, "NEXT WEEKLY GOAL", Vector2(270, 729), 14, Color("#8b7969"), false, 350.0)
		text(c, "%s  %d/%d" % [String(next_weekly["title"]), int(next_weekly["progress"]), int(next_weekly["target"])], Vector2(270, 748), 15, Color("#516f57"), false, 350.0)
	else:
		text(c, "ALL WEEKLY GOALS COMPLETED", Vector2(270, 742), 15, Color("#516f57"))
	# Preserve exact touch hitboxes used by the existing retry / home actions.
	rr(c, Rect2(70, 565, 213, 59), 23, Color("#a5ce7c"), Color("#5b7a59"), 2)
	text(c, "RETRY", Vector2(175, 593), 24, Color("#435443"))
	rr(c, Rect2(294, 565, 178, 59), 23, Color("#eee0c2"), Color("#92836d"), 2)
	text(c, "HOME", Vector2(382, 593), 24, INK)
	if not rewarded_this_run and monetization.can_watch_rewarded():
		rr(c, Rect2(80, 651, 390, 62), 23, Color("#d9e6ad"), Color("#7f9a64"), 2)
		text(c, "WATCH AD  •  +5 LEAVES", Vector2(275, 680), 21, Color("#56634c"))
	elif rewarded_this_run:
		text(c, "BONUS CLAIMED", Vector2(270, 664), 17, Color("#548463"))


static func _pause_overlay(c: CanvasItem, muted: bool, monetization: Node, haptics_enabled: bool, android_tones_enabled: bool) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color(0.15, 0.22, 0.29, 0.60))
	rr(c, Rect2(55, 226, 430, 639 if (monetization.billing != null or monetization.ads != null) else 449), 32, Color("#fff0d9"), Color("#887b72"), 3)
	text(c, "PAUSED", Vector2(270, 290), 43, Color("#5a6474"), true)
	text(c, "The river can wait.", Vector2(270, 343), 18, Color("#897871"))
	rr(c, Rect2(108, 374, 324, 60), 22, Color("#d5e9e5"), Color("#799e9b"), 1.8)
	text(c, "DEVICE DIAGNOSTICS", Vector2(270, 403), 20, Color("#456d70"))
	rr(c, Rect2(108, 460, 324, 66), 27, Color("#b3d185"), Color("#5e7e60"), 2)
	text(c, "RESUME", Vector2(270, 494), 26, Color("#49564b"))
	if OS.has_feature("android"):
		rr(c, Rect2(108, 544, 154, 66), 22, Color("#d3e6cf") if android_tones_enabled else Color("#eee0c2"), Color("#92836d"), 2)
		rr(c, Rect2(278, 544, 154, 66), 22, Color("#d3e6cf") if haptics_enabled else Color("#eee0c2"), Color("#92836d"), 2)
		text(c, "TONES: " + ("ON" if android_tones_enabled else "OFF"), Vector2(185, 575), 17, INK)
		text(c, "VIBRATE: " + ("ON" if haptics_enabled else "OFF"), Vector2(355, 575), 16, INK)
		text(c, "Tones: experimental Android system audio", Vector2(270, 620), 13, Color("#917b72"))
	else:
		rr(c, Rect2(108, 544, 324, 66), 27, Color("#eee0c2"), Color("#92836d"), 2)
		text(c, "SOUND: OFF" if muted else "SOUND: ON", Vector2(270, 577), 22, INK)
	if monetization.purchase_ready and not monetization.premium:
		rr(c, Rect2(108, 633, 324, 62), 22, Color("#eed8ad"), Color("#a48a68"), 2)
		var label: String = "NO ADS " + (monetization.price_label if not monetization.price_label.is_empty() else "• PLAY")
		text(c, label, Vector2(270, 662), 21, INK)
	if monetization.ads != null:
		rr(c, Rect2(108, 704, 324, 56), 22, Color("#e8e1d7"), Color("#968b80"), 1.5)
		text(c, "PRIVACY OPTIONS", Vector2(270, 731), 18, INK)
	if monetization.billing != null and not monetization.premium:
		rr(c, Rect2(108, 781, 324, 54), 22, Color("#e5d6bb"), Color("#968b80"), 1.5)
		text(c, "RESTORE PURCHASE", Vector2(270, 806), 19, INK)

static func _device_diagnostics_overlay(c: CanvasItem, stats: Dictionary, graphics_quality: int, android_tones_enabled: bool, haptics_enabled: bool) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color(0.12, 0.19, 0.25, 0.70))
	rr(c, Rect2(40, 191, 460, 638), 32, Color("#fff3e2"), Color("#7f9a92"), 3.0)
	text(c, "DEVICE DIAGNOSTICS", Vector2(270, 250), 29, Color("#456c71"), true)
	text(c, "LIVE PERFORMANCE SAMPLE", Vector2(270, 296), 16, Color("#75867e"))
	var recorded: int = int(stats.get("frames", 0))
	if recorded == 0:
		text(c, "PLAY FOR 30 SECONDS FIRST", Vector2(270, 387), 20, INK)
	else:
		var fps: float = float(stats.get("fps", 0.0))
		var p95: float = float(stats.get("p95_ms", 0.0))
		var slow_pct: float = float(stats.get("slow_pct", 0.0))
		for i in range(3):
			var labels := ["AVERAGE FPS", "95% FRAME TIME", "SLOW FRAMES"]
			var values := ["%.1f" % fps, "%.1f ms" % p95, "%.1f%%" % slow_pct]
			var y := 334.0 + float(i) * 80.0
			rr(c, Rect2(83, y, 374, 66), 16, Color("#eaf2e3"), Color("#9aafa2"), 1.2)
			text(c, labels[i], Vector2(195, y + 25), 15, Color("#617b71"))
			text(c, values[i], Vector2(380, y + 26), 19, INK, true)
		text(c, "%d frames sampled (recent ~4 sec)" % recorded, Vector2(270, 603), 15, Color("#65766d"))
	var tier_names := ["LOW", "BALANCED", "HIGH"]
	text(c, "GRAPHICS: " + tier_names[clampi(graphics_quality, 0, 2)], Vector2(270, 638), 19, Color("#567560"), true)
	if OS.has_feature("android"):
		text(c, "AUDIO: SAFE DRIVER / " + ("SYSTEM TONES ON" if android_tones_enabled else "SILENT"), Vector2(270, 666), 14, Color("#8e705b"))
	else:
		text(c, "AUDIO: DESKTOP DRIVER", Vector2(270, 666), 15, Color("#8e705b"))
	text(c, "HAPTICS: " + ("ON" if haptics_enabled else "OFF"), Vector2(270, 691), 14, Color("#677a6c"))
	rr(c, Rect2(100, 716, 340, 74), 22, Color("#a8ceb0"), Color("#6d9783"), 2)
	text(c, "BACK TO PAUSE", Vector2(270, 751), 22, Color("#43634f"))


static func _wardrobe_overlay(c: CanvasItem, time: float, leaves: int, selected: int, unlocked: int, prices: Array, page: int) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color(0.15, 0.22, 0.29, 0.67))
	rr(c, Rect2(29, 226, 482, 670), 33, Color("#fff0dc"), Color("#957d6b"), 3)
	text(c, "RIVER WARDROBE", Vector2(270, 275), 32, Color("#595468"), true)
	text(c, "LEAVES  %d" % leaves, Vector2(270, 316), 21, Color("#66835b"))
	var names := ["ORIGINAL", "MIST", "SUNSHINE", "MOSS", "BERRY", "DUSK", "LOTUS", "GOLD"]
	var fill := [Color("#b48161"), Color("#a9b9d2"), Color("#e9b379"), Color("#99bd87"), Color("#d68da7"), Color("#9988b5"), Color("#e9a6a2"), Color("#d9be67")]
	for i in range(4):
		var index := i + page * 4
		var px := 66.0 + float(i % 2) * 216.0
		var py := 340.0 + float(i / 2) * 162.0
		var is_owned := (unlocked & (1 << index)) != 0
		var is_selected := index == selected
		var border := Color("#74a17b") if is_selected else Color("#ae9c82")
		rr(c, Rect2(px, py, 192, 146), 20, Color("#fcf7e9") if is_owned else Color("#e8e2d7"), border, 3.0 if is_selected else 1.5)
		ellipse(c, Vector2(px + 96, py + 57), Vector2(30, 37), fill[index])
		ellipse(c, Vector2(px + 96, py + 59), Vector2(18, 14), fill[index].lightened(0.23))
		for side in [-1, 1]:
			c.draw_circle(Vector2(px + 88 + side * 11, py + 42), 3.0, INK)
		text(c, names[index], Vector2(px + 96, py + 108), 18, INK)
		var status := "EQUIPPED" if is_selected else ("SELECT" if is_owned else "%d LEAVES" % int(prices[index]))
		text(c, status, Vector2(px + 96, py + 130), 14, Color("#53815d") if is_owned else Color("#a67c57"))
	rr(c, Rect2(139, 694, 262, 58), 23, Color("#ead9b4"), Color("#95846a"), 2)
	text(c, "PAGE %d/2  -  SWITCH" % (page + 1), Vector2(270, 722), 18, INK)
	rr(c, Rect2(100, 770, 340, 74), 25, Color("#a7ca83"), Color("#577c5b"), 2.5)
	text(c, "BACK TO RIVER", Vector2(270, 807), 24, Color("#3c5745"))

static func _goals_overlay(c: CanvasItem, daily: RefCounted) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color(0.15, 0.22, 0.29, 0.68))
	rr(c, Rect2(31, 235, 478, 663), 34, Color("#fff1db"), Color("#93806e"), 3)
	text(c, "RIVER MISSIONS", Vector2(270, 284), 33, Color("#595669"), true)
	text(c, "DAILY STREAK  %d DAY(S)" % daily.streak_days, Vector2(270, 321), 18, Color("#6a835a"))
	for i in range(3):
		var goal: Dictionary = daily.goal_at(i)
		var y := 351.0 + float(i) * 101.0
		var progress: int = daily.progress(i)
		var target: int = int(goal["target"])
		var completed: bool = (daily.goals_claimed & (1 << i)) != 0
		rr(c, Rect2(66, y, 408, 88), 19, Color("#f5f1dc") if completed else Color("#fae4d0"), Color("#a7a090"), 1)
		text(c, String(goal["title"]), Vector2(270, y + 20), 19, INK)
		text(c, "%d / %d     •     +%d LEAVES" % [mini(progress, target), target, int(goal["reward"])], Vector2(270, y + 48), 16, Color("#548263"))
		rr(c, Rect2(111, y + 70, 318, 7), 3.5, Color("#dbcbb2"))
		var ratio: float = minf(1.0, float(progress) / float(target))
		if ratio > 0.001:
			rr(c, Rect2(111, y + 70, 318.0 * ratio, 7), 3.5, Color("#89b874"))
	# Weekly expedition rewards are automatic. Each checked goal has a
	# separate counter persisted across launches until Monday 00:00 UTC.
	rr(c, Rect2(62, 657, 416, 110), 17, Color("#e9f0da"), Color("#8b9c80"), 1.4)
	text(c, "WEEKLY EXPEDITION  %d/3" % daily.weekly_completion_count(), Vector2(270, 677), 17, Color("#547456"))
	for i in range(3):
		var goal: Dictionary = daily.WEEKLY_GOALS[i]
		var progress: int = mini(daily.weekly_progress(i), int(goal["target"]))
		var finished: bool = (daily.weekly_claimed & (1 << i)) != 0
		var y := 696.0 + float(i) * 21.0
		var status := "✓" if finished else "·"
		text(c, "%s %s" % [status, String(goal["title"])], Vector2(188, y), 13, Color("#45694e") if finished else INK)
		text(c, "%d/%d  +%d" % [progress, int(goal["target"]), int(goal["reward"])], Vector2(402, y), 13, Color("#547456"))
	var milestone: Dictionary = daily.next_milestone()
	text(c, "CAREER MILESTONES  %d/%d" % [daily.milestone_count(), daily.milestone_total()], Vector2(270, 786), 15, Color("#6a815e"))
	if milestone.is_empty():
		text(c, "ALL CAREER MILESTONES COMPLETED", Vector2(270, 807), 13, INK)
	else:
		text(c, "%s  %d/%d  +%d" % [String(milestone["title"]), mini(int(milestone["progress"]), int(milestone["target"])), int(milestone["target"]), int(milestone["reward"])], Vector2(270, 807), 13, INK)
	rr(c, Rect2(100, 831, 340, 55), 23, Color("#accd85"), Color("#5e7e59"), 2)
	text(c, "BACK", Vector2(270, 859), 23, Color("#3f5847"))


static func _chapter_select_overlay(c: CanvasItem, chapters: RefCounted) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color(0.12, 0.18, 0.28, 0.76))
	rr(c, Rect2(28, 161, 484, 740), 33, Color("#fff1db"), Color("#8a7e72"), 3.0)
	text(c, "THE SIX RIVERS", Vector2(270, 220), 34, Color("#53576b"), true)
	text(c, "Finish each river to unlock the next", Vector2(270, 260), 18, Color("#998574"))
	var colors := [Color("#93bf92"), Color("#8ac2a8"), Color("#d9bf83"), Color("#9ba4c9"), Color("#82b5bf"), Color("#878fa7")]
	for i in range(6):
		var x := 65.0 + float(i % 2) * 215.0
		var y := 335.0 + float(i / 2) * 138.0
		var active: bool = chapters.can_play(i)
		var level: Dictionary = chapters.chapter(i)
		var stars: int = int(chapters.medals[i])
		rr(c, Rect2(x, y, 192, 123), 22, (colors[i] if active else Color("#d5d5d3")), Color("#858576"), 2.0)
		c.draw_circle(Vector2(x + 26, y + 28), 17, Color("#f7f1de"))
		text(c, str(i + 1) if active else "×", Vector2(x + 26, y + 27), 20, Color("#626474"))
		text(c, String(level["name"]), Vector2(x + 98, y + 61), 17, Color("#414854") if active else Color("#777a7e"))
		if active:
			var medal_text := "★".repeat(stars) + "☆".repeat(3 - stars)
			text(c, medal_text, Vector2(x + 96, y + 95), 24, Color("#fff2be"), true)
		else:
			text(c, "LOCKED", Vector2(x + 96, y + 95), 19, Color("#6b6d70"))
	rr(c, Rect2(105, 790, 330, 75), 25, Color("#a8d1a3"), Color("#708768"), 2.0)
	text(c, "BACK TO HOME", Vector2(270, 826), 25, Color("#3d594b"))


static func _daily_clear_overlay(c: CanvasItem, reward: int, daily: RefCounted, score: int) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color(0.10, 0.19, 0.30, 0.72))
	rr(c, Rect2(39, 243, 462, 515), 34, Color("#fff2d9"), Color("#a89479"), 4.0)
	text(c, "DAILY RIVER!", Vector2(270, 306), 43, Color("#577582"), true)
	text(c, "TODAY'S CHALLENGE COMPLETED", Vector2(270, 357), 20, Color("#697d75"))
	text(c, "★", Vector2(270, 435), 78, Color("#e0b451"), true)
	text(c, "SCORE  %s" % _commas(score), Vector2(270, 505), 26, INK)
	text(c, "TODAY'S BEST  %s" % _commas(daily.river_best_score), Vector2(270, 548), 18, Color("#827d77"))
	var prize := "+%d LEAVES" % reward if reward > 0 else "TODAY'S BONUS ALREADY CLAIMED"
	text(c, prize, Vector2(270, 588), 20, Color("#668957"))
	rr(c, Rect2(72, 633, 195, 66), 24, Color("#9fcf8b"), Color("#638761"), 2)
	text(c, "PLAY AGAIN", Vector2(169, 663), 19, Color("#435c49"))
	rr(c, Rect2(285, 633, 190, 66), 24, Color("#e8d8b8"), Color("#938573"), 2)
	text(c, "HOME", Vector2(380, 663), 25, Color("#6a5d54"))


static func _chapter_clear_overlay(c: CanvasItem, index: int, stars: int, reward: int, chapters: RefCounted) -> void:
	if index < 0:
		return
	c.draw_rect(Rect2(0, 0, W, H), Color(0.11, 0.20, 0.26, 0.67))
	rr(c, Rect2(39, 243, 462, 515), 34, Color("#fff2d9"), Color("#a89479"), 4.0)
	text(c, "RIVER COMPLETED!", Vector2(270, 305), 36, Color("#566d70"), true)
	var level: Dictionary = chapters.chapter(index)
	text(c, String(level["name"]), Vector2(270, 356), 23, Color("#827d77"))
	var medal_text := "★".repeat(stars) + "☆".repeat(3 - stars)
	text(c, medal_text, Vector2(270, 443), 58, Color("#d7a74c"), true)
	text(c, "CHAPTER %d / 6" % (index + 1), Vector2(270, 497), 21, Color("#717078"))
	text(c, "+%d LEAVES" % reward if reward > 0 else "MEDAL RECORDED", Vector2(270, 548), 23, Color("#668957"))
	rr(c, Rect2(72, 633, 195, 66), 24, Color("#9fcf8b"), Color("#638761"), 2.0)
	text(c, "NEXT" if chapters.can_play(index + 1) else "HOME", Vector2(169, 663), 25, Color("#435c49"))
	rr(c, Rect2(285, 633, 190, 66), 24, Color("#e8d8b8"), Color("#938573"), 2.0)
	text(c, "HOME", Vector2(380, 663), 25, Color("#6a5d54"))


static func _commas(value: int) -> String:
	var s := str(value)
	var result := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			result += ","
		result += s[i]
	return result
