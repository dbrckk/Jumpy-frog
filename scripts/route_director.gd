extends RefCounted
## Lightweight phrase-based procedural director for Endless only.
## Replaces repetitive fixed slalom with four reachable 16-hop motifs.
## All lateral moves remain within each biome's existing drift budget.
const LENGTH := 16
const NAMES := ["MEADOW", "SWITCHBACK", "RIPPLE", "S-CURVE"]
var phrase_number := -1
var current_motif := 0
var motif_counts := [0, 0, 0, 0]
var last_motif := -1

func reset() -> void:
	phrase_number = -1
	current_motif = 0
	last_motif = -1
	motif_counts = [0, 0, 0, 0]

func lateral_delta(ident: int, raw_delta: float, lateral: float, rng: RandomNumberGenerator, festival_easy: bool) -> float:
	var sequence: int = maxi(ident - 1, 0)
	var phrase: int = sequence / LENGTH
	var step: int = sequence % LENGTH
	if phrase != phrase_number:
		phrase_number = phrase
		current_motif = rng.randi_range(0, NAMES.size() - 1)
		# Prevent back-to-back copies of the same pattern.
		if current_motif == last_motif:
			current_motif = (current_motif + 1 + rng.randi_range(0, 2)) % NAMES.size()
		motif_counts[current_motif] += 1
		last_motif = current_motif
	if festival_easy:
		return clampf(raw_delta * 0.28, -lateral * 0.30, lateral * 0.30)
	if step <= 1:
		return clampf(raw_delta * 0.24, -lateral * 0.25, lateral * 0.25)
	var delta := raw_delta
	match current_motif:
		0: # Recovery lane, with a predictable three-hop mini slalom.
			if step in [5, 6, 7]:
				delta = lateral * (0.60 if step % 2 == 1 else -0.60)
		1: # A long bank-to-bank switchback with gentle course corrections.
			if step in [3, 4, 5, 6]:
				delta = lateral * 0.57
			elif step in [9, 10, 11, 12]:
				delta = -lateral * 0.57
		2: # A sequence of alternating small movements, followed by rest.
			if step in [3, 4, 5, 6, 7, 8, 9]:
				delta = lateral * (0.54 if step % 2 == 1 else -0.54)
			elif step in [11, 12]:
				delta *= 0.30
		3: # S-curve: gentle entry, wider turn, then glide to straight.
			if step in [3, 4, 5]:
				delta = lateral * 0.68
			elif step in [7, 8, 9]:
				delta = -lateral * 0.68
			elif step in [11, 12]:
				delta *= 0.35
	return clampf(delta, -lateral, lateral)
