extends RefCounted
## Six curated rivers with separate difficulty, goals, and permanent medals.
## No consumables, paid shortcuts or time gates: every chapter unlocks by play.
const LEVELS := [
	{"name": "SUNNY BANKS", "biome": 0, "target": 105, "radius": 1.12, "drift": 82.0, "wave": -0.25, "reward": 12, "score": 780, "leaves": 2},
	{"name": "LILY GARDEN", "biome": 1, "target": 130, "radius": 1.06, "drift": 94.0, "wave": 0.0, "reward": 16, "score": 1120, "leaves": 3},
	{"name": "GOLDEN REEDS", "biome": 2, "target": 150, "radius": 1.00, "drift": 104.0, "wave": 0.25, "reward": 20, "score": 1420, "leaves": 4},
	{"name": "MOONLIT POND", "biome": 3, "target": 175, "radius": 0.96, "drift": 111.0, "wave": 0.50, "reward": 25, "score": 1700, "leaves": 5},
	{"name": "CRYSTAL RIVER", "biome": 4, "target": 195, "radius": 0.93, "drift": 115.0, "wave": 0.75, "reward": 32, "score": 2050, "leaves": 6},
	{"name": "STORMY RAPIDS", "biome": 5, "target": 220, "radius": 0.90, "drift": 119.0, "wave": 1.1, "reward": 40, "score": 2460, "leaves": 7}
]

# Fixed, versioned course identities. Changing seeds requires explicit record migration.
# Endless remains procedural and Daily River retains its separate UTC seed.
const COURSE_SEEDS := [171009, 284119, 398221, 471449, 587033, 692191]
const SECTOR_METERS := 140.0
var unlocked_count := 1
var medals := [0, 0, 0, 0, 0, 0]
var attempts := [0, 0, 0, 0, 0, 0]
# Persistent best completed time in milliseconds, zero before first finish.
var best_times_ms := [0, 0, 0, 0, 0, 0]
# Best halfway split from a FULLY completed chapter, not an abandoned run.
var best_splits_ms := [0, 0, 0, 0, 0, 0]

func load_from(save: ConfigFile) -> void:
	unlocked_count = clampi(int(save.get_value("chapters", "unlocked", 1)), 1, LEVELS.size())
	for i in range(LEVELS.size()):
		medals[i] = clampi(int(save.get_value("chapters", "medal_%d" % i, 0)), 0, 3)
		attempts[i] = maxi(0, int(save.get_value("chapters", "attempts_%d" % i, 0)))
		best_times_ms[i] = clampi(int(save.get_value("chapters", "best_time_ms_%d" % i, 0)), 0, 86400000)
		best_splits_ms[i] = clampi(int(save.get_value("chapters", "best_split_ms_%d" % i, 0)), 0, 86400000)
		if medals[i] > 0:
			unlocked_count = maxi(unlocked_count, mini(i + 2, LEVELS.size()))

func write_to(save: ConfigFile) -> void:
	save.set_value("chapters", "unlocked", unlocked_count)
	for i in range(LEVELS.size()):
		save.set_value("chapters", "medal_%d" % i, medals[i])
		save.set_value("chapters", "attempts_%d" % i, attempts[i])
		save.set_value("chapters", "best_time_ms_%d" % i, best_times_ms[i])
		save.set_value("chapters", "best_split_ms_%d" % i, best_splits_ms[i])

func can_play(index: int) -> bool:
	return index >= 0 and index < unlocked_count and index < LEVELS.size()

func chapter(index: int) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		return {}
	return LEVELS[index]

func course_seed(index: int) -> int:
	return int(COURSE_SEEDS[index]) if index >= 0 and index < COURSE_SEEDS.size() else 0

func biome_at(distance: float, selected_chapter: int) -> int:
	if selected_chapter >= 0:
		return clampi(selected_chapter, 0, LEVELS.size() - 1)
	return posmod(int(floor(maxf(distance, 0.0) / SECTOR_METERS)), LEVELS.size())

func record_attempt(index: int) -> void:
	if can_play(index):
		attempts[index] += 1

func complete(index: int, score: int, found_leaves: int) -> Dictionary:
	if not can_play(index):
		return {"stars": 0, "reward": 0}
	var level: Dictionary = LEVELS[index]
	var stars := 1
	if score >= int(level["score"]):
		stars += 1
	if found_leaves >= int(level["leaves"]):
		stars += 1
	var previous: int = medals[index]
	medals[index] = maxi(previous, stars)
	unlocked_count = maxi(unlocked_count, mini(index + 2, LEVELS.size()))
	# A small extra award for improving a medal; never pay the same rank twice.
	var prize := 0
	if stars > previous:
		prize = int(level["reward"]) if previous == 0 else 0
		prize += 3 * (stars - maxi(previous, 1))
	return {"stars": stars, "reward": prize, "new_best": stars > previous}

# Only legitimately completed, unlocked chapters may set a personal record.
# Timing has no bearing on medal or currency payouts.
func record_time(index: int, elapsed_seconds: float) -> bool:
	if not can_play(index) or medals[index] <= 0:
		return false
	if elapsed_seconds <= 0.0 or elapsed_seconds > 86400.0 or elapsed_seconds != elapsed_seconds:
		return false
	var milliseconds := maxi(1, roundi(elapsed_seconds * 1000.0))
	var previous: int = int(best_times_ms[index])
	if previous != 0 and milliseconds >= previous:
		return false
	best_times_ms[index] = milliseconds
	return true

# Only a legitimately finished chapter can commit a checkpoint split.
# Replays cannot pay extra currency, and slower splits never overwrite PBs.
func record_split(index: int, elapsed_seconds: float) -> bool:
	if not can_play(index) or medals[index] <= 0:
		return false
	if elapsed_seconds <= 0.0 or elapsed_seconds > 86400.0 or elapsed_seconds != elapsed_seconds:
		return false
	var milliseconds := maxi(1, roundi(elapsed_seconds * 1000.0))
	var previous: int = int(best_splits_ms[index])
	if previous > 0 and milliseconds >= previous:
		return false
	best_splits_ms[index] = milliseconds
	return true

static func format_time(milliseconds: int) -> String:
	if milliseconds <= 0:
		return "--:--.-"
	var minutes: int = int(milliseconds / 60000)
	var seconds: int = int(milliseconds / 1000) % 60
	var tenths: int = int(milliseconds / 100) % 10
	return "%02d:%02d.%d" % [minutes, seconds, tenths]

func completed_count() -> int:
	var result := 0
	for stars in medals:
		if int(stars) > 0:
			result += 1
	return result
