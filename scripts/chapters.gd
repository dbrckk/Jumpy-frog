extends RefCounted
## Six curated rivers with separate difficulty, goals, and permanent medals.
## No consumables, paid shortcuts or time gates: every chapter unlocks by play.
const LEVELS := [
	{"name": "SUNNY BANKS", "biome": 0, "target": 105, "par": 32, "radius": 1.12, "drift": 82.0, "wave": -0.25, "reward": 12, "score": 780, "leaves": 2},
	{"name": "LILY GARDEN", "biome": 1, "target": 130, "par": 38, "radius": 1.06, "drift": 94.0, "wave": 0.0, "reward": 16, "score": 1120, "leaves": 3},
	{"name": "GOLDEN REEDS", "biome": 2, "target": 150, "par": 44, "radius": 1.00, "drift": 104.0, "wave": 0.25, "reward": 20, "score": 1420, "leaves": 4},
	{"name": "MOONLIT POND", "biome": 3, "target": 175, "par": 50, "radius": 0.96, "drift": 111.0, "wave": 0.50, "reward": 25, "score": 1700, "leaves": 5},
	{"name": "CRYSTAL RIVER", "biome": 4, "target": 195, "par": 56, "radius": 0.93, "drift": 115.0, "wave": 0.75, "reward": 32, "score": 2050, "leaves": 6},
	{"name": "STORMY RAPIDS", "biome": 5, "target": 220, "par": 62, "radius": 0.90, "drift": 119.0, "wave": 1.1, "reward": 40, "score": 2460, "leaves": 7}
]

# Fixed, versioned course identities. Changing seeds requires explicit record migration.
# Endless remains procedural and Daily River retains its separate UTC seed.
const COURSE_SEEDS := [171009, 284119, 398221, 471449, 587033, 692191]
const SECTOR_METERS := 140.0
const BADGE_PACE := 1
const BADGE_PRECISION := 2
const BADGE_FLOW := 4
const BADGE_ALL := BADGE_PACE | BADGE_PRECISION | BADGE_FLOW
var unlocked_count := 1
var medals := [0, 0, 0, 0, 0, 0]
var attempts := [0, 0, 0, 0, 0, 0]
# Persistent best completed time in milliseconds, zero before first finish.
var best_times_ms := [0, 0, 0, 0, 0, 0]
# Best halfway split from a FULLY completed chapter, not an abandoned run.
var best_splits_ms := [0, 0, 0, 0, 0, 0]
# Three permanent skill achievements on each fixed course; no leaves are paid.
var mastery_masks := [0, 0, 0, 0, 0, 0]

func load_from(save: ConfigFile) -> void:
	unlocked_count = clampi(int(save.get_value("chapters", "unlocked", 1)), 1, LEVELS.size())
	for i in range(LEVELS.size()):
		medals[i] = clampi(int(save.get_value("chapters", "medal_%d" % i, 0)), 0, 3)
		attempts[i] = maxi(0, int(save.get_value("chapters", "attempts_%d" % i, 0)))
		best_times_ms[i] = clampi(int(save.get_value("chapters", "best_time_ms_%d" % i, 0)), 0, 86400000)
		best_splits_ms[i] = clampi(int(save.get_value("chapters", "best_split_ms_%d" % i, 0)), 0, 86400000)
		mastery_masks[i] = clampi(int(save.get_value("chapters", "mastery_mask_%d" % i, 0)), 0, BADGE_ALL)
		if medals[i] > 0:
			unlocked_count = maxi(unlocked_count, mini(i + 2, LEVELS.size()))

func write_to(save: ConfigFile) -> void:
	save.set_value("chapters", "unlocked", unlocked_count)
	for i in range(LEVELS.size()):
		save.set_value("chapters", "medal_%d" % i, medals[i])
		save.set_value("chapters", "attempts_%d" % i, attempts[i])
		save.set_value("chapters", "best_time_ms_%d" % i, best_times_ms[i])
		save.set_value("chapters", "best_split_ms_%d" % i, best_splits_ms[i])
		save.set_value("chapters", "mastery_mask_%d" % i, mastery_masks[i])

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

# The game calls this only after a REAL chapter victory. The run must include
# at least four landings. Achievements accumulate over separate valid wins.
# PACE: beat river-specific par. PRECISION: 75% perfect, minimum four.
# FLOW: trigger a four-perfect Flow Rush. None awards replayable currency.
func record_mastery(index: int, elapsed_seconds: float, hops: int, perfects: int, flows: int) -> int:
	if not can_play(index) or int(medals[index]) <= 0:
		return 0
	if elapsed_seconds <= 0.0 or elapsed_seconds > 86400.0 or elapsed_seconds != elapsed_seconds:
		return 0
	if hops < 4 or perfects < 0 or perfects > hops or flows < 0 or flows > perfects:
		return 0
	var earned := 0
	if elapsed_seconds <= float(LEVELS[index]["par"]):
		earned |= BADGE_PACE
	if perfects >= 4 and perfects * 4 >= hops * 3:
		earned |= BADGE_PRECISION
	if flows > 0 and perfects >= 4:
		earned |= BADGE_FLOW
	var previous: int = int(mastery_masks[index])
	var fresh: int = earned & ~previous
	mastery_masks[index] = previous | earned
	return fresh

func mastery_count(index: int) -> int:
	if index < 0 or index >= mastery_masks.size():
		return 0
	var mask: int = int(mastery_masks[index])
	var count := 0
	for bit in [BADGE_PACE, BADGE_PRECISION, BADGE_FLOW]:
		if (mask & bit) != 0:
			count += 1
	return count

func mastered_total() -> int:
	var count := 0
	for i in range(mastery_masks.size()):
		count += mastery_count(i)
	return count

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
