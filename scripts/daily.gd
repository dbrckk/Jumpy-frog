extends RefCounted
## A real offline daily progression loop. UTC days and backwards-clock protection.
const GOALS := [
	[
		{"title": "MAKE 8 HOPS", "target": 8, "reward": 3, "kind": "hops"},
		{"title": "COLLECT 4 LEAVES", "target": 4, "reward": 5, "kind": "leaves"},
		{"title": "REACH 80 METERS", "target": 80, "reward": 7, "kind": "distance"}
	],
	[
		{"title": "MAKE 10 HOPS", "target": 10, "reward": 4, "kind": "hops"},
		{"title": "RESCUE 2 FRIENDS", "target": 2, "reward": 5, "kind": "friends"},
		{"title": "COMBO OF 3", "target": 3, "reward": 6, "kind": "combo"}
	],
	[
		{"title": "COLLECT 6 LEAVES", "target": 6, "reward": 6, "kind": "leaves"},
		{"title": "REACH 120 METERS", "target": 120, "reward": 8, "kind": "distance"},
		{"title": "3 LONG SIDE JUMPS", "target": 3, "reward": 7, "kind": "long_hops"}
	]
]
## Monday-to-Sunday UTC expeditions: reachable for casual players, no
## spending, no paid shortcuts and no pressure to log in on consecutive days.
const WEEKLY_GOALS := [
	{"kind": "hops", "target": 30, "reward": 8, "title": "30 RIVER HOPS"},
	{"kind": "perfect", "target": 8, "reward": 12, "title": "8 PERFECT LANDINGS"},
	{"kind": "friends", "target": 3, "reward": 15, "title": "RESCUE 3 FRIENDS"}
]
## Lifetime achievements are awarded once, independent of the UTC daily reset.
const MILESTONES := [
	{"kind": "hops", "target": 25, "reward": 6, "title": "FIRST 25 HOPS"},
	{"kind": "leaves", "target": 15, "reward": 8, "title": "GATHER 15 LEAVES"},
	{"kind": "distance", "target": 250, "reward": 10, "title": "REACH 250 METERS"},
	{"kind": "hops", "target": 75, "reward": 15, "title": "75 LILY HOPS"},
	{"kind": "leaves", "target": 60, "reward": 22, "title": "60 LEAVES"},
	{"kind": "distance", "target": 800, "reward": 28, "title": "REACH 800 METERS"},
	{"kind": "hops", "target": 250, "reward": 40, "title": "250 LILY HOPS"},
	{"kind": "distance", "target": 2000, "reward": 65, "title": "REACH 2 KM"},
	{"kind": "hops", "target": 1000, "reward": 100, "title": "1000 LILY HOPS"}
]

var day_id: int = -1
var today_hops := 0
var today_leaves := 0
var today_distance := 0
var today_best := 0
var today_friends := 0
var today_combo := 0
var today_long_hops := 0
var goals_claimed := 0
var last_session_day := -1
var streak_days := 0
var lifetime_hops := 0
var lifetime_leaves := 0
var lifetime_best_distance := 0
var milestones_claimed := 0
var daily_sessions := 0
var weekly_id := -1
var weekly_hops := 0
var weekly_perfect := 0
var weekly_friends := 0
var weekly_claimed := 0
## Daily River: same seeded route every UTC day, one completion payout.
const RIVER_TARGET := 180.0
const RIVER_REWARD := 25
var river_best_score := 0
var river_completed_day := -1
var river_attempts := 0

