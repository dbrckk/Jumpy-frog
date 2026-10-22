extends RefCounted
## Optional six-landing precision sprints: no new hazards or fail penalties.
const FIRST_HOP := 18
const INTERVAL := 34
const LENGTH := 6
const REQUIRED := 3
const REWARD_LEAVES := 2
const REWARD_SCORE := 180
var active := false
var start_hop := 0
var attempts := 0
var perfects := 0
var completions := 0

func reset() -> void:
	active = false
	start_hop = 0
	attempts = 0
	perfects = 0
	completions = 0

func on_landing(hops: int, perfect: bool) -> Dictionary:
	if not active and hops >= FIRST_HOP and (hops - FIRST_HOP) % INTERVAL == 0:
		active = true
		start_hop = hops
		attempts = 0
		perfects = 0
	if not active:
		return {}
	attempts += 1
	if perfect:
		perfects += 1
	if perfects >= REQUIRED:
		active = false
		completions += 1
		return {"won": true, "leaves": REWARD_LEAVES, "score": REWARD_SCORE}
	if attempts >= LENGTH:
		active = false
		return {"won": false}
	return {"progress": perfects, "remaining": LENGTH - attempts}
