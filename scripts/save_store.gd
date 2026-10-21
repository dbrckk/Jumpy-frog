extends RefCounted
## Crash-resistant persistence shared by progress and Google Play entitlement
## cache. Stage a complete ConfigFile, retain the last valid backup, then
## atomically rename it over the active file on Android/Linux.
const MAIN_PATH := "user://jumpy_frog.cfg"

static func read_into(config: ConfigFile, path: String = MAIN_PATH) -> Error:
	var error: Error = config.load(path)
	if error == OK:
		return OK
	# Older installations may have no backup. When the active file is
	# interrupted/corrupted, return the last parseable, complete snapshot.
	var backup_error: Error = config.load(path + ".bak")
	return OK if backup_error == OK else error


static func write(config: ConfigFile, path: String = MAIN_PATH) -> Error:
	var staged := path + ".writing"
	var save_error: Error = config.save(staged)
	if save_error != OK:
		return save_error

	# Never replace a valid backup with an invalid/corrupted active file.
	var prior := ConfigFile.new()
	if prior.load(path) == OK:
		var copy_error: Error = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(path + ".bak")
		)
		if copy_error != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(staged))
			return copy_error

	var rename_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(staged),
		ProjectSettings.globalize_path(path)
	)
	if rename_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staged))
	return rename_error
