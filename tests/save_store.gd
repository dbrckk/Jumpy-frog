extends SceneTree
## Regression suite for atomic shared persistence and corrupted active-file recovery.
const STORE = preload("res://scripts/save_store.gd")
var fails := 0

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var path := "user://save_store_qa.cfg"
	for suffix in ["", ".bak", ".writing"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	var original := ConfigFile.new()
	original.set_value("progress", "leaves", 125)
	original.set_value("billing", "remove_ads_verified", true)
	original.set_value("weekly", "claimed", 3)
	_assert(STORE.write(original, path) == OK, "first save succeeds")
	_assert(FileAccess.file_exists(path), "a complete primary exists")
	var next := ConfigFile.new()
	_assert(STORE.read_into(next, path) == OK, "old file loads")
	next.set_value("progress", "leaves", 143)
	_assert(STORE.write(next, path) == OK, "atomic overwrite succeeds")
	_assert(FileAccess.file_exists(path + ".bak"), "last known-good backup is saved")
	var restored := ConfigFile.new()
	_assert(STORE.read_into(restored, path) == OK, "new primary loads")
	_assert(int(restored.get_value("progress", "leaves", -1)) == 143, "current update committed")
	_assert(bool(restored.get_value("billing", "remove_ads_verified", false)), "premium ownership survives progress update")
	_assert(int(restored.get_value("weekly", "claimed", -1)) == 3, "weekly claims survive progress update")

	# An interrupted/corrupted write must be recoverable, including the
	# Google Play entitlement and the old career and weekly progress.
	var damaged := FileAccess.open(path, FileAccess.WRITE)
	_assert(damaged != null, "test can corrupt active file")
	if damaged != null:
		damaged.store_string("[progress\nleaves=broken")
		damaged.close()
	var fallback := ConfigFile.new()
	_assert(STORE.read_into(fallback, path) == OK, "backup restores a damaged primary")
	_assert(int(fallback.get_value("progress", "leaves", -1)) == 125, "recover last valid snapshot")
	_assert(bool(fallback.get_value("billing", "remove_ads_verified", false)), "restore does not lose verified ad-free purchase")
	_assert(int(fallback.get_value("weekly", "claimed", -1)) == 3, "restore does not lose weekly claims")
	fallback.set_value("progress", "leaves", 126)
	_assert(STORE.write(fallback, path) == OK, "new healthy primary replaces damaged one")
	var old_backup := ConfigFile.new()
	_assert(old_backup.load(path + ".bak") == OK, "backup not overwritten with corrupt primary")
	_assert(int(old_backup.get_value("progress", "leaves", -1)) == 125, "backup retains last valid data")
	var post_recovery := ConfigFile.new()
	_assert(post_recovery.load(path) == OK and int(post_recovery.get_value("progress", "leaves", -1)) == 126, "recovered primary is now valid")
	_assert(not FileAccess.file_exists(path + ".writing"), "no unfinished temporary writes remain")

	# A failed save cannot destroy a previously valid file.
	var invalid_path := "user://not_a_created_dir_67896/nonexistent.cfg"
	_assert(STORE.write(original, invalid_path) != OK, "nonexistent parent directory fails safely")
	_assert(int(post_recovery.get_value("weekly", "claimed", -1)) == 3, "prior valid data remains intact")

	# Test an actual game save to ensure premium and records share the same
	# file safely. Tests run under an isolated Godot user:// sandbox.
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._reset_game()
	game.leaves = 77
	game.best_run_perfects = 11
	game.daily.weekly_claimed = 5
	game._save_progress()
	var snapshot := ConfigFile.new()
	_assert(STORE.read_into(snapshot) == OK, "real game save uses recoverable storage")
	_assert(int(snapshot.get_value("progress", "leaves", -1)) == 77, "real game saves currency")
	_assert(int(snapshot.get_value("records", "perfects", -1)) == 11, "real game saves best records")
	_assert(int(snapshot.get_value("weekly", "claimed", -1)) == 5, "real game saves weekly goals")
	game.queue_free()
	await process_frame

	for suffix in ["", ".bak", ".writing"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	if fails == 0:
		print("PASS: atomic writes, corruption recovery, premium/mission isolation and real game persistence")
	else:
		printerr("FAIL: %d save store regressions" % fails)
	quit(0 if fails == 0 else 1)

func _assert(ok: bool, label: String) -> void:
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
