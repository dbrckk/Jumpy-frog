extends RefCounted
## Optional rotating challenges for long Endless runs.
## No additional hazards, time pressure, purchases, ads or failure penalties.
## Each goal uses events from successful REAL landings, not simulated rewards.
const FIRST_HOP := 18
const INTERVAL := 34
const LENGTH := 6
const REWARD_LEAVES := 2
const REWARD_SCORE := 180

const TYPE_PRECISION := 0
const TYPE_FORAGER := 1
const TYPE_LONG_JUMP := 2
const TYPE_FRIENDS := 3
const TYPES := 4
const TITLES := ["PRECISION SPRINT", "LEAF TRAIL", "LONG LEAP", "FRIEND RESCUE"]
const TARGETS := [3, 2, 2, 1]
const DESCRIPTIONS := ["PERFECT LANDINGS", "LEAVES COLLECTED", "JUMPS 17m+", "FRIENDS RESCUED"]
const LONG_JUMP_METERS := 17.0

var active := false
var start_hop := 0
var attempts := 0
var perfects := 0 # Retained as the precision-specific metric.
var completions := 0
var challenge_type := TYPE_PRECISION
var progress := 0
var last_processed_hop := 0
var completed_by_type := [0, 0, 0, 0]

func reset() -> void:
	active = false
	start_hop = 0
	attempts = 0
	perfects = 0
	completions = 0
	challenge_type = TYPE_PRECISION
	progress = 0
	last_processed_hop = 0
	completed_by_type = [0, 0, 0, 0]

func title() -> String:
	return TITLES[challenge_type]

func description() -> String:
	return DESCRIPTIONS[challenge_type]

func target() -> int:
	return int(TARGETS[challenge_type])

func snapshot() -> Dictionary:
	return {
		"active": active,
		"type": challenge_type,
		"title": title(),
		"description": description(),
		"progress": progress,
		"target": target(),
		"remaining": maxi(0, LENGTH - attempts)
	}

func on_landing(hops: int, perfect: bool, picked_leaf: bool = false, hop_distance_m: float = 0.0, rescued_friend: bool = false) -> Dictionary:
	# Repeated callbacks for the same hop must never advance a goal or pay
	# currency twice (e.g. on resume, overlapping collection events).
	if hops <= last_processed_hop:
		return {}
	last_processed_hop = hops
	if not active and hops >= FIRST_HOP and (hops - FIRST_HOP) % INTERVAL == 0:
		active = true
		start_hop = hops
		attempts = 0
		perfects = 0
		progress = 0
		# Alternating predictable categories guarantees real replay variety.
		challenge_type = int((hops - FIRST_HOP) / INTERVAL) % TYPES
	if not active:
		return {}
	attempts += 1
	if perfect:
		perfects += 1
	var earned := false
	match challenge_type:
		TYPE_PRECISION:
			earned = perfect
		TYPE_FORAGER:
			earned = picked_leaf
		TYPE_LONG_JUMP:
			earned = hop_distance_m >= LONG_JUMP_METERS
		TYPE_FRIENDS:
			earned = rescued_friend
	if earned:
		progress += 1
	var state := snapshot()
	if progress >= target():
		active = false
		completions += 1
		completed_by_type[challenge_type] += 1
		return {
			"won": true,
			"type": challenge_type,
			"title": title(),
			"leaves": REWARD_LEAVES,
			"score": REWARD_SCORE
		}
	if attempts >= LENGTH:
		active = false
		return {"won": false, "type": challenge_type, "title": title()}
	return state
