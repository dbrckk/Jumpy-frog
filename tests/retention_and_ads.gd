extends SceneTree
## Strict exit codes for daily missions and monetization policy; no test purchase spoofing.
var errors := 0

func _initialize() -> void:
	call_deferred("_check_all")

func _check_all() -> void:
	var Daily = load("res://scripts/daily.gd")
	var daily = Daily.new()
	_expect(daily.refresh_day(22002), "first UTC day initializes")
	daily.begin_run(22002)
	_expect(daily.streak_days == 1, "streak starts at 1")
	_expect(not daily.refresh_day(22003), "clock rollback cannot replay daily rewards")
	var rewards := 0
	for i in range(8):
		rewards += daily.on_landing(i * 12, i % 2 == 0)
	_expect(rewards == 15, "three missions grant exactly 3+5+7 leaves")
	_expect(daily.goals_claimed == 7, "each goal is claimed once")
	_expect(daily.claim_goals() == 0, "mission rewards cannot be claimed twice")
	_expect(daily.lifetime_hops == 8 and daily.lifetime_leaves == 4, "lifetime statistics tracked")
	daily.on_finish(3450)
	var save := ConfigFile.new()
	daily.write_to(save)
	var restored = Daily.new()
	restored.load_from(save)
	_expect(restored.today_best == 3450 and restored.goals_claimed == 7, "daily progress round trips through ConfigFile")
	_expect(restored.refresh_day(22001), "new UTC day resets daily goals")
	restored.begin_run(22003)
	_expect(restored.streak_days == 2, "next-day streak grows")
	_expect(restored.today_hops == 0 and restored.goals_claimed == 0, "daily progress resets")
	_expect(restored.lifetime_hops == 8, "lifetime progress persists")
	restored.refresh_day(22008)
	restored.begin_run(22008)
	_expect(restored.streak_days == 1, "streak breaks after skipped days")
	var Monet = load("res://scripts/monetization.gd")
	var monet: Node = Monet.new()
	root.add_child(monet)
	await process_frame
	_expect(not monet.purchase_ready and not monet.can_watch_rewarded(), "no fake monetization without native Google SDK")
	_expect(not monet.purchase_remove_ads(), "missing product cannot trigger a payment")
	_expect(not monet.request_rewarded_leaves(), "reward unavailable without watched ad")
	_expect(not monet.request_break_interstitial(), "interstitial unavailable without SDK")
	monet.completed_runs = 100
	monet.runs_since_ad = 100
	monet.elapsed = 10000.0
	_expect(not monet.request_break_interstitial(), "no fallback fake ad even after threshold")
	monet.queue_free()
	await process_frame
	if errors == 0:
		print("PASS: daily goals, UTC rollover, clock rollback, streak, save integrity, and safe unavailable billing/ads")
	quit(0 if errors == 0 else 1)

func _expect(ok: bool, label: String) -> void:
	if not ok:
		errors += 1
		push_error("FAIL: " + label)
