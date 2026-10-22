extends RefCounted
## Optional rotating challenges for long Endless runs.
## No additional hazards, time pressure, purchases, ads or failure penalties.
## Each goal uses events from successful REAL landings, not simulated rewards.
const FIRST_HOP := 18
const INTERVAL := 34
const LENGTH := 6
const REWARD_LEAVES := 2
const REWARD_SCORE := 180
const ADVANCED_LEAVES := 3
const ADVANCED_SCORE := 260
const PREVIEW_HOPS := 3
const MAX_LEVEL := 1

const TYPE_PRECISION := 0
const TYPE_FORAGER := 1
const TYPE_LONG_JUMP := 2
const TYPE_FRIENDS := 3
const TYPES := 4
const TITLES := ["PRECISION SPRINT", "LEAF TRAIL", "LONG LEAP", "FRIEND RESCUE"]
const TARGETS := [3, 2, 2, 1]
const ADVANCED_TARGETS := [4, 3, 3, 2]
const DESCRIPTIONS := ["PERFECT LANDINGS", "LEAVES COLLECTED", "JUMPS 17m+", "FRIENDS RESCUED"]
const LONG_JUMP_METERS := 17.0

var active := false
var start_hop := 0
var attempts := 0
var perfects := 0 # Retained as the precision-specific metric.
var completions := 0
var challenge_type := TYPE_PRECISION
var progress := 0
var level := 0
var rest_hops := 0
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
	level = 0
	rest_hops = 0
	last_processed_hop = 0
	completed_by_type = [0, 0, 0, 0]

func title() -> String:
	return TITLES[challenge_type]

func description() -> String:
	return DESCRIPTIONS[challenge_type]

func target() -> int:
	return int(ADVANCED_TARGETS[challenge_type]) if level > 0 else int(TARGETS[challenge_type])

func _sequence_number(hops: int) -> int:
	return maxi(0, int((hops - FIRST_HOP) / INTERVAL))

func snapshot(next_hop: int = 0) -> Dictionary:
	var info := {
		"active": active,
		"type": challenge_type,
		"title": title(),
		"description": description(),
		"progress": progress,
		"target": target(),
		"remaining": maxi(0, LENGTH - attempts),
		"level": level,
		"rest_hops": rest_hops
	}
	if not active and next_hop > 0:
		# Only the upcoming goal is announced; the preview is informative
		# and cannot start, pay or mutate a challenge.
		var next_number := maxi(0, int(ceil(float(next_hop - FIRST_HOP) / INTERVAL)))
		var scheduled := FIRST_HOP + next_number * INTERVAL
		var until := scheduled - next_hop
		if next_hop <= scheduled and until >= 0 and until < PREVIEW_HOPS:
			var next_type := next_number % TYPES
			info["upcoming"] = true
			info["next_title"] = TITLES[next_type]
			info["next_type"] = next_type
			info["next_level"] = mini(int(next_number / TYPES), MAX_LEVEL)
			info["starts_in"] = until
	return info

func on_landing(hops: int, perfect: bool, picked_leaf: bool = false, hop_distance_m: float = 0.0, rescued_friend: bool = false, eligible: bool = true) -> Dictionary:
	# Repeated callbacks for the same hop must never advance a goal or pay
	# currency twice (e.g. on resume, overlapping collection events).
	if hops <= last_processed_hop:
		return {}
	last_processed_hop = hops
	var just_started := false
	if not active and hops >= FIRST_HOP and (hops - FIRST_HOP) % INTERVAL == 0:
		just_started = true
		active = true
		start_hop = hops
		attempts = 0
		perfects = 0
		progress = 0
		rest_hops = 0
		# Rotate every type before increasing difficulty; the first 4
		# challenges remain the same familiar onboarding progression.
		var sequence := _sequence_number(hops)
		challenge_type = sequence % TYPES
		level = mini(int(sequence / TYPES), MAX_LEVEL)
	if not active:
		return {}
	if not eligible:
		# Firefly lilies cannot spawn coins or rescued friends. They are
		# intentionally calm and must not consume the player's skill window.
		rest_hops += 1
		var resting := snapshot()
		resting["started"] = just_started
		return resting
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
	state["started"] = just_started
	if progress >= target():
		active = false
		completions += 1
		completed_by_type[challenge_type] += 1
		return {
			"won": true,
			"type": challenge_type,
			"title": title(),
			"level": level,
			"target": target(),
			"leaves": ADVANCED_LEAVES if level > 0 else REWARD_LEAVES,
			"score": ADVANCED_SCORE if level > 0 else REWARD_SCORE
		}
	if attempts >= LENGTH:
		active = false
		return {"won": false, "type": challenge_type, "title": title(), "level": level}
	return state
