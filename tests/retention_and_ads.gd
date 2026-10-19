extends SceneTree
## Strict exit codes for daily missions and monetization policy; no test purchase spoofing.
var errors := 0
class TestAdBridge extends Node:
	var shown := 0
	func can_show_interstitial() -> bool:
		return true
	var allow_show := true
	func show_interstitial() -> bool:
		if not allow_show:
			return false
		shown += 1
		return true
	func can_show_rewarded() -> bool:
		return true
	func show_rewarded() -> void:
		pass


func _initialize() -> void:
	call_deferred("_check_all")

func _check_all() -> void:
	var Daily = load("res://scripts/daily.gd")
	var daily = Daily.new()
	_expect(daily.refresh_day(22002), "first UTC day initializes")
	daily.begin_run(22002)
	_expect(daily.streak_days == 1, "streak starts at 1")
	_expect(not daily.refresh_day(22001), "clock rollback cannot replay daily rewards")
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
	_expect(restored.refresh_day(22003), "new UTC day resets daily goals")
	restored.begin_run(22003)
	_expect(restored.streak_days == 2, "next-day streak grows")
	_expect(restored.today_hops == 0 and restored.goals_claimed == 0, "daily progress resets")
	_expect(restored.lifetime_hops == 8, "lifetime progress persists")
	restored.refresh_day(22008)
	restored.begin_run(22008)
	_expect(restored.streak_days == 1, "streak breaks after skipped days")

	# Each of the three rotating daily pools must be independently completable.
	var rescue_day = Daily.new()
	rescue_day.refresh_day(22000) # day_id % 3 == 1
	var rescue_rewards := 0
	for n in range(10):
		rescue_rewards += rescue_day.on_landing(10 * n, false, n < 2, maxi(1, n), false)
	_expect(rescue_day.goals_claimed == 7 and rescue_rewards == 15, "rescue and combo daily mission set pays exactly once")
	var distance_day = Daily.new()
	distance_day.refresh_day(22001) # day_id % 3 == 2
	var distance_rewards := 0
	for n in range(6):
		distance_rewards += distance_day.on_landing(28 * n, true, false, n, n < 3)
	_expect(distance_day.goals_claimed == 7 and distance_rewards == 21, "long-jump/distance daily mission set pays once")
	_expect(distance_day.claim_goals() == 0 and rescue_day.claim_goals() == 0, "rotated daily missions cannot be farmed twice")
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

	var test_ads := TestAdBridge.new()
	root.add_child(test_ads)
	monet.ads = test_ads
	monet.elapsed = 100.0
	monet.completed_runs = 3
	monet.runs_since_ad = 3
	_expect(not monet.request_break_interstitial(), "no interstitial in first three runs")
	monet.completed_runs = 4
	monet.runs_since_ad = 4
	_expect(not monet.request_break_interstitial(), "no interstitial before 6 minutes")
	monet.elapsed = 361.0
	_expect(monet.request_break_interstitial(), "natural break eligible after four runs and 6 minutes")
	_expect(test_ads.shown == 1, "one interstitial requested from real-provider abstraction")
	_expect(not monet.request_break_interstitial(), "cooldown prevents consecutive interstitials")
	# If the provider refuses an impression, the cadence must not be consumed.
	monet.last_interstitial = 0.0
	monet.runs_since_ad = 4
	monet.elapsed = 1300.0
	test_ads.allow_show = false
	_expect(not monet.request_break_interstitial(), "provider refusal cannot count as a shown ad")
	_expect(monet.runs_since_ad == 4 and monet.last_interstitial == 0.0, "provider refusal preserves ad cadence")
	test_ads.allow_show = true
	_expect(monet.request_break_interstitial(), "later eligible ad can be shown normally")

	var earned := [0]
	monet.rewarded_leaves_granted.connect(func(amount: int) -> void: earned[0] += amount)
	monet._reward_pending = true
	monet._on_reward_earned()
	monet._on_reward_earned()
	_expect(earned[0] == 5, "reward callback grants exactly five leaves only once")
	monet.premium = true
	monet.completed_runs = 100
	monet.runs_since_ad = 100
	monet.elapsed = 2000
	_expect(not monet.request_break_interstitial(), "owned remove-ads entitlement blocks interstitial")
	_expect(not monet.request_rewarded_leaves(), "owned remove-ads entitlement blocks rewarded ads")
	monet.ads = null
	test_ads.queue_free()
	monet.queue_free()
	await process_frame
	if errors == 0:
		print("PASS: daily goals, UTC rollover, clock rollback, streak, save integrity, and safe unavailable billing/ads")
	quit(0 if errors == 0 else 1)

func _expect(ok: bool, label: String) -> void:
	if not ok:
		errors += 1
		push_error("FAIL: " + label)
