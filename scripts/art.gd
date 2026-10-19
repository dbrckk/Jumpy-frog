extends RefCounted
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

static func text(c: CanvasItem, value: String, center: Vector2, size: int, color: Color = INK, shadow: bool = false) -> void:
	var font: Font = ThemeDB.fallback_font
	var origin := center - Vector2(0, -float(size) * 0.36)
	if shadow:
		c.draw_string(font, origin + Vector2(1.4, 2.2), value, HORIZONTAL_ALIGNMENT_CENTER, -1, size, Color("#655d6b"))
	c.draw_string(font, origin, value, HORIZONTAL_ALIGNMENT_CENTER, -1, size, color)

static func scene(c: CanvasItem, time: float, cam: float, pads: Array, player_at: Vector2, jump_z: float, pets: int, wave_m: float, aiming: bool, aim_at: Vector2, aim_valid: bool, mode: int, score: int, best: int, combo: int, particles: Array, distance: int, muted: bool, skin: int, leaves: int, unlocked: int, prices: Array, run_leaves: int, daily: RefCounted, monetization: Node, rewarded_this_run: bool, wardrobe_page: int, tilt: float, squash: float, sway: float, blink: float, impact: float, pad_impacts: Dictionary, celebration: float, float_texts: Array, ripples: Array, shake: Vector2, flash: float, chapters: RefCounted, campaign_stage: int, biome_banner: float, clear_medal: int, clear_reward: int, haptics_enabled: bool, android_tones_enabled: bool, graphics_quality: int = 2) -> void:
	var biome: int = chapters.biome_at(cam, campaign_stage)
	# Shake is applied only to the illustrated world; HUD remains legible.
	c.draw_set_transform(shake)
	_river(c, time, cam, biome, graphics_quality)
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
		var screen := Vector2(float(pad["x"]), ANCHOR - (float(pad["m"]) - cam) * SCALE) + shake
		if screen.y < -125.0 or screen.y > H + 125.0:
			continue
		_lily(c, screen, float(pad["r"]), int(pad["kind"]), time, int(pad["id"]), float(pad_impacts.get(int(pad["id"]), 0.0)), chapters.biome_at(float(pad["m"]), campaign_stage), graphics_quality)
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
	if aiming:
		_aim_guide(c, player_at + shake, aim_at + shake, time, aim_valid)
	_character(c, player_at + shake, jump_z, pets, time, mode == 3, tilt, squash, sway, blink, impact, celebration, skin)
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
	if mode == 0:
		_start_overlay(c, time, leaves, skin, daily, monetization, chapters)
	if mode == 4:
		_lost_overlay(c, score, best, run_leaves, monetization, rewarded_this_run)
	if mode == 5:
		_pause_overlay(c, muted, monetization, haptics_enabled, android_tones_enabled)
	if mode == 6:
		_wardrobe_overlay(c, time, leaves, skin, unlocked, prices, wardrobe_page)
	if mode == 7:
		_goals_overlay(c, daily)
	if mode == 8:
		_chapter_select_overlay(c, chapters)
	if mode == 9:
		if campaign_stage == -2:
			_daily_clear_overlay(c, clear_reward, daily, score)
		else:
			_chapter_clear_overlay(c, campaign_stage, clear_medal, clear_reward, chapters)

