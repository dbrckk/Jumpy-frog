extends SceneTree
var errors := 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	g.mode = 1
	var pad: Dictionary = g.pads[1]
	pad["guardian"] = true
	g.aim_x = pad["x"]
	g.aim_m = pad["m"]
	g._start_jump()
	for i in range(65):
		g._process(0.02)
		if g.mode != 3: break
	_check(g.guardian_charge, "picked up guardian")
	var x: float = g.player_x
	var m: float = g.player_m
	g.aim_x = 270
	g.aim_m = m + 3000
	g._start_jump()
	for i in range(65):
		g._process(0.02)
		if g.mode != 3: break
	_check(g.mode == 1 and not g.guardian_charge, "one life saved")
	_check(is_equal_approx(g.player_x, x) and is_equal_approx(g.player_m, m), "landed back on safe pad")
	g.aim_x = 270
	g.aim_m = m + 3000
	g._start_jump()
	for i in range(65):
		g._process(0.02)
		if g.mode != 3: break
	_check(g.mode == 4, "second failure ends run")
	_check(g.flight_trail.size() <= 9, "bounded trail")
	g.queue_free()
	await process_frame
	print("PASS: guardian mechanic" if errors == 0 else "FAIL: guardian mechanic")
	quit(1 if errors else 0)
func _check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error(message)
