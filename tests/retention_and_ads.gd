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
	var allow_rewarded := true
	func show_rewarded() -> bool:
		return allow_rewarded


class TestBilling extends Node:
	var acknowledged_tokens: Array[String] = []
	func acknowledge_purchase(token: String) -> void:
		acknowledged_tokens.append(token)


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
	# Lifetime milestones must be earned once and survive daily resets.
	var lifetime = Daily.new()
	lifetime.refresh_day(22000)
	for i in range(25):
		lifetime.on_landing(i * 9, true, false, 1, false)
	_expect(lifetime.milestone_count() == 2, "25 hops and 15 leaves unlock two lifetime milestones")
	_expect(lifetime.claim_milestones() == 0, "completed lifetime milestones cannot be farmed again")
	_expect(lifetime.lifetime_best_distance == 216, "lifetime personal distance is tracked")
	var next: Dictionary = lifetime.next_milestone()
	_expect(int(next.get("target", 0)) == 250, "next lifetime goal is 250 meters")
	var persistent_save := ConfigFile.new()
	lifetime.write_to(persistent_save)
	var loaded_lifetime = Daily.new()
	loaded_lifetime.load_from(persistent_save)
	_expect(loaded_lifetime.milestone_count() == 2, "milestones persist in ConfigFile")
	_expect(loaded_lifetime.lifetime_best_distance == 216, "lifetime distance persists in ConfigFile")
	loaded_lifetime.refresh_day(22008)
	_expect(loaded_lifetime.milestone_count() == 2, "daily rollover never resets lifetime milestones")
	_expect(loaded_lifetime.claim_milestones() == 0, "daily rollover never reissues milestone rewards")

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
	test_ads.allow_rewarded = false
	_expect(not monet.request_rewarded_leaves(), "rewarded ad refusal cannot start a reward")
	_expect(not monet._reward_pending, "native reward refusal clears pending flag")
	test_ads.allow_rewarded = true
	_expect(monet.request_rewarded_leaves(), "real provider acceptance can start rewarded ad")
	_expect(monet._reward_pending, "accepted rewarded ad marks reward pending")
	monet._on_reward_failed()
	_expect(not monet._reward_pending, "dismissed rewarded ad clears pending flag")
	# No unsolicited ads, regardless of elapsed time or completed runs.
	monet.elapsed = 999999.0
	monet.completed_runs = 999
	monet.runs_since_ad = 999
	_expect(not monet.request_break_interstitial(), "free tier never runs automatic interstitial ads")
	_expect(test_ads.shown == 0, "even an available provider cannot display a forced ad")

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
	# The score screen must not trigger an unexpected interstitial.
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.monetization.premium = false
	game.monetization.ads = test_ads
	game.monetization.completed_runs = 3
	game.monetization.runs_since_ad = 3
	game.monetization.elapsed = 800.0
	game.mode = 1
	var ads_before := test_ads.shown
	game._die()
	_expect(game.mode == 4, "run ends at visible score screen")
	_expect(test_ads.shown == ads_before, "no automatic interruption when score appears")
	var previous_attempts: int = game.total_runs
	game._down(Vector2(270, 639)) # Between RESTART and rewarded ad controls.
	_expect(game.mode == game.MODE_LOST and game.total_runs == previous_attempts,
		"tapping results summary never restarts an endless run")
	game._down(Vector2(175, 593))
	_expect(test_ads.shown == ads_before, "retry must never request an automatic ad")
	_expect(game.mode == game.MODE_PLAY,
		"retry starts controllable gameplay without consuming its press as an aim gesture")
	# Emulate ONLY the trusted monetization->game signal handler. A delayed
	# native reward callback must survive a navigation away from the score.
	var wallet_before: int = game.leaves
	game._on_rewarded_leaves(5)
	_expect(game.leaves == wallet_before + 5, "verified reward survives result-screen navigation")
	_expect(game.rewarded_shield_queued, "verified rewarded video queues a next-run shield")
	var wallet_saved := ConfigFile.new()
	_expect(wallet_saved.load("user://jumpy_frog.cfg") == OK, "delayed reward saved immediately")
	_expect(int(wallet_saved.get_value("progress", "leaves", -1)) == game.leaves, "wallet persistence after late reward")
	game.mode = 4
	game.rewarded_this_run = false
	game._on_rewarded_leaves(5)
	_expect(game.rewarded_this_run, "result-screen native reward is marked claimed")
	_expect(game.leaves == wallet_before + 10, "result-screen callback grants one reward")
	_expect(game.rewarded_shield_queued, "earned shield survives result-screen callback")
	game._on_rewarded_leaves(5)
	_expect(game.leaves == wallet_before + 10, "duplicate result-screen callback cannot grant twice")
	game.monetization.ads = null
	game.queue_free()
	await process_frame
	# Exercise the purchase schema emitted by Godot Google Play Billing 3.3.0.
	# In particular product_ids arrives as PackedStringArray, not a JSON Array.
	monet.ads = null
	monet.premium = false
	var test_billing := TestBilling.new()
	root.add_child(test_billing)
	monet.billing = test_billing
	monet._on_purchases({"response_code": 0, "purchases": [{
		"product_ids": PackedStringArray(["remove_ads"]),
		"purchase_state": 2,
		"is_acknowledged": false,
		"purchase_token": "pending-token"
	}]})
	_expect(not monet.premium and test_billing.acknowledged_tokens.is_empty(),
		"pending transaction does not unlock or acknowledge premium")
	monet._on_purchases({"response_code": 0, "purchases": [{
		"product_ids": PackedStringArray(["different_product"]),
		"purchase_state": 1,
		"purchase_token": "unrelated-token"
	}]})
	_expect(not monet.premium, "unrelated Play product cannot unlock premium")
	monet._on_purchases({"response_code": 0, "purchases": [
		{"product_ids": null, "purchase_state": 1},
		{"purchase_state": 1}, "invalid-record"
	]})
	_expect(not monet.premium, "malformed Play callbacks cannot unlock premium")
	var paid := {"product_ids": PackedStringArray(["remove_ads"]),
		"purchase_state": 1, "is_acknowledged": false, "purchase_token": "verified-token"}
	monet._on_purchases({"response_code": 0, "purchases": [paid]})
	_expect(monet.premium, "completed Play purchase grants permanent remove-ads entitlement")
	_expect(test_billing.acknowledged_tokens == ["verified-token"],
		"completed unacknowledged purchase is acknowledged once")
	monet._on_restore({"response_code": 2, "purchases": []})
	_expect(monet.premium, "billing service error cannot revoke existing offline entitlement")
	monet._on_restore({"response_code": 0, "purchases": [paid]})
	_expect(monet.premium, "successful restore keeps an owned non-consumable")
	monet._on_restore({"response_code": 0, "purchases": []})
	_expect(not monet.premium, "authoritative empty Play ownership query revokes refunded purchase")
	monet.billing = null
	test_billing.queue_free()
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
