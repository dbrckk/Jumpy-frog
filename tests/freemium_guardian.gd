extends SceneTree
## Freemium v1.4: no forced ads, one-use rewarded shield and lifetime River Pass.
const SAVE_STORE = preload("res://scripts/save_store.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_exercise")

func _check(valid: bool, label: String) -> void:
	if not valid:
		failures += 1
		push_error("FAIL: " + label)

func _exercise() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# A verified rewarded callback is credited and persisted even if the
	# player already left the result screen or is currently on the title.
	game._reset_game()
	var wallet: int = game.leaves
	game._on_rewarded_leaves(5)
	_check(game.rewarded_shield_queued and game.leaves == wallet + 5,
		"native rewarded callback queues a shield and pays five leaves")
	var saved := ConfigFile.new()
	_check(SAVE_STORE.read_into(saved) == OK, "earned benefit save is readable")
	_check(bool(saved.get_value("progress", "rewarded_shield_queued", false)),
		"rewarded benefit remains in storage after callback")
	game._reset_game()
	_check(game.rewarded_shield_queued and not game.guardian_charge,
		"returning to title never consumes a paid-for-video shield")
	game._activate_run_benefits()
	_check(game.guardian_charge and not game.rewarded_shield_queued,
		"starting a real run equips the earned shield exactly once")
	game._save_progress()
	var after_use := ConfigFile.new()
	_check(SAVE_STORE.read_into(after_use) == OK and
		not bool(after_use.get_value("progress", "rewarded_shield_queued", true)),
		"consumed one-use benefit is atomically persisted")
	game._reset_game()
	game._activate_run_benefits()
	_check(not game.guardian_charge, "free runner's next run does not get a second shield")
	_check(is_equal_approx(game.wave_m, -32.0),
		"free runner starts with the original fair wave offset")

	# Lifetime advantages must come from Billing premium ownership only.
	game.monetization.premium = true
	game._reset_game()
	game._activate_run_benefits()
	_check(game.guardian_charge and is_equal_approx(game.wave_m, -44.0),
		"River Pass adds a Guardian and twelve extra metres every run")
	game.guardian_charge = false
	game._reset_game()
	game._activate_run_benefits()
	_check(game.guardian_charge and game.wave_m <= -44.0,
		"River Pass renews its benefit for each new run, never just once")
	game.monetization.premium = false
	game._reset_game()
	game._activate_run_benefits()
	_check(not game.guardian_charge and is_equal_approx(game.wave_m, -32.0),
		"refund/revocation removes future-run paid advantages")

	# Regression: one normal real hop remains freely playable after a
	# premium revocation, with exactly the same collision and layout rules.
	game.mode = game.MODE_PLAY
	var target: Dictionary = game.pads[1]
	game.aim_x = float(target["x"])
	game.aim_m = float(target["m"])
	game._start_jump()
	_check(game.jump_pad_id == int(target["id"]), "base free physics predicts a valid jump")
	for frame in range(65):
		game._process(0.02)
		if game.mode != game.MODE_FLY:
			break
	_check(game.mode == game.MODE_PLAY and game.run_hops == 1,
		"free player still lands safely after premium revocation")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: rewarded benefit survives restart, pays once, paid lifetime shield/head-start, refunded access revoked")
	else:
		printerr("FAIL: freemium Guardian QA: %d errors" % failures)
	quit(0 if failures == 0 else 1)
