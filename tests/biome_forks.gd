extends SceneTree
## Six optional campaign branches: original route, real physics and return safety.
const FORKS = preload("res://scripts/biome_forks.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + detail)

func _hop(game: Node2D, pad: Dictionary) -> void:
	game.aim_x = game._predicted_pad_x(pad)
	game.aim_m = float(pad["m"])
	game._start_jump()
	_check(game.jump_pad_id == int(pad["id"]), "real jump targets selected fork or normal lily")
	for i in range(70):
		game._process(0.02)
		if game.mode != game.MODE_FLY:
			break
	_check(game.mode in [game.MODE_PLAY, game.MODE_CLEAR], "fork jump lands safely")

func _run() -> void:
	_check(FORKS.START_ID == 4 and FORKS.PERIOD == 5, "detours begin after introductory hops")
	_check(not FORKS.eligible(-1, 4, {}), "Endless keeps its own existing routes")
	_check(not FORKS.eligible(0, 3, {}), "first three hops have no detours")
	_check(FORKS.eligible(0, 4, {}), "fourth hop can have an optional choice")
	_check(not FORKS.eligible(0, 4, {"fragile": true}), "fragile mandatory lily is never paired with a route")
	var tiny_a := {"x": 270.0, "m": 0.0, "moving": false}
	var tiny_b := {"x": 360.0, "m": 21.0, "moving": false}
	_check(FORKS.reachable(tiny_a, tiny_b), "reachable optional gesture is accepted")
	_check(not FORKS.reachable(tiny_a, {"x": 440.0, "m": 30.0}), "too-long gesture gets rejected")
	_check(not FORKS.reachable(tiny_b, tiny_a), "backward jumps are never eligible")
	var unique_labels := {}
	for biome in range(6):
		var sample := {"biome_fork": true, "fork_biome": biome}
		var reward: Dictionary = FORKS.claim(sample)
		_check(not reward.is_empty() and int(reward["score"]) > 0 and not reward.has("leaves"),
			"biome reward is positive, non-currency and well formed")
		unique_labels[String(reward["label"])] = true
		_check(not bool(sample["biome_fork"]) and FORKS.claim(sample).is_empty(),
			"fork reward cannot be farmed twice")
	_check(unique_labels.size() == 6, "all six paths award recognizably different effects")
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.chapters.unlocked_count = 6
	for biome in range(6):
		game._start_chapter(biome)
		var originals: Array = []
		for pad in game.pads:
			if int(pad["id"]) < FORKS.FORK_ID_OFFSET:
				originals.append([pad["id"], pad["x"], pad["m"], pad["r"]])
		var seen := 0
		for i in range(game.pads.size()):
			var pad: Dictionary = game.pads[i]
			if not bool(pad.get("biome_fork", false)):
				continue
			seen += 1
			var id: int = int(pad["id"]) - FORKS.FORK_ID_OFFSET
			_check(id >= 4 and (id - 4) % 5 == 0, "forks keep sparse, deterministic IDs")
			_check(int(pad["fork_biome"]) == biome, "fork identity matches the scenery")
			_check(not bool(pad.get("coin", false)) and not bool(pad.get("pet", false)),
				"side path never grants extra permanent currency or a friend")
			var previous: Dictionary = {}
			var primary: Dictionary = {}
			var next: Dictionary = {}
			for candidate in game.pads:
				if int(candidate["id"]) == id - 1:
					previous = candidate
				elif int(candidate["id"]) == id:
					primary = candidate
				elif int(candidate["id"]) == id + 1:
					next = candidate
			_check(not previous.is_empty() and not primary.is_empty(),
				"every optional path has an intact mandatory approach and alternate")
			if previous.is_empty() or primary.is_empty():
				continue
			_check(FORKS.reachable(previous, pad), "all forks reachable even at worst motion phase")
			_check(absf(float(pad["x"]) - float(primary["x"])) >= 84.0,
				"fork is clearly distinguishable from mandatory platform")
			if not next.is_empty():
				_check(FORKS.reachable(pad, next), "every visible side route reconnects safely")
			_check(not bool(pad.get("danger", false)), "detour introduces no hidden crab timing")
		_check(seen > 0, "every biome generates a real side path early in the course")
		# Reset-and-compare ensures extra routes do not perturb original RNG.
		game._start_chapter(biome)
		var regenerated: Array = []
		for pad in game.pads:
			if int(pad["id"]) < FORKS.FORK_ID_OFFSET:
				regenerated.append([pad["id"], pad["x"], pad["m"], pad["r"]])
		_check(originals == regenerated, "replaying a chapter keeps all main lily positions")
	# A genuine optional route at hop four, followed by a return to the main path.
	game._start_chapter(0)
	for id in range(1, 4):
		var target: Dictionary = {}
		for pad in game.pads:
			if int(pad["id"]) == id:
				target = pad
				break
		_check(not target.is_empty(), "unmodified introductory pads remain playable")
		if target.is_empty():
			break
		_hop(game, target)
	var fork: Dictionary = {}
	var successor: Dictionary = {}
	for pad in game.pads:
		if int(pad["id"]) == FORKS.FORK_ID_OFFSET + 4:
			fork = pad
		elif int(pad["id"]) == 5:
			successor = pad
	_check(not fork.is_empty() and not successor.is_empty(), "first chapter offers detour with an exit")
	if not fork.is_empty() and not successor.is_empty():
		var leaves_before: int = game.leaves
		var score_before: int = game.score
		_hop(game, fork)
		_check(game.standing_pad_id == int(fork["id"]), "actual collision solver lands on the side route")
		_check(game.leaves == leaves_before, "side route produces no repeatable leaves")
		_check(game.score >= score_before + int(FORKS.SCORES[0]), "detour pays its unique score reward")
		_check(not bool(fork.get("biome_fork", true)), "genuine landing consumes the detour reward")
		_hop(game, successor)
		_check(game.standing_pad_id == int(successor["id"]), "next mandatory lily remains reachable")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: six campaign detours, deterministic originals, guaranteed exits and real rewarded hops")
	else:
		printerr("FAIL: %d optional fork regressions" % failures)
	quit(0 if failures == 0 else 1)
