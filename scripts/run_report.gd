extends RefCounted
## Pure, non-monetary end-of-run achievements. Grades cannot modify the
## economy, difficulty, purchases or saved milestone claims.
static func grade(hops: int, perfect: int, friends: int, flow: int) -> String:
	if hops <= 0:
		return "FIRST SPLASH"
	if hops >= 30 and perfect >= 12 and flow >= 2:
		return "RIVER LEGEND"
	if hops >= 15 and perfect >= 6:
		return "CURRENT MASTER"
	if hops >= 8 or perfect >= 4 or friends >= 2:
		return "LILY EXPLORER"
	return "RIVER ROOKIE"


static func next_weekly_goal(daily: RefCounted) -> Dictionary:
	# Nearest attainable weekly milestone, rather than always displaying
	# an arbitrary first task that may take much longer to complete.
	var nearest: Dictionary = {}
	var closest_remaining := INF
	for i in range(daily.WEEKLY_GOALS.size()):
		if (daily.weekly_claimed & (1 << i)) != 0:
			continue
		var goal: Dictionary = daily.WEEKLY_GOALS[i]
		var target: int = int(goal["target"])
		var progress: int = mini(daily.weekly_progress(i), target)
		var ratio := float(target - progress) / float(maxi(target, 1))
		if ratio < closest_remaining:
			closest_remaining = ratio
			nearest = {"title": String(goal["title"]), "progress": progress, "target": target}
	return nearest
