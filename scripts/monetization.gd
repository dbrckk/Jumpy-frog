extends Node
## Monetization gate. Ads and billing require verified, installed Android SDKs.
## No ad is simulated; no entitlement is granted by clicking a button.
signal premium_changed(enabled: bool)
signal rewarded_leaves_granted(amount: int)
signal status_changed(message: String)

const PRODUCT_ID := "remove_ads"
const REWARD_LEAVES := 5
const INTERSTITIAL_MIN_RUNS := 4
const INTERSTITIAL_COOLDOWN_SECONDS := 360.0

var premium := false
var purchase_ready := false
var price_label := ""
var billing: Node
var ads: Node
var completed_runs := 0
var runs_since_ad := 0
var elapsed := 0.0
var last_interstitial := 0.0
var _reward_pending := false

func _ready() -> void:
	_load_cache()
	if not OS.has_feature("android"):
		return
	_init_billing()
	_init_ads()

func _process(delta: float) -> void:
	elapsed += maxf(delta, 0.0)

func _load_cache() -> void:
	var save := ConfigFile.new()
	if save.load("user://jumpy_frog.cfg") == OK:
		# Cache only a purchase previously observed through Play Billing.
		premium = bool(save.get_value("billing", "remove_ads_verified", false))

func _save_cache() -> void:
	var save := ConfigFile.new()
	# Use the same file as the game and preserve other sections.
	save.load("user://jumpy_frog.cfg")
	save.set_value("billing", "remove_ads_verified", premium)
	save.save("user://jumpy_frog.cfg")

func _init_billing() -> void:
	if not Engine.has_singleton("GodotGooglePlayBilling"):
		return
	var path := "res://addons/GodotGooglePlayBilling/BillingClient.gd"
	if not ResourceLoader.exists(path):
		return
	var source: Script = load(path)
	billing = source.new()
	add_child(billing)
	billing.connected.connect(_on_billing_connected)
	billing.connect_error.connect(func(_code: int, _message: String) -> void:
		status_changed.emit("Google Play inaccessible"))
	billing.query_product_details_response.connect(_on_product_details)
	billing.query_purchases_response.connect(_on_restore)
	billing.on_purchase_updated.connect(_on_purchases)
	billing.acknowledge_purchase_response.connect(_on_acknowledge)
	billing.start_connection()

func _on_billing_connected() -> void:
	billing.query_product_details(PackedStringArray([PRODUCT_ID]), 0) # INAPP
	billing.query_purchases(0) # restore past purchases, not just this session

func _on_product_details(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) != 0:
		return
	for item in result.get("product_details", []):
		var product: Dictionary = item
		if String(product.get("product_id", "")) == PRODUCT_ID:
			var offers: Variant = product.get("one_time_purchase_offer_details_list", [])
			if offers is Array and not offers.is_empty():
				price_label = String(offers[0].get("formatted_price", ""))
			purchase_ready = true
			status_changed.emit("Purchase available")

func purchase_remove_ads() -> bool:
	if premium or not purchase_ready or billing == null:
		return false
	var response: Dictionary = billing.purchase(PRODUCT_ID)
	return int(response.get("response_code", -1)) == 0

func restore_purchase() -> bool:
	if billing == null or not billing.is_ready():
		return false
	billing.query_purchases(0)
	return true

func _is_owned_purchase(purchase: Dictionary) -> bool:
	# Billing 3.3.0 emits PackedStringArray product IDs, but tolerate
	# ordinary arrays and ignore malformed callbacks without granting access.
	var ids: Variant = purchase.get("product_ids", null)
	if not (ids is Array or ids is PackedStringArray):
		return false
	return ids.has(PRODUCT_ID) and int(purchase.get("purchase_state", 0)) == 1


func _on_restore(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) != 0:
		return # retain locally verified offline ownership during network failures
	var is_owned := false
	for candidate in result.get("purchases", []):
		if candidate is Dictionary and _is_owned_purchase(candidate):
			is_owned = true
			break
	if not is_owned and premium:
		# A successful Google Play ownership query is authoritative for refunds.
		premium = false
		_save_cache()
		premium_changed.emit(false)
		_init_ads()
		return
	_on_purchases(result)

func _on_purchases(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) != 0:
		return
	for item in result.get("purchases", []):
		if not (item is Dictionary and _is_owned_purchase(item)):
			continue # Pending, invalid and unrelated purchases are not owned.
		var purchase: Dictionary = item
		if not premium:
			premium = true
			_save_cache()
			premium_changed.emit(true)
			on_purchase_restored()
		if not bool(purchase.get("is_acknowledged", false)) and billing != null:
			var token := String(purchase.get("purchase_token", ""))
			if not token.is_empty():
				billing.acknowledge_purchase(token)
		return

func _on_acknowledge(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) != 0:
		status_changed.emit("Google Play acknowledgement pending")

func _init_ads() -> void:
	if premium:
		return
	# This bridge is only installed in a monetized release build that has
	# real AdMob IDs, native plugin binaries and an UMP consent configuration.
	var bridge_path := "res://scripts/admob_bridge.gd"
	if not Engine.has_singleton("PoingGodotAdMob") or not ResourceLoader.exists(bridge_path):
		return
	var bridge_script: Script = load(bridge_path)
	if bridge_script == null:
		return
	ads = bridge_script.new()
	add_child(ads)
	ads.reward_earned.connect(_on_reward_earned)
	ads.reward_failed.connect(_on_reward_failed)
	ads.start()

func on_run_finished() -> void:
	completed_runs += 1
	runs_since_ad += 1

func request_break_interstitial() -> bool:
	if premium or ads == null:
		return false
	if completed_runs < INTERSTITIAL_MIN_RUNS or runs_since_ad < INTERSTITIAL_MIN_RUNS:
		return false
	if elapsed - last_interstitial < INTERSTITIAL_COOLDOWN_SECONDS:
		return false
	if not ads.can_show_interstitial():
		return false
	# An ad should count against pacing only when the native bridge actually
	# accepts the show request. Missing inventory never blocks the player.
	if not ads.show_interstitial():
		return false
	last_interstitial = elapsed
	runs_since_ad = 0
	return true

func can_watch_rewarded() -> bool:
	return not premium and not _reward_pending and ads != null and ads.can_show_rewarded()

func request_rewarded_leaves() -> bool:
	if not can_watch_rewarded():
		return false
	_reward_pending = true
	if not ads.show_rewarded():
		# Native inventory can disappear between availability and showing.
		_reward_pending = false
		return false
	return true

func _on_reward_earned() -> void:
	if not _reward_pending or premium:
		return
	_reward_pending = false
	rewarded_leaves_granted.emit(REWARD_LEAVES)

func _on_reward_failed() -> void:
	_reward_pending = false

func on_purchase_restored() -> void:
	if premium and ads != null:
		ads.stop_ads()
		ads.queue_free()
		ads = null
