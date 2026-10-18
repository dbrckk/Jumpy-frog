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

static func scene(c: CanvasItem, time: float, cam: float, pads: Array, player_at: Vector2, jump_z: float, pets: int, wave_m: float, aiming: bool, aim_at: Vector2, aim_valid: bool, mode: int, score: int, best: int, combo: int, particles: Array, distance: int, muted: bool, tilt: float, squash: float, sway: float, blink: float, impact: float, pad_impacts: Dictionary, celebration: float) -> void:
	_river(c, time, cam)
	for pad in pads:
		var screen := Vector2(float(pad["x"]), ANCHOR - (float(pad["m"]) - cam) * SCALE)
		if screen.y < -125.0 or screen.y > H + 125.0:
			continue
		_lily(c, screen, float(pad["r"]), int(pad["kind"]), time, int(pad["id"]), float(pad_impacts.get(int(pad["id"]), 0.0)))
		if bool(pad["coin"]):
			_coin(c, screen + Vector2(11, -25 + sin(time * 3.0 + float(pad["id"])) * 3), time)
		if bool(pad["pet"]):
			_friend(c, screen + Vector2(0, -18), int(pad["id"]) % 4, 0.82, time)
	_wave(c, ANCHOR - (wave_m - cam) * SCALE, time)
	if aiming:
		_aim_guide(c, player_at, aim_at, time, aim_valid)
	_character(c, player_at, jump_z, pets, time, mode == 3, tilt, squash, sway, blink, impact, celebration)
	for particle in particles:
		var p: Vector2 = particle["pos"]
		var life: float = particle["life"]
		c.draw_circle(p, 2.0 + 5.0 * life, Color(1, 0.94, 0.65, life))
	_hud(c, score, best, pets, distance, wave_m, cam, combo, mode)
	if mode == 0:
		_start_overlay(c, time)
	if mode == 4:
		_lost_overlay(c, score, best)
	if mode == 5:
		_pause_overlay(c, muted)

static func _river(c: CanvasItem, t: float, cam: float) -> void:
	# Slate-blue flowing water, pale shoreline and watercolor vegetation.
	c.draw_rect(Rect2(0, 0, W, H), Color("#a0b796"))
	var water := PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(58):
		var y := -34.0 + float(i) * 18.6
		var offset := y + cam * SCALE
		var wiggle := sin(offset * 0.007) * 9.0 + sin(offset * 0.021 + 1.3) * 4.0
		left.append(Vector2(45.0 + wiggle, y))
		right.append(Vector2(494.0 + wiggle * 0.83, y))
	# Sandy outline adds separation against the banks.
	for i in range(left.size() - 1):
		line(c, left[i] + Vector2(-9, 0), left[i + 1] + Vector2(-9, 0), Color("#e9dfbd"), 18)
		line(c, right[i] + Vector2(9, 0), right[i + 1] + Vector2(9, 0), Color("#e9dfbd"), 18)
	water.append_array(left)
	for i in range(right.size() - 1, -1, -1):
		water.append(right[i])
	c.draw_colored_polygon(water, Color("#7d9bb7"))
	# Broad drifting translucent current. Polygon edges never self-intersect.
	for band in range(7):
		var y := fposmod(float(band) * 193.0 + cam * SCALE * 0.62 + t * 13.0, 1350.0) - 190.0
		var band_poly := PackedVector2Array()
		for i in range(21):
			var x := float(i) * 27.0
			band_poly.append(Vector2(x, y + sin(x * 0.014 + band) * 12.0))
		for i in range(20, -1, -1):
			var x := float(i) * 27.0
			band_poly.append(Vector2(x, y + 40 + sin(x * 0.014 + band) * 12.0))
		c.draw_colored_polygon(band_poly, Color(0.20, 0.35, 0.51, 0.10))
	for i in range(left.size() - 1):
		line(c, left[i], left[i + 1], Color("#779d95"), 3.5)
		line(c, right[i], right[i + 1], Color("#799e97"), 3.5)
	# Water speed lines tilt back with a hand-animated flow.
	for i in range(69):
		var x := 65.0 + float((i * 113 + 29) % 410)
		var y := fposmod(float(i) * 81.7 + cam * SCALE * 0.65 + t * 29.0, 1210.0) - 155.0
		var n := 10.0 + float(i % 5) * 7.0
		line(c, Vector2(x, y), Vector2(x + 6, y + n), Color(0.98, 1.0, 1.0, 0.36), 1.4 + float(i % 2) * 0.25)
	# Pebbles, reeds, small blossoms and flattened grasses.
	for i in range(42):
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
			line(c, origin, tip, Color("#5e856a"), 2.0)
			if (i + stalk) % 4 == 0:
				ellipse(c, tip, Vector2(3.2, 8.0), Color("#9d676d"))
			else:
				ellipse(c, tip + Vector2(0, -3), Vector2(2.2, 5.0), Color("#739961"))
	# Floating rings, bubbles and firefly-like glints.
	for i in range(38):
		var y := fposmod(float(i) * 73.0 + cam * SCALE * 0.83 + t * 5.0, 1160.0) - 100.0
		var x := 87.0 + float((i * 137 + 41) % 365)
		var alpha := 0.20 + float(i % 4) * 0.055
		c.draw_arc(Vector2(x, y), float(8 + i % 8), 0.35, 2.65, 16, Color(0.97, 1, 1, alpha), 1.5, true)
		c.draw_arc(Vector2(x + 7, y + 5), float(6 + i % 6), 3.35, 5.75, 15, Color(0.97, 1, 1, alpha), 1.3, true)
		if i % 3 == 0:
			var pulse := 1.5 + sin(t * 3 + float(i)) * 0.55
			c.draw_circle(Vector2(x - 20, y - 25), pulse, Color("#fff3b8"))
			c.draw_circle(Vector2(x - 20, y - 25), 4.5, Color(1, 0.96, 0.73, 0.09))


