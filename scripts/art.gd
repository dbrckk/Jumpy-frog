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

static func scene(c: CanvasItem, time: float, cam: float, pads: Array, player_at: Vector2, jump_z: float, pets: int, wave_m: float, aiming: bool, aim_at: Vector2, mode: int, score: int, best: int, combo: int, particles: Array, distance: int) -> void:
	_river(c, time, cam)
	for pad in pads:
		var screen := Vector2(float(pad["x"]), ANCHOR - (float(pad["m"]) - cam) * SCALE)
		if screen.y < -125.0 or screen.y > H + 125.0:
			continue
		_lily(c, screen, float(pad["r"]), int(pad["kind"]), time, int(pad["id"]))
		if bool(pad["coin"]):
			_coin(c, screen + Vector2(11, -25 + sin(time * 3.0 + float(pad["id"])) * 3), time)
		if bool(pad["pet"]):
			_friend(c, screen + Vector2(0, -18), 0, 0.82)
	_wave(c, ANCHOR - (wave_m - cam) * SCALE, time)
	if aiming:
		_aim_guide(c, player_at, aim_at, time)
	_character(c, player_at, jump_z, pets, time, mode == 3)
	for particle in particles:
		var p: Vector2 = particle["pos"]
		var life: float = particle["life"]
		c.draw_circle(p, 2.0 + 5.0 * life, Color(1, 0.94, 0.65, life))
	_hud(c, score, best, pets, distance, wave_m, cam, combo, mode)
	if mode == 0:
		_start_overlay(c, time)
	if mode == 4:
		_lost_overlay(c, score, best)

static func _river(c: CanvasItem, t: float, cam: float) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color("#e8d9b4"))
	# River, hand-drawn irregular banks.
	var water := PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(42):
		var y := -30.0 + float(i) * 25.0
		var offset := y + cam * SCALE
		var wiggle := sin(offset * 0.007) * 8.0 + sin(offset * 0.024 + 1.2) * 3.5
		left.append(Vector2(49.0 + wiggle, y))
		right.append(Vector2(493.0 + wiggle * 0.8, y))
	for p in left:
		water.append(p)
	for i in range(right.size() - 1, -1, -1):
		water.append(right[i])
	c.draw_colored_polygon(water, Color("#96d4ce"))
	# Transparent moving watercolor bands.
	for i in range(13):
		var y := fposmod(float(i) * 116.0 + cam * SCALE * 0.63, 1180.0) - 130.0
		rr(c, Rect2(49, y, 443, 53), 22, Color(0.34, 0.56, 0.66, 0.085))
	for i in range(left.size() - 1):
		line(c, left[i], left[i + 1], Color("#669e8f"), 5)
		line(c, right[i], right[i + 1], Color("#65998b"), 5)
		line(c, left[i] + Vector2(-8, 0), left[i + 1] + Vector2(-8, 0), Color("#f3eccb"), 10)
		line(c, right[i] + Vector2(8, 0), right[i + 1] + Vector2(8, 0), Color("#f3eccb"), 10)
	# Grassy banks, small stones, leaves and cattails. Stable as camera scrolls.
	for i in range(27):
		var y := fposmod(float(i) * 91.0 + cam * SCALE, 1150.0) - 70.0
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var edge := 40.0 if side < 0.0 else 499.0
		var x := edge + side * (float((i * 11) % 16))
		ellipse(c, Vector2(x, y + 7), Vector2(9, 6), Color("#b9a17d"))
		ellipse(c, Vector2(x - side * 2.0, y + 4), Vector2(6, 4), Color("#ece0bd"))
		if i % 3 != 0:
			line(c, Vector2(x + side * 16, y + 8), Vector2(x + side * 11, y - 14), Color("#748f55"), 2)
			line(c, Vector2(x + side * 16, y + 8), Vector2(x + side * 21, y - 10), Color("#789a57"), 2)
			ellipse(c, Vector2(x + side * 11, y - 14), Vector2(2.6, 7.0), Color("#a56d68"))
	# Tiny hand-drawn water rings and sparkles.
	for i in range(32):
		var y := fposmod(float(i) * 71.0 + cam * SCALE * (0.85 + float(i % 3) * 0.05), 1060.0) - 50.0
		var x := 84.0 + float((i * 137 + 41) % 370)
		var alpha := 0.17 + float(i % 4) * 0.052
		c.draw_arc(Vector2(x, y), float(8 + i % 7), 0.45, 2.3, 14, Color(0.95, 1, 0.93, alpha), 1.35, true)
		c.draw_arc(Vector2(x + 6, y + 4), float(7 + i % 5), 3.45, 5.35, 12, Color(0.95, 1, 0.93, alpha), 1.3, true)
		if i % 3 == 0:
			c.draw_circle(Vector2(x - 18, y - 27 + sin(t * 2 + i) * 4), 1.7, Color("#fff9df"))