static func _river(c: CanvasItem, t: float, cam: float, biome: int, graphics_quality: int = 2) -> void:
	# Each chapter has its own original illustrated color script; no external textures.
	var earth := [Color("#a6c49e"), Color("#9cc69a"), Color("#d3bd91"), Color("#77879b"), Color("#9cbcc4"), Color("#7c8297")]
	var water_colors := [Color("#81abb9"), Color("#79b5a8"), Color("#b0b8b0"), Color("#647caa"), Color("#84b7cb"), Color("#627e9b")]
	var sand_colors := [Color("#f0e1b7"), Color("#e3e7c6"), Color("#f1d5a7"), Color("#afb4d0"), Color("#d9e5e5"), Color("#adb7c2")]
	var plants := [Color("#558765"), Color("#608c72"), Color("#947f57"), Color("#657c91"), Color("#668f92"), Color("#718078")]
	var b := clampi(biome, 0, 5)
	c.draw_rect(Rect2(0, 0, W, H), earth[b])
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
		line(c, left[i] + Vector2(-9, 0), left[i + 1] + Vector2(-9, 0), sand_colors[b], 18)
		line(c, right[i] + Vector2(9, 0), right[i + 1] + Vector2(9, 0), Color("#e9dfbd"), 18)
	water.append_array(left)
	for i in range(right.size() - 1, -1, -1):
		water.append(right[i])
	c.draw_colored_polygon(water, water_colors[b])
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
		c.draw_colored_polygon(band_poly, water_colors[b].darkened(0.28) * Color(1, 1, 1, 0.10))
	for i in range(left.size() - 1):
		line(c, left[i], left[i + 1], plants[b], 3.5)
		line(c, right[i], right[i + 1], plants[b].lightened(0.06), 3.5)
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
			line(c, origin, tip, plants[b].darkened(0.10), 2.0)
			if (i + stalk) % 4 == 0:
				ellipse(c, tip, Vector2(3.2, 8.0), Color("#9d676d"))
			else:
				ellipse(c, tip + Vector2(0, -3), Vector2(2.2, 5.0), plants[b].lightened(0.14))
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


static func _character(c: CanvasItem, at: Vector2, height: float, pets: int, t: float, airborne: bool, tilt: float, squash: float, sway: float, blink: float, impact: float, celebration: float, skin: int = 0) -> void:
	# Animated vector puppet: springy takeoff, landing compression and follow-through.
	var flight := clampf(height / 53.0, 0.0, 1.0)
	var jump_stretch := flight * 0.19
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
	# Behind-the-body paws, tail and ears.
	ellipse(c, Vector2(21, 24), Vector2(12, 7), dark)
	ellipse(c, Vector2(-22, 23), Vector2(12, 7), dark)
	ellipse(c, Vector2(23, 11), Vector2(10, 13), Color("#916a53"))
	ellipse(c, Vector2(-23, 10), Vector2(10, 13), Color("#916a53"))
	ellipse(c, Vector2(27, 18), Vector2(7, 6), warm)
	ellipse(c, Vector2(0, 3), Vector2(30, 41), dark)
	ellipse(c, Vector2(0, 1), Vector2(28, 39), fur)
	ellipse(c, Vector2(-7, 11), Vector2(18, 24), fur.lightened(0.13))
	ellipse(c, Vector2(12, -3), Vector2(11, 25), fur.darkened(0.08))
	for side in [-1, 1]:
		var ear_pos := Vector2(18.0 * side, -29.0 + sin(t * 5.2 + side) * 1.1)
		c.draw_circle(ear_pos, 9.4, dark)
		c.draw_circle(ear_pos, 6.0, warm)
	# Fluffy head, face and readable muzzle.
	ellipse(c, Vector2(0, -23), Vector2(26, 23), dark)
	ellipse(c, Vector2(0, -23), Vector2(24, 21), fur.lightened(0.06))
	ellipse(c, Vector2(0, -14), Vector2(18, 12), warm)
	for side in [-1, 1]:
		var eye := Vector2(13.0 * side, -27.0)
		if blink > 0.48:
			line(c, eye + Vector2(-3, 0), eye + Vector2(3, 0), dark, 2.2)
		else:
			ellipse(c, eye, Vector2(3.6, 3.9), Color("#352f36"))
			c.draw_circle(eye + Vector2(-0.8, -1.1), 1.25, Color.WHITE)
		ellipse(c, Vector2(17.0 * side, -17), Vector2(4.4, 2.9), Color("#d58979"))
	ellipse(c, Vector2(0, -14), Vector2(7, 4), Color("#70544c"))
	line(c, Vector2(0, -11), Vector2(0, -7), Color("#70544c"), 1.5)
	# Tiny smile, plus asymmetrical fur texture.
	c.draw_arc(Vector2(0, -8), 4.1, 0.2, PI - 0.2, 14, Color("#81574c"), 1.2, true)
	line(c, Vector2(-17, 5), Vector2(-14, 11), Color("#d7a885"), 1.1)
	line(c, Vector2(-13, 4), Vector2(-10, 9), Color("#d7a885"), 1.1)
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