static func _lily(c: CanvasItem, pos: Vector2, radius: float, kind: int, t: float, ident: int, impact: float = 0.0) -> void:
	var r := radius * (1.0 + sin(t * 1.5 + float(ident)) * 0.012)
	var wiggle := sin(t * 2.1 + float(ident) * 1.7) * 0.035 + sin((1.0 - impact) * 17.0) * impact * 0.075
	c.draw_set_transform(pos + Vector2(0, impact * 7.0), wiggle, Vector2(1.0 + impact * 0.10, 1.0 - impact * 0.13))
	var center := Vector2.ZERO
	ellipse(c, center + Vector2(3, 10), Vector2(r + 4, r * 0.69), Color(0.24, 0.48, 0.49, 0.33))
	c.draw_arc(center + Vector2(0, 3), r + 12.0, 0.1, PI - 0.1, 32, Color(1, 1, 1, 0.24), 1.8, true)
	var pts := PackedVector2Array([center + Vector2(2, -2)])
	var start := 0.38 + float(ident % 5) * 0.2
	for i in range(52):
		var a := start + 0.55 + (TAU - 1.1) * float(i) / 51.0
		pts.append(center + Vector2(cos(a) * r, sin(a) * r * 0.78))
	var dark := Color("#547c57") if kind != 2 else Color("#9d8550")
	c.draw_colored_polygon(pts, dark)
	var inner := PackedVector2Array([center])
	for i in range(52):
		var a := start + 0.55 + (TAU - 1.1) * float(i) / 51.0
		inner.append(center + Vector2(cos(a) * (r - 4), sin(a) * (r - 4) * 0.78))
	var fill: Color = PALETTE[kind % PALETTE.size()]
	c.draw_colored_polygon(inner, fill)
	# Leaf veins and subtle watercolor highlights.
	for i in range(5):
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

