extends RefCounted
## A real offline daily progression loop. UTC days and backwards-clock protection.
const GOALS := [
	{"title": "MAKE 8 HOPS", "target": 8, "reward": 3},
	{"title": "COLLECT 4 LEAVES", "target": 4, "reward": 5},
	{"title": "REACH 80 METERS", "target": 80, "reward": 7}
]
var day_id: int = -1
var today_hops := 0
var today_leaves := 0
var today_distance := 0
var today_best := 0
var goals_claimed := 0
var last_session_day := -1
var streak_days := 0
var lifetime_hops := 0
var lifetime_leaves := 0
var daily_sessions := 0

func load_from(save: ConfigFile) -> void:
	day_id = int(save.get_value("daily", "day_id", -1))
	today_hops = maxi(0, int(save.get_value("daily", "hops", 0)))
	today_leaves = maxi(0, int(save.get_value("daily", "leaves", 0)))
	today_distance = maxi(0, int(save.get_value("daily", "distance", 0)))
	today_best = maxi(0, int(save.get_value("daily", "best", 0)))
	goals_claimed = int(save.get_value("daily", "claimed", 0)) & 7
	last_session_day = int(save.get_value("daily", "last_session_day", -1))
	streak_days = clampi(int(save.get_value("daily", "streak_days", 0)), 0, 100000)
	lifetime_hops = maxi(0, int(save.get_value("lifetime", "hops", 0)))
	lifetime_leaves = maxi(0, int(save.get_value("lifetime", "leaves", 0)))
	daily_sessions = maxi(0, int(save.get_value("daily", "sessions", 0)))
	refresh_day()

func write_to(save: ConfigFile) -> void:
	save.set_value("daily", "day_id", day_id)
	save.set_value("daily", "hops", today_hops)
	save.set_value("daily", "leaves", today_leaves)
	save.set_value("daily", "distance", today_distance)
	save.set_value("daily", "best", today_best)
	save.set_value("daily", "claimed", goals_claimed)
	save.set_value("daily", "last_session_day", last_session_day)
	save.set_value("daily", "streak_days", streak_days)
	save.set_value("daily", "sessions", daily_sessions)
	save.set_value("lifetime", "hops", lifetime_hops)
	save.set_value("lifetime", "leaves", lifetime_leaves)

func refresh_day(now: int = -1) -> bool:
	var actual := now if now >= 0 else int(floor(Time.get_unix_time_from_system() / 86400.0))
	if actual <= day_id:
		return false
	day_id = actual
	today_hops = 0
	today_leaves = 0
	today_distance = 0
	today_best = 0
	goals_claimed = 0
	daily_sessions = 0
	return true

func begin_run(now: int = -1) -> void:
	refresh_day(now)
	if last_session_day < day_id:
		streak_days = streak_days + 1 if last_session_day == day_id - 1 else 1
		last_session_day = day_id
		daily_sessions += 1

func on_landing(height_m: int, leaf_collected: bool) -> int:
	today_hops += 1
	lifetime_hops += 1
	if leaf_collected:
		today_leaves += 1
		lifetime_leaves += 1
	today_distance = maxi(today_distance, height_m)
	return claim_goals()

func on_finish(score: int) -> void:
	today_best = maxi(today_best, score)

func claim_goals() -> int:
	var reward := 0
	for index in range(GOALS.size()):
		if goals_claimed & (1 << index):
			continue
		if progress(index) >= int(GOALS[index]["target"]):
			goals_claimed |= 1 << index
			reward += int(GOALS[index]["reward"])
	return reward

func progress(index: int) -> int:
	match index:
		0: return today_hops
		1: return today_leaves
		2: return today_distance
	return 0

func completion_count() -> int:
	var count := 0
	for i in range(GOALS.size()):
		if goals_claimed & (1 << i):
			count += 1
	return count
