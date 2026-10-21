extends RefCounted
## Rare, peaceful interludes during Endless runs. Only PRIMARY pads receive
## stages, avoiding impossible gold-route collisions and unfair crab combos.
const LENGTH := 3
const LEAVES := 3
const SCORE := 320
const FIRST_START := 23
const MIN_NEXT_GAP := 37
const MAX_NEXT_GAP := 49
var next_start_id := FIRST_START
var generated_group := -1
var active_group := -1
var progress := 0
var completions := 0

func reset() -> void:
	next_start_id = FIRST_START
	generated_group = -1
	active_group = -1
	progress = 0
	completions = 0

func decorate_primary(primary_id: int, rng: RandomNumberGenerator) -> Dictionary:
	if primary_id == next_start_id:
		generated_group = primary_id
		next_start_id = primary_id + rng.randi_range(MIN_NEXT_GAP, MAX_NEXT_GAP)
	if generated_group >= 0 and primary_id >= generated_group and primary_id < generated_group + LENGTH:
		return {"festival_group": generated_group, "festival_step": primary_id - generated_group}
	return {"festival_group": -1, "festival_step": -1}

func land(pad: Dictionary) -> bool:
	var group: int = int(pad.get("festival_group", -1))
	var step: int = int(pad.get("festival_step", -1))
	if group < 0 or step < 0:
		# A skipped or non-festival landing breaks the optional chain.
		active_group = -1
		progress = 0
		return false
	if bool(pad.get("festival_collected", false)):
		return false
	pad["festival_collected"] = true
	if step == 0:
		active_group = group
		progress = 1
		return false
	if group != active_group or step != progress:
		active_group = -1
		progress = 0
		return false
	progress += 1
	if progress >= LENGTH:
		progress = 0
		active_group = -1
		completions += 1
		return true
	return false