static func _friend(c: CanvasItem, at: Vector2, kind: int, scale: float = 1.0, time: float = 0.0) -> void:
	# Four readable species; silhouettes remain distinct even when stacked.
	var species := posmod(kind, 4)
	var colors := [Color("#73acd0"), Color("#e6aa70"), Color("#aa90c8"), Color("#97be76")]
	var bellies := [Color("#d5ecf0"), Color("#ffe2c0"), Color("#f0d9eb"), Color("#e7ecb5")]
	var main: Color = colors[species]
	var belly: Color = bellies[species]
	var ink := Color("#504b58")
	var blink := fposmod(time * (0.83 + species * 0.07) + kind * 1.93, 4.7) < 0.12
	var bob := sin(time * (3.0 + species * 0.23) + kind * 1.4) * 0.9
	c.draw_set_transform(at + Vector2(0, bob), sin(time * 2.4 + kind) * 0.045, Vector2(scale, scale))
	# Species 0: blue bird with feather crest and side wings.
	if species == 0:
		ellipse(c, Vector2(-11, 4), Vector2(7, 9), ink)
		ellipse(c, Vector2(-11, 3), Vector2(6, 8), main.darkened(0.16))
		ellipse(c, Vector2(10, 4), Vector2(7, 9), ink)
		ellipse(c, Vector2(10, 3), Vector2(6, 8), main.darkened(0.16))
		for i in range(3):
			ellipse(c, Vector2(-3 + i * 4, -15 - (1 if i == 1 else 0)), Vector2(2.8, 6), main.lightened(0.12))
	# Species 1: fox ears and a golden tail.
	elif species == 1:
		ellipse(c, Vector2(10, 8), Vector2(7, 11), ink)
		ellipse(c, Vector2(11, 7), Vector2(5, 9), main)
		for side in [-1, 1]:
			var ear := PackedVector2Array([Vector2(side * 4, -6), Vector2(side * 12, -21), Vector2(side * 12, -3)])
			c.draw_colored_polygon(ear, ink)
			var inside := PackedVector2Array([Vector2(side * 5, -7), Vector2(side * 11, -18), Vector2(side * 10, -5)])
			c.draw_colored_polygon(inside, Color("#edc3a0"))
	# Species 2: floppy bunny ears.
	elif species == 2:
		for side in [-1, 1]:
			ellipse(c, Vector2(side * 7, -18), Vector2(4.4, 13), ink)
			ellipse(c, Vector2(side * 7, -18), Vector2(3, 11), main)
			ellipse(c, Vector2(side * 7, -18), Vector2(1.5, 8), Color("#ebbbd3"))
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


static func _character(c: CanvasItem, at: Vector2, height: float, pets: int, t: float, airborne: bool, tilt: float, squash: float, sway: float, blink: float, impact: float, celebration: float) -> void:
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
	var dark := Color("#604a43")
	var fur := Color("#b48161")
	var warm := Color("#d6a680")
	# Behind-the-body paws, tail and ears.
	ellipse(c, Vector2(21, 24), Vector2(12, 7), dark)
	ellipse(c, Vector2(-22, 23), Vector2(12, 7), dark)
	ellipse(c, Vector2(23, 11), Vector2(10, 13), Color("#916a53"))
	ellipse(c, Vector2(-23, 10), Vector2(10, 13), Color("#916a53"))
	ellipse(c, Vector2(27, 18), Vector2(7, 6), warm)
	ellipse(c, Vector2(0, 3), Vector2(30, 41), dark)
	ellipse(c, Vector2(0, 1), Vector2(28, 39), fur)
	ellipse(c, Vector2(-7, 11), Vector2(18, 24), Color("#c69670"))
	ellipse(c, Vector2(12, -3), Vector2(11, 25), Color("#c08c68"))
	for side in [-1, 1]:
		var ear_pos := Vector2(18.0 * side, -29.0 + sin(t * 5.2 + side) * 1.1)
		c.draw_circle(ear_pos, 9.4, dark)
		c.draw_circle(ear_pos, 6.0, Color("#ce9a7b"))
	# Fluffy head, face and readable muzzle.
	ellipse(c, Vector2(0, -23), Vector2(26, 23), dark)
	ellipse(c, Vector2(0, -23), Vector2(24, 21), Color("#bf906e"))
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
		_friend(c, passenger, i, 0.84 + celebration * 0.07, t)
	if pets > 0:
		c.draw_circle(stack_top + Vector2(-14, -pets * 17), 2.5, Color("#fff4ad"))

