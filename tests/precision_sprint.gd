extends SceneTree
const SPRINT = preload("res://scripts/precision_sprint.gd")
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sprint := SPRINT.new()
	for hop in range(1, SPRINT.FIRST_HOP):
		_check(sprint.on_landing(hop, true).is_empty(), "no early sprint")
	_check(sprint.on_landing(18, true).get("progress", -1) == 1, "starts on hop 18")
	_check(sprint.on_landing(19, false).get("progress", -1) == 1, "ordinary landings preserve progress")
	_check(sprint.on_landing(20, true).get("progress", -1) == 2, "second perfect advances")
	var won: Dictionary = sprint.on_landing(21, true)
	_check(bool(won.get("won", false)), "three perfects win")
	_check(int(won.get("leaves", 0)) == 2 and int(won.get("score", 0)) == 180, "correct reward")
	_check(sprint.completions == 1 and not sprint.active, "pays once")
	for hop in range(22, 52):
		_check(sprint.on_landing(hop, true).is_empty(), "no accidental repeated rewards")
	for hop in range(52, 58):
		var result: Dictionary = sprint.on_landing(hop, false)
		if hop == 57:
			_check(not bool(result.get("won", true)) and not sprint.active, "missed challenge ends without penalty")
	_check(sprint.completions == 1, "missed challenge never pays")
	sprint.reset()
	_check(sprint.completions == 0 and sprint.attempts == 0, "new run resets optional event")
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._reset_game()
	_check(not game.precision_sprint.active, "game resets skill trial")
	for chapter in range(6):
		game._start_chapter(chapter)
		_check(not game.precision_sprint.active, "chapter never starts Endless sprint")
	game._start_daily_river()
	_check(not game.precision_sprint.active, "daily mode unchanged")
	game.queue_free()
	await process_frame
	if failed == 0:
		print("PASS: deterministic precision sprints, fair win/loss, once-only reward, reset and campaign/daily isolation")
	quit(0 if failed == 0 else 1)
func _check(ok: bool, why: String) -> void:
	if not ok:
		failed += 1
		push_error("FAIL: " + why)