func load_from(save: ConfigFile) -> void:
	day_id = int(save.get_value("daily", "day_id", -1))
	today_hops = maxi(0, int(save.get_value("daily", "hops", 0)))
	today_leaves = maxi(0, int(save.get_value("daily", "leaves", 0)))
	today_distance = maxi(0, int(save.get_value("daily", "distance", 0)))
	today_best = maxi(0, int(save.get_value("daily", "best", 0)))
	today_friends = maxi(0, int(save.get_value("daily", "friends", 0)))
	today_combo = maxi(0, int(save.get_value("daily", "combo", 0)))
	today_long_hops = maxi(0, int(save.get_value("daily", "long_hops", 0)))
	goals_claimed = int(save.get_value("daily", "claimed", 0)) & 7
	last_session_day = int(save.get_value("daily", "last_session_day", -1))
	streak_days = clampi(int(save.get_value("daily", "streak_days", 0)), 0, 100000)
	lifetime_hops = maxi(0, int(save.get_value("lifetime", "hops", 0)))
	lifetime_leaves = maxi(0, int(save.get_value("lifetime", "leaves", 0)))
	lifetime_best_distance = maxi(0, int(save.get_value("lifetime", "best_distance", 0)))
	milestones_claimed = maxi(0, int(save.get_value("lifetime", "milestones_claimed", 0))) & ((1 << MILESTONES.size()) - 1)
	daily_sessions = maxi(0, int(save.get_value("daily", "sessions", 0)))
	weekly_id = int(save.get_value("weekly", "id", -1))
	weekly_hops = maxi(0, int(save.get_value("weekly", "hops", 0)))
	weekly_perfect = maxi(0, int(save.get_value("weekly", "perfect", 0)))
	weekly_friends = maxi(0, int(save.get_value("weekly", "friends", 0)))
	weekly_claimed = int(save.get_value("weekly", "claimed", 0)) & 7
	river_best_score = maxi(0, int(save.get_value("daily", "river_best_score", 0)))
	river_completed_day = int(save.get_value("daily", "river_completed_day", -1))
	river_attempts = maxi(0, int(save.get_value("daily", "river_attempts", 0)))
	refresh_day()

func write_to(save: ConfigFile) -> void:
	save.set_value("daily", "day_id", day_id)
	save.set_value("daily", "hops", today_hops)
	save.set_value("daily", "leaves", today_leaves)
	save.set_value("daily", "distance", today_distance)
	save.set_value("daily", "best", today_best)
	save.set_value("daily", "friends", today_friends)
	save.set_value("daily", "combo", today_combo)
	save.set_value("daily", "long_hops", today_long_hops)
	save.set_value("daily", "claimed", goals_claimed)
	save.set_value("daily", "last_session_day", last_session_day)
	save.set_value("daily", "streak_days", streak_days)
	save.set_value("daily", "sessions", daily_sessions)
	save.set_value("weekly", "id", weekly_id)
	save.set_value("weekly", "hops", weekly_hops)
	save.set_value("weekly", "perfect", weekly_perfect)
	save.set_value("weekly", "friends", weekly_friends)
	save.set_value("weekly", "claimed", weekly_claimed)
	save.set_value("daily", "river_best_score", river_best_score)
	save.set_value("daily", "river_completed_day", river_completed_day)
	save.set_value("daily", "river_attempts", river_attempts)
	save.set_value("lifetime", "hops", lifetime_hops)
	save.set_value("lifetime", "leaves", lifetime_leaves)
	save.set_value("lifetime", "best_distance", lifetime_best_distance)
	save.set_value("lifetime", "milestones_claimed", milestones_claimed)

func refresh_day(now: int = -1) -> bool:
	var actual := now if now >= 0 else int(floor(Time.get_unix_time_from_system() / 86400.0))
	if actual <= day_id:
		# Existing saves must acquire a weekly clock even if the daily clock
		# has already been initialized by an older version of the game.
		_sync_week(day_id)
		return false
	day_id = actual
	_sync_week(day_id)
	today_hops = 0
	today_leaves = 0
	today_distance = 0
	today_best = 0
	today_friends = 0
	today_combo = 0
	today_long_hops = 0
	goals_claimed = 0
	daily_sessions = 0
	river_best_score = 0
	river_attempts = 0
	return true

static func week_for_day(utc_day: int) -> int:
	# Unix day 4 was Monday, 1970-01-05. Integer floor handles the
	# first partial week and every ISO-style Monday boundary in UTC.
	return int(floor((float(utc_day) - 4.0) / 7.0))


func _sync_week(utc_day: int) -> bool:
	if utc_day < 0:
		return false
	var current_week := week_for_day(utc_day)
	if current_week <= weekly_id:
		return false
	weekly_id = current_week
	weekly_hops = 0
	weekly_perfect = 0
	weekly_friends = 0
	weekly_claimed = 0
	return true


func weekly_progress(index: int) -> int:
	if index < 0 or index >= WEEKLY_GOALS.size():
		return 0
	match String(WEEKLY_GOALS[index]["kind"]):
		"hops": return weekly_hops
		"perfect": return weekly_perfect
		"friends": return weekly_friends
	return 0