static func _lily(c: CanvasItem, pos: Vector2, radius: float, kind: int, t: float, ident: int) -> void:
	var r := radius * (1.0 + sin(t * 1.5 + float(ident)) * 0.012)
	ellipse(c, pos + Vector2(3, 10), Vector2(r + 4, r * 0.69), Color(0.24, 0.48, 0.49, 0.33))
	c.draw_arc(pos + Vector2(0, 3), r + 12.0, 0.1, PI - 0.1, 32, Color(1, 1, 1, 0.24), 1.8, true)
	var pts := PackedVector2Array([pos + Vector2(2, -2)])
	var start := 0.38 + float(ident % 5) * 0.2
	for i in range(52):
		var a := start + 0.55 + (TAU - 1.1) * float(i) / 51.0
		pts.append(pos + Vector2(cos(a) * r, sin(a) * r * 0.78))
	var dark := Color("#547c57") if kind != 2 else Color("#9d8550")
	c.draw_colored_polygon(pts, dark)
	var inner := PackedVector2Array([pos])
	for i in range(52):
		var a := start + 0.55 + (TAU - 1.1) * float(i) / 51.0
		inner.append(pos + Vector2(cos(a) * (r - 4), sin(a) * (r - 4) * 0.78))
	var fill: Color = PALETTE[kind % PALETTE.size()]
	c.draw_colored_polygon(inner, fill)
	# Leaf veins and subtle watercolor highlights.
	for i in range(5):
		var a := start + 1.35 + (TAU - 2.7) * float(i) / 4.0
		line(c, pos, pos + Vector2(cos(a) * r * 0.7, sin(a) * r * 0.55), fill.darkened(0.16), 1.5)
	ellipse(c, pos + Vector2(-13, -12), Vector2(9, 4), Color(1, 1, 0.85, 0.13))
	if kind == 1:
		_flower(c, pos + Vector2(15, 7), 0.9, t)
	elif kind == 2:
		for i in range(5):
			c.draw_circle(pos + Vector2(float((i * 23) % 41) - 20, float((i * 17) % 29) - 14), 3.3, Color("#a98f58"))
	elif kind == 3:
		_flower(c, pos + Vector2(-9, 8), 0.7, t)

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

static func _friend(c: CanvasItem, at: Vector2, kind: int, scale: float = 1.0) -> void:
	var main: Color
	var secondary: Color
	match kind % 4:
		0:
			main = Color("#6caed0")
			secondary = Color("#c8e8ed")
		1:
			main = Color("#e6a66f")
			secondary = Color("#fce3c0")
		2:
			main = Color("#a78cc0")
			secondary = Color("#efcfeb")
		_:
			main = Color("#96bd6c")
			secondary = Color("#daedaa")
	var r := 10.5 * scale
	ellipse(c, at + Vector2(0, 1.5), Vector2(r, r * 1.25), Color("#554954"))
	ellipse(c, at, Vector2(r - 1.5, r * 1.2 - 1.0), main)
	ellipse(c, at + Vector2(0, 4.5 * scale), Vector2(6, 5) * scale, secondary)
	for side in [-1, 1]:
		c.draw_circle(at + Vector2(6.0 * side, -9.0) * scale, 5.1 * scale, Color("#5a4f56"))
		c.draw_circle(at + Vector2(6.0 * side, -9.0) * scale, 3.7 * scale, main)
		c.draw_circle(at + Vector2(4.0 * side, -2.6) * scale, 1.9 * scale, INK)
	c.draw_circle(at + Vector2(0, 1.5) * scale, 2 * scale, Color("#744b53"))