static func _wave(c: CanvasItem, wave_y: float, t: float) -> void:
	if wave_y > H + 70:
		return
	var pts := PackedVector2Array()
	for i in range(45):
		var x := float(i) * W / 44.0
		var y := wave_y + sin(x * 0.026 + t * 2.3) * 9.0 + sin(x * 0.074 - t) * 3.5
		pts.append(Vector2(x, y))
	pts.append(Vector2(W, H + 1000))
	pts.append(Vector2(0, H + 1000))
	c.draw_colored_polygon(pts, Color("#242c55"))
	for i in range(33):
		var x := float(i) * W / 32.0
		var y := wave_y + sin(x * 0.026 + t * 2.3) * 9.0 + sin(x * 0.074 - t) * 3.5
		c.draw_circle(Vector2(x, y), 6.4, Color("#fff1dd"))
		if i % 2 == 0:
			c.draw_circle(Vector2(x + 5, y + 6), 3.5, Color("#fff1dd"))
	var bubbles := PackedVector2Array()
	for i in range(36):
		var x := float(i) * 16
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

static func _hud(c: CanvasItem, score: int, best: int, pets: int, distance: int, wave_m: float, cam: float, combo: int, mode: int) -> void:
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
	if mode in [1, 2, 3] and wave_m > cam - 32:
		rr(c, Rect2(180, 67, 180, 31), 14, Color("#fff0d9"), Color("#c57e6e"), 1.5)
		text(c, "WAVE APPROACHING!", Vector2(270, 83), 13, Color("#a15c53"))
	elif combo >= 3 and mode in [1, 2, 3]:
		text(c, "COMBO x%d!" % combo, Vector2(270, 84), 19, Color("#f7f1b2"), true)

static func _start_overlay(c: CanvasItem, time: float) -> void:
	rr(c, Rect2(62, 128, 416, 179), 34, Color("#fbedd6"), Color("#ae977d"), 3)
	text(c, "JUMPY FROG", Vector2(270, 186), 49, Color("#5b5868"), true)
	text(c, "A RIVER ADVENTURE", Vector2(270, 244), 19, Color("#a17f74"))
	rr(c, Rect2(64, 783, 412, 112), 29, Color("#fcf0d9"), Color("#907b69"), 2.0)
	text(c, "PULL BACK · RELEASE", Vector2(270, 816), 24, INK)
	text(c, "Hop from lily to lily!", Vector2(270, 863), 19, Color("#947b6b"))
	c.draw_circle(Vector2(270 + sin(time * 3) * 16, 907), 5, Color("#fff6d0"))

static func _lost_overlay(c: CanvasItem, score: int, best: int) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color(0.16, 0.21, 0.32, 0.55))
	rr(c, Rect2(49, 285, 442, 365), 32, Color("#fff0d9"), Color("#8a716a"), 4)
	text(c, "SPLASH!", Vector2(270, 354), 56, Color("#5c668a"))
	text(c, "Your score", Vector2(270, 432), 22, Color("#917769"))
	text(c, _commas(score), Vector2(270, 478), 43, INK)
	text(c, "Best: %s" % _commas(best), Vector2(270, 538), 20, Color("#8c756c"))
	rr(c, Rect2(111, 565, 318, 59), 27, Color("#a5ce7c"), Color("#5b7a59"), 2)
	text(c, "TAP TO RETRY", Vector2(270, 593), 24, Color("#435443"))

static func _pause_overlay(c: CanvasItem, muted: bool) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color(0.15, 0.22, 0.29, 0.60))
	rr(c, Rect2(55, 295, 430, 360), 32, Color("#fff0d9"), Color("#887b72"), 3)
	text(c, "PAUSED", Vector2(270, 360), 48, Color("#5a6474"), true)
	text(c, "The river can wait.", Vector2(270, 418), 21, Color("#897871"))
	rr(c, Rect2(108, 460, 324, 66), 27, Color("#b3d185"), Color("#5e7e60"), 2)
	text(c, "RESUME", Vector2(270, 494), 26, Color("#49564b"))
	rr(c, Rect2(108, 544, 324, 66), 27, Color("#eee0c2"), Color("#92836d"), 2)
	text(c, "SOUND: OFF" if muted else "SOUND: ON", Vector2(270, 577), 23, INK)

static func _commas(value: int) -> String:
	var s := str(value)
	var result := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			result += ","
		result += s[i]
	return result