func weekly_completion_count() -> int:
	var done := 0
	for i in range(WEEKLY_GOALS.size()):
		if (weekly_claimed & (1 << i)) != 0:
			done += 1
	return done


func claim_weekly() -> int:
	var reward := 0
	for i in range(WEEKLY_GOALS.size()):
		if (weekly_claimed & (1 << i)) != 0:
			continue
		var goal: Dictionary = WEEKLY_GOALS[i]
		if weekly_progress(i) >= int(goal["target"]):
			weekly_claimed |= (1 << i)
			reward += int(goal["reward"])
	return reward


func river_seed() -> int:
	# No network, account, or mutable server data involved.
	return int((day_id * 134775813 + 198237) & 0x7FFFFFFF)

func start_river() -> void:
	river_attempts += 1

func finish_river(score: int) -> int:
	river_best_score = maxi(river_best_score, maxi(score, 0))
	if river_completed_day == day_id:
		return 0
	river_completed_day = day_id
	return RIVER_REWARD

func river_complete_today() -> bool:
	return river_completed_day == day_id

func begin_run(now: int = -1) -> void:
	refresh_day(now)
	if last_session_day < day_id:
		streak_days = streak_days + 1 if last_session_day == day_id - 1 else 1
		last_session_day = day_id
		daily_sessions += 1

func on_landing(height_m: int, leaf_collected: bool, rescued: bool = false, combo_count: int = 0, long_hop: bool = false, perfect: bool = false) -> int:
	# Expired weekly progress rolls over only to a newer UTC week. Clock
	# rollback never reopens an old week or pays the same reward twice.
	refresh_day()
	today_hops += 1
	weekly_hops += 1
	if perfect:
		weekly_perfect += 1
	if rescued:
		weekly_friends += 1
	lifetime_hops += 1
	if leaf_collected:
		today_leaves += 1
		lifetime_leaves += 1
	today_distance = maxi(today_distance, height_m)
	lifetime_best_distance = maxi(lifetime_best_distance, height_m)
	if rescued:
		today_friends += 1
	today_combo = maxi(today_combo, combo_count)
	if long_hop:
		today_long_hops += 1
	return claim_goals() + claim_milestones() + claim_weekly()

func on_finish(score: int) -> void:
	today_best = maxi(today_best, score)

func claim_goals() -> int:
	var reward := 0
	for index in range(GOALS.size()):
		if goals_claimed & (1 << index):
			continue
		var goal := goal_at(index)
		if progress(index) >= int(goal["target"]):
			goals_claimed |= 1 << index
			reward += int(goal["reward"])
	return reward

func claim_milestones() -> int:
	var payout := 0
	for index in range(MILESTONES.size()):
		if (milestones_claimed & (1 << index)) != 0:
			continue
		var milestone: Dictionary = MILESTONES[index]
		if milestone_progress(index) >= int(milestone["target"]):
			milestones_claimed |= 1 << index
			payout += int(milestone["reward"])
	return payout

func milestone_progress(index: int) -> int:
	if index < 0 or index >= MILESTONES.size():
		return 0
	match String(MILESTONES[index]["kind"]):
		"hops": return lifetime_hops
		"leaves": return lifetime_leaves
		"distance": return lifetime_best_distance
	return 0

func next_milestone() -> Dictionary:
	for index in range(MILESTONES.size()):
		if (milestones_claimed & (1 << index)) == 0:
			var entry: Dictionary = MILESTONES[index].duplicate()
			entry["progress"] = milestone_progress(index)
			return entry
	return {}

func milestone_total() -> int:
	return MILESTONES.size()

func milestone_count() -> int:
	var total := 0
	for index in range(MILESTONES.size()):
		if (milestones_claimed & (1 << index)) != 0:
			total += 1
	return total

func goal_at(index: int) -> Dictionary:
	return GOALS[posmod(day_id, GOALS.size())][index]

func progress(index: int) -> int:
	var kind: String = String(goal_at(index)["kind"])
	match kind:
		"hops": return today_hops
		"leaves": return today_leaves
		"distance": return today_distance
		"friends": return today_friends
		"combo": return today_combo
		"long_hops": return today_long_hops
	return 0

func completion_count() -> int:
	var count := 0
	for i in range(GOALS.size()):
		if goals_claimed & (1 << i):
			count += 1
	return count
