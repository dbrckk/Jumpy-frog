extends SceneTree
const CHALLENGES = preload("res://scripts/precision_sprint.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var d := CHALLENGES.new()
	var rewards := 0
	for cycle in range(4):
		var start := CHALLENGES.FIRST_HOP + cycle * CHALLENGES.INTERVAL
		for hop in range(d.last_processed_hop + 1, start):
			d.on_landing(hop, false)
		for offset in range(6):
			var event := {}
			match cycle:
				0: event = d.on_landing(start + offset, true)
				1: event = d.on_landing(start + offset, false, true)
				2: event = d.on_landing(start + offset, false, false, 19.0)
				3: event = d.on_landing(start + offset, false, false, 0.0, true)
			if bool(event.get("won", false)):
				rewards += 1
				_check(int(event["win_streak"]) == rewards, "streak only increments on real wins")
				_check(int(event["streak_bonus"]) == (1 if rewards == 3 else 0), "only third consecutive win adds one leaf")
				_check(int(event["leaves"]) == 2 + (1 if rewards == 3 else 0), "correct payout")
	_check(d.win_streak == 4 and d.best_win_streak == 4, "four wins produce four streak")
	_check(d.completions == 4, "exactly four payouts")
	var start := CHALLENGES.FIRST_HOP + 4 * CHALLENGES.INTERVAL
	for hop in range(d.last_processed_hop + 1, start):
		d.on_landing(hop, false)
	for hop in range(start, start + CHALLENGES.LENGTH):
		d.on_landing(hop, false)
	_check(d.win_streak == 0 and d.best_win_streak == 4, "failed challenge resets current streak, not best")
	_check(d.on_landing(start + 5, true).is_empty(), "replaying last failed hop cannot create reward")
	d.reset()
	_check(d.win_streak == 0 and d.best_win_streak == 0, "new run resets temporary streak")
	if failures == 0:
		print("PASS: authentic consecutive challenge streaks, every-third reward, no double payouts and failure reset")
	quit(0 if failures == 0 else 1)

func _check(ok: bool, reason: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + reason)