static func _aim_guide(c: CanvasItem, from: Vector2, target: Vector2, t: float, valid: bool) -> void:
	var ink := Color("#dcfbc3") if valid else Color("#ffb5a3")
	var accent := Color("#5f895f") if valid else Color("#ac5c63")
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
		rr(c, Rect2(target.x - 67, target.y - 70, 134, 28), 11, CREAM, accent, 1.5)
		text(c, "SAFE LANDING", target + Vector2(0, -56), 14, accent)
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

static func _start_overlay(c: CanvasItem, time: float, leaves: int, skin: int, daily: RefCounted, monetization: Node, chapters: RefCounted) -> void:
	rr(c, Rect2(62, 128, 416, 179), 34, Color("#fbedd6"), Color("#ae977d"), 3)
	text(c, "JUMPY FROG", Vector2(270, 186), 49, Color("#5b5868"), true)
	text(c, "A RIVER ADVENTURE", Vector2(270, 244), 19, Color("#a17f74"))
	rr(c, Rect2(169, 321, 202, 44), 18, CREAM, Color("#a28f72"), 1.5)
	text(c, "LEAVES  %d" % leaves, Vector2(270, 341), 21, Color("#5c815c"))
	if monetization.premium:
		text(c, "AD-FREE FOREVER", Vector2(270, 416), 20, Color("#5a9462"))
	elif monetization.purchase_ready:
		rr(c, Rect2(139, 403, 262, 58), 23, Color("#f3dfba"), Color("#a88e68"), 2)
		var label: String = "REMOVE ADS " + (monetization.price_label if not monetization.price_label.is_empty() else "• PLAY STORE")
		text(c, label, Vector2(270, 429), 18, Color("#755d4f"))
	rr(c, Rect2(139, 549, 262, 67), 23, Color("#f2d79d"), Color("#92734d"), 2.1)
	text(c, "CHAPTERS  %d / 6" % chapters.completed_count(), Vector2(270, 579), 23, Color("#60533f"))
	rr(c, Rect2(62, 470, 197, 62), 22, Color("#8fbc94"), Color("#658b75"), 2)
	text(c, "ENDLESS", Vector2(160, 499), 22, Color("#f7f6df"), true)
	rr(c, Rect2(281, 470, 197, 62), 22, Color("#aabedc"), Color("#717e9b"), 2)
	text(c, "DAILY RIVER", Vector2(379, 494), 19, Color("#fff5db"), true)
	var today_status := "DONE" if daily.river_complete_today() else "+25 LEAVES"
	text(c, today_status, Vector2(379, 517), 13, Color("#506277"))
	rr(c, Rect2(139, 634, 262, 58), 23, Color("#c6e2ba"), Color("#748b6b"), 2.2)
	text(c, "DAILY GOALS  %d/3" % daily.completion_count(), Vector2(270, 660), 21, Color("#4b654b"))
	rr(c, Rect2(139, 710, 262, 58), 23, Color("#a8d2aa"), Color("#668569"), 2.2)
	text(c, "CUSTOMIZE", Vector2(270, 736), 24, Color("#3c5543"))
	rr(c, Rect2(64, 783, 412, 112), 29, Color("#fcf0d9"), Color("#907b69"), 2.0)
	text(c, "PULL BACK · RELEASE", Vector2(270, 816), 24, INK)
	text(c, "Hop from lily to lily!", Vector2(270, 863), 19, Color("#947b6b"))
	c.draw_circle(Vector2(270 + sin(time * 3) * 16, 907), 5, Color("#fff6d0"))

