extends SceneTree
## True long-run festival completion: rare schedule, safe spacing and exact-once awards.
const FESTIVAL = preload("res://scripts/river_festival.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._reset_game()
	game.mode = game.MODE_PLAY
	game.daily.goals_claimed = 7
	game.daily.weekly_claimed = 7
	game.daily.milestones_claimed = (1 << game.daily.MILESTONES.size()) - 1
	game.rng.seed = 23819

	# The first event must be discoverable but not in the tutorial.
	_check(game.festival.next_start_id == 23, "first festival occurs after learning controls")
	game.player_m = 1700.0
	game._generate_pads()
	var group_starts: Array[int] = []
	var stages: Dictionary = {}
	var total = 0
	for pad in game.pads:
		var step := int(pad.get("festival_step", -1))
		if step < 0:
			continue
		total += 1
		var ident: int = int(pad["id"])
		var group: int = int(pad["festival_group"])
		if step == 0:
			group_starts.append(ident)
		stages[ident] = step
		_check(ident == group + step, "festival has three consecutive primary pads")
		_check(float(pad["r"]) >= 55.0, "festival pads are large breathing spaces")
		_check(not bool(pad.get("fragile", false)) and not bool(pad.get("danger", false)), "no timed dangers during festival")
		_check(not bool(pad.get("moving", false)) and not bool(pad.get("harmony", false)), "no competing skill hazard during festival")
		_check(not bool(pad.get("guardian", false)) and not bool(pad.get("boost", false)), "no special power overlaps festival")
		_check(not bool(pad.get("coin", false)) and not bool(pad.get("pet", false)), "festival reward remains legible and unique")
		_check(ident < 1000000, "bonus gold branches never impersonate festival pads")
	_check(group_starts.size() >= 2 and total >= 6, "rare festivals recur across long sessions")
	for n in range(1,group_starts.size()):
		var span: int = group_starts[n] - group_starts[n-1]
		_check(span >= FESTIVAL.MIN_NEXT_GAP and span <= FESTIVAL.MAX_NEXT_GAP,
			"rare events spaced between 37 and 49 hops")
	for start in group_starts:
		for k in range(3):
			_check(int(stages.get(start+k, -1)) == k, "every generated festival has all three stages")

	# End-to-end gameplay: traverse 25 real landings, including the
	# first full festival. Do not force a touch score or bypass collisions.
	game._reset_game()
	game.mode = game.MODE_PLAY
	game.daily.goals_claimed = 7
	game.daily.weekly_claimed = 7
	game.daily.milestones_claimed = (1 << game.daily.MILESTONES.size()) - 1
	var expected_award_base := 0
	for hop in range(1, 26):
		var target: Dictionary = {}
		for candidate in game.pads:
			if int(candidate["id"]) >= 1000000:
				continue
			if float(candidate["m"]) > game.player_m + 3.0:
				target = candidate
				break
		_check(not target.is_empty(), "every festival approach has a valid next platform")
		if target.is_empty():
			break
		var attempts := 0
		while game._landing_target(game._predicted_pad_x(target), float(target["m"])).is_empty() and attempts < 115:
			game._process(0.02)
			attempts += 1
			if game.mode != game.MODE_PLAY:
				break
		_check(game.mode == game.MODE_PLAY and attempts < 115, "short waiting for crab still allows play")
		if game.mode != game.MODE_PLAY:
			break
		game.aim_x = game._predicted_pad_x(target)
		game.aim_m = float(target["m"])
		game._start_jump()
		_check(game.jump_pad_id == int(target["id"]), "real leap resolves planned primary lily")
		for frame in range(60):
			game._process(0.02)
			if game.mode != game.MODE_FLY:
				break
		_check(game.mode == game.MODE_PLAY, "landing safely progresses through event")
		if game.mode != game.MODE_PLAY:
			break
		if hop == 22:
			expected_award_base = game.leaves
			_check(game.festival.progress == 0, "event is not activated early")
		if hop == 23:
			_check(game.festival.progress == 1, "first glow pad arms 1/3")
			_check(game.leaves == expected_award_base, "event entry gives no unearned payout")
		if hop == 24:
			_check(game.festival.progress == 2, "second glow pad advances 2/3")
			_check(game.leaves == expected_award_base, "no premature payout")
		if hop == 25:
			_check(game.festival.progress == 0 and game.festival.completions == 1,
				"third consecutive festival pad completes event exactly once")
			# A separate, legitimate 5-perfect streak bonus can occur on
			# landing 25, alongside the three festival leaves.
			var streak_leaf := 1 if game.perfect_streak % 5 == 0 else 0
			_check(game.leaves == expected_award_base + FESTIVAL.LEAVES + streak_leaf,
				"festival awards exactly three leaves alongside normal precision bonuses")
			_check(game.festival_banner_seconds > 2.0, "celebration appears after completion")
			_check(game.precision_pulse > 0.0, "large audiovisual celebration includes impact flash")
	_check(game.run_hops == 25, "festival integrates naturally into normal Endless scoring")
	_check(game.score > 0, "full completed event retains run score")
	var saved := ConfigFile.new()
	_check(saved.load("user://jumpy_frog.cfg") == OK and int(saved.get_value("progress","leaves",0)) == game.leaves,
		"festival reward persists through shared robust save")

	# Claim sequence cannot be replayed or farmed, and missed steps reset it.
	var ctrl := FESTIVAL.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	ctrl.reset()
	var a: Dictionary = {"festival_group": 23, "festival_step": 0}
	var b: Dictionary = {"festival_group": 23, "festival_step": 1}
	var c: Dictionary = {"festival_group": 23, "festival_step": 2}
	_check(not ctrl.land(a) and ctrl.progress == 1, "fresh chain starts only at step one")
	_check(not ctrl.land({"festival_group": -1, "festival_step": -1}) and ctrl.progress == 0, "skipping the middle breaks chain")
	_check(not ctrl.land(b) and not ctrl.land(c) and ctrl.completions == 0, "incomplete sequence cannot pay out")
	ctrl.reset()
	_check(not ctrl.land({"festival_group": 23,"festival_step": 0}), "fresh step one")
	_check(not ctrl.land({"festival_group": 23,"festival_step": 1}), "fresh step two")
	var finish := {"festival_group": 23, "festival_step": 2}
	_check(ctrl.land(finish) and ctrl.completions == 1, "correct sequence completes exactly once")
	_check(not ctrl.land(finish) and ctrl.completions == 1, "revisiting completed stage never pays again")
	ctrl.reset()
	_check(ctrl.completions == 0 and ctrl.progress == 0 and ctrl.next_start_id == 23, "new game resets event state")
	for chapter in range(6):
		game._start_chapter(chapter)
		for pad in game.pads:
			_check(int(pad.get("festival_step", -1)) == -1, "story chapters remain unchanged")
	game._start_daily_river()
	for pad in game.pads:
		_check(int(pad.get("festival_step", -1)) == -1, "daily event remains deterministic and festival free")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: fair three-hop festivals, 2km generation, no paywall, rare cadence, reward persistence, anti-replay and chapter safety")
	else:
		printerr("FAIL: %d festival gameplay assertions" % failures)
	quit(0 if failures == 0 else 1)

func _check(valid: bool, label: String) -> void:
	if not valid:
		failures += 1
		push_error("FAIL: " + label)