static func _character(c: CanvasItem, at: Vector2, height: float, pets: int, t: float, airborne: bool) -> void:
	var z := height
	ellipse(c, at + Vector2(3, 13), Vector2(27 + height * 0.11, 12 + height * 0.045), Color(0.20, 0.39, 0.45, 0.25))
	if not airborne:
		for i in range(2):
			var r := 35.0 + float(i) * 10.0 + fposmod(t * 12, 12)
			c.draw_arc(at + Vector2(0, 8), r, 0.15, 3.0, 36, Color(1, 1, 1, 0.23 - i * 0.06), 1.8, true)
	var body := at + Vector2(0, -18 - z + sin(t * 2.8) * 1.3)
	# Flippers, body silhouette, cheek and face are deliberately original.
	for side in [-1, 1]:
		ellipse(c, body + Vector2(23.0 * side, 17), Vector2(10, 6), Color("#6c5047"))
		ellipse(c, body + Vector2(21.0 * side, -13), Vector2(8, 9), Color("#876450"))
	ellipse(c, body + Vector2(0, 3), Vector2(29, 40), Color("#5d4947"))
	ellipse(c, body, Vector2(27, 37), Color("#aa795d"))
	ellipse(c, body + Vector2(-7, 11), Vector2(16, 22), Color("#bc8f69"))
	ellipse(c, body + Vector2(13, -9), Vector2(8, 18), Color("#bf8d6c"))
	for side in [-1, 1]:
		c.draw_circle(body + Vector2(18 * side, -29), 9.5, Color("#624c46"))
		c.draw_circle(body + Vector2(18 * side, -29), 6.0, Color("#c9997c"))
	ellipse(c, body + Vector2(0, -22), Vector2(25, 22), Color("#be8d69"))
	ellipse(c, body + Vector2(0, -15), Vector2(17, 12), Color("#d9ad82"))
	for side in [-1, 1]:
		c.draw_circle(body + Vector2(14 * side, -25), 3.4, Color("#3e3435"))
		c.draw_circle(body + Vector2(13.3 * side, -26), 1.1, Color.WHITE)
		ellipse(c, body + Vector2(17 * side, -15), Vector2(4, 2.8), Color("#d68d7a"))
	ellipse(c, body + Vector2(0, -14), Vector2(7.0, 4.0), Color("#77554b"))
	line(c, body + Vector2(0, -12), body + Vector2(0, -8), Color("#77554b"), 1.3)
	# Up to eight riders, swaying slightly.
	for i in range(mini(pets, 8)):
		var wiggle := sin(t * 3.0 + float(i) * 0.9) * (1.3 + i * 0.25)
		var p := body + Vector2(wiggle, -52 - float(i) * 18.0)
		_friend(c, p, i, 0.80)
	if pets > 0:
		c.draw_circle(body + Vector2(-14, -47 - pets * 18), 3.0, Color("#fff5af"))

static func _wave(c: CanvasItem, wave_y: float, t: float) -> void:
	if wave_y > H + 70:
		return
	var pts := PackedVector2Array()
	for i in range(45):
		var x := float(i) * W / 44.0
		var y := wave_y + sin(x * 0.026 + t * 2.3) * 9.0 + sin(x * 0.074 - t) * 3.5
		pts.append(Vector2(x, y))
	pts.append(Vector2(W, H + 20))
	pts.append(Vector2(0, H + 20))
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
	bubbles.append(Vector2(W, H + 20))
	bubbles.append(Vector2(0, H + 20))
	c.draw_colored_polygon(bubbles, Color(0.32, 0.45, 0.65, 0.27))

static func _aim_guide(c: CanvasItem, from: Vector2, target: Vector2, t: float) -> void:
	var dist := from.distance_to(target)
	var viable := dist > 28.0 and target.y < from.y - 25.0
	var ink := Color("#fff1b6") if viable else Color("#ffaaaa")
	ellipse(c, target + Vector2(0, 4), Vector2(21, 9), Color(1, 1, 1, 0.36))
	c.draw_arc(target, 25, 0.0, TAU, 48, ink, 3, true)
	for i in range(1, 13):
		var portion := float(i) / 13.0
		var point := from.lerp(target, portion) + Vector2(0, -sin(portion * PI) * 65)
		c.draw_circle(point, 4.0 * (1.0 - portion * 0.45), ink)
	if viable:
		text(c, "RELEASE", target + Vector2(0, -44), 15, CREAM, true)

static func _hud(c: CanvasItem, score: int, best: int, pets: int, distance: int, wave_m: float, cam: float, combo: int, mode: int) -> void:
	rr(c, Rect2(14, 17, 101, 35), 17, CREAM, Color("#8c806e"), 1.6)
	text(c, "★  x%d" % pets, Vector2(65, 34), 17, Color("#755b51"))
	rr(c, Rect2(138, 14, 259, 44), 21, CREAM, Color("#8c806e"), 1.7)
	text(c, "%s" % _commas(score), Vector2(267, 35), 25, INK)
	rr(c, Rect2(415, 17, 111, 35), 17, CREAM, Color("#8c806e"), 1.5)
	text(c, "%d m" % distance, Vector2(470, 34), 17, INK)
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

static func _commas(value: int) -> String:
	var s := str(value)
	var result := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			result += ","
		result += s[i]
	return result