static func _lost_overlay(c: CanvasItem, score: int, best: int, run_leaves: int, monetization: Node, rewarded_this_run: bool) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color(0.16, 0.21, 0.32, 0.55))
	rr(c, Rect2(49, 285, 442, 446), 32, Color("#fff0d9"), Color("#8a716a"), 4)
	text(c, "SPLASH!", Vector2(270, 354), 56, Color("#5c668a"))
	text(c, "Your score", Vector2(270, 432), 22, Color("#917769"))
	text(c, _commas(score), Vector2(270, 478), 43, INK)
	text(c, "Best: %s   •   Leaves +%d" % [_commas(best), run_leaves], Vector2(270, 538), 19, Color("#8c756c"))
	rr(c, Rect2(70, 565, 213, 59), 23, Color("#a5ce7c"), Color("#5b7a59"), 2)
	text(c, "RETRY", Vector2(175, 593), 24, Color("#435443"))
	rr(c, Rect2(294, 565, 178, 59), 23, Color("#eee0c2"), Color("#92836d"), 2)
	text(c, "HOME", Vector2(382, 593), 24, INK)
	if not rewarded_this_run and monetization.can_watch_rewarded():
		rr(c, Rect2(80, 651, 390, 62), 23, Color("#d9e6ad"), Color("#7f9a64"), 2)
		text(c, "WATCH AD  •  +5 LEAVES", Vector2(275, 680), 21, Color("#56634c"))
	elif rewarded_this_run:
		text(c, "BONUS CLAIMED", Vector2(270, 683), 21, Color("#548463"))

static func _pause_overlay(c: CanvasItem, muted: bool, monetization: Node, haptics_enabled: bool, android_tones_enabled: bool) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color(0.15, 0.22, 0.29, 0.60))
	rr(c, Rect2(55, 295, 430, 565 if (monetization.billing != null or monetization.ads != null) else 360), 32, Color("#fff0d9"), Color("#887b72"), 3)
	text(c, "PAUSED", Vector2(270, 360), 48, Color("#5a6474"), true)
	text(c, "The river can wait.", Vector2(270, 418), 21, Color("#897871"))
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
	text(c, "TODAY'S MISSIONS", Vector2(270, 294), 32, Color("#595669"), true)
	text(c, "STREAK  %d DAY(S)" % daily.streak_days, Vector2(270, 337), 20, Color("#6a835a"))
	for i in range(3):
		var goal: Dictionary = daily.goal_at(i)
		var y := 382.0 + float(i) * 124.0
		var progress: int = daily.progress(i)
		var target: int = int(goal["target"])
		var completed: bool = (daily.goals_claimed & (1 << i)) != 0
		rr(c, Rect2(66, y, 408, 99), 19, Color("#f5f1dc") if completed else Color("#fae4d0"), Color("#a7a090"), 1)
		text(c, String(goal["title"]), Vector2(270, y + 23), 20, INK)
		text(c, "%d / %d     •     +%d LEAVES" % [mini(progress, target), target, int(goal["reward"])], Vector2(270, y + 51), 17, Color("#548263"))
		rr(c, Rect2(111, y + 76, 318, 8), 4, Color("#dbcbb2"))
		var ratio: float = minf(1.0, float(progress) / float(target))
		if ratio > 0.001:
			rr(c, Rect2(111, y + 76, 318.0 * ratio, 8), 4, Color("#89b874"))
	var milestone: Dictionary = daily.next_milestone()
	var milestone_caption := "ALL MILESTONES COMPLETED" if milestone.is_empty() else ("NEXT: %s" % String(milestone["title"]))
	var milestone_progress := "" if milestone.is_empty() else ("%d / %d   +%d LEAVES" % [mini(int(milestone["progress"]), int(milestone["target"])), int(milestone["target"]), int(milestone["reward"])])
	text(c, "LIFETIME MILESTONES  %d / %d" % [daily.milestone_count(), daily.milestone_total()], Vector2(270, 748), 16, Color("#6a815e"))
	text(c, milestone_caption, Vector2(270, 772), 15, INK)
	if not milestone_progress.is_empty():
		text(c, milestone_progress, Vector2(270, 792), 14, Color("#548263"))
	rr(c, Rect2(100, 815, 340, 67), 23, Color("#accd85"), Color("#5e7e59"), 2)
	text(c, "BACK", Vector2(270, 848), 24, Color("#3f5847"))

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
