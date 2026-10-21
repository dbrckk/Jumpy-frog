extends SceneTree
## Weekly expeditions: Monday UTC rollover, persistence and finite economy.
const DAILY = preload("res://scripts/daily.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_exercise")

func _exercise() -> void:
	# Unix day 26002 is Monday. Earlier days are strictly older than this
	# synthetic period; tests remain independent of the real device date.
	const MONDAY := 26002
	_check(DAILY.week_for_day(MONDAY - 1) != DAILY.week_for_day(MONDAY), "Monday UTC starts a new week")
	_check(DAILY.week_for_day(MONDAY) == DAILY.week_for_day(MONDAY + 6), "Sunday belongs to current week")
	_check(DAILY.week_for_day(MONDAY) != DAILY.week_for_day(MONDAY + 7), "next Monday begins new expedition")

	var daily = DAILY.new()
	daily.refresh_day(MONDAY)
	daily.begin_run(MONDAY)
	_check(daily.weekly_id == DAILY.week_for_day(MONDAY), "first weekly period set")
	_check(daily.weekly_completion_count() == 0, "new expedition starts unclaimed")
	# Exclude existing daily and career payouts to isolate the weekly economy.
	daily.goals_claimed = 7
	daily.milestones_claimed = (1 << DAILY.MILESTONES.size()) - 1
	var paid := 0
	for i in range(29):
		paid += daily.on_landing(4 * i, false, i < 2, 1, false, i < 7)
	_check(paid == 0, "no early expedition reward")
	_check(daily.weekly_hops == 29 and daily.weekly_perfect == 7 and daily.weekly_friends == 2, "each metric counts independently")
	paid += daily.on_landing(120, false, true, 1, false, true)
	_check(paid == 35, "weekly pays exactly 8+12+15 leaves")
	_check(daily.weekly_claimed == 7 and daily.weekly_completion_count() == 3, "all weekly rewards claimed")
	_check(daily.claim_weekly() == 0, "completed weekly goals cannot be redeemed twice")
	_check(daily.on_landing(121, false, false, 1, false, true) == 0, "extra landings after completion never repay")

	var save := ConfigFile.new()
	daily.write_to(save)
	var loaded = DAILY.new()
	loaded.load_from(save)
	_check(loaded.weekly_id == daily.weekly_id and loaded.weekly_claimed == 7, "weekly claims persist across app restarts")
	_check(loaded.weekly_hops == 31 and loaded.weekly_perfect == 9 and loaded.weekly_friends == 3, "weekly counters survive save/load")
	_check(loaded.claim_weekly() == 0, "reload cannot reissue payout")
	loaded.refresh_day(MONDAY + 6)
	_check(loaded.weekly_claimed == 7 and loaded.weekly_hops == 31, "daily rollover within week preserves expedition")
	_check(not loaded.refresh_day(MONDAY + 2), "backwards clock cannot reset UTC days")
	_check(loaded.weekly_claimed == 7 and loaded.claim_weekly() == 0, "backwards clock cannot replay weekly rewards")

	loaded.refresh_day(MONDAY + 7)
	_check(loaded.weekly_claimed == 0 and loaded.weekly_hops == 0 and loaded.weekly_perfect == 0 and loaded.weekly_friends == 0,
		"next Monday resets weekly stats and rewards")
	_check(loaded.milestones_claimed == daily.milestones_claimed, "weekly reset preserves career awards")
	_check(loaded.weekly_id == DAILY.week_for_day(MONDAY + 7), "new week ID saved")
	loaded.goals_claimed = 7
	_check(loaded.on_landing(2, false, false, 0, false, true) == 0, "new week begins earning goals again")
	_check(loaded.weekly_hops == 1 and loaded.weekly_perfect == 1, "new week starts at one landing")
	_check(not loaded.refresh_day(MONDAY), "older Monday cannot reopen an already played week")

	# A prior release's ConfigFile has no weekly fields. Migration must not
	# change the saved leaves, daily progress, or lifetime milestones.
	var old := ConfigFile.new()
	old.set_value("daily", "day_id", MONDAY)
	old.set_value("daily", "hops", 5)
	old.set_value("daily", "claimed", 3)
	old.set_value("lifetime", "hops", 80)
	old.set_value("lifetime", "milestones_claimed", 5)
	var migrated = DAILY.new()
	migrated.load_from(old)
	_check(migrated.weekly_id == DAILY.week_for_day(MONDAY), "old save migrates to current week")
	_check(migrated.weekly_hops == 0 and migrated.weekly_claimed == 0, "new weekly stats do not inherit already rewarded old activities")
	_check(migrated.today_hops == 5 and migrated.goals_claimed == 3, "legacy daily stats preserved")
	_check(migrated.lifetime_hops == 80 and migrated.milestones_claimed == 5, "legacy career stats preserved")

	# Real game integration; script call and UI remain operational with all
	# three weekly rows shown in the existing missions screen.
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._reset_game()
	game.mode = game.MODE_GOALS
	game._process(0.016)
	game._down(Vector2(270, 856))
	_check(game.mode == game.MODE_TITLE, "weekly missions screen back button matches its hitbox")
	game.queue_free()
	await process_frame

	if failures == 0:
		print("PASS: weekly expedition rewards, calendar, anti-rollback, save migration, mission UI and replay prevention")
	else:
		printerr("FAIL: %d weekly regression checks" % failures)
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
