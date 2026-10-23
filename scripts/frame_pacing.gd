extends RefCounted
## Android target refresh rates. This is only a rendering cap; game physics
## continues to use real frame delta and the race timer is not quantized.
## Desktop/headless capture paths deliberately retain their existing cadence.
const ACTIVE_FPS := 60
const MENU_FPS := 30
const PAUSED_FPS := 24

static func target_fps(mode: int) -> int:
	match mode:
		1, 2, 3: # PLAY, AIM, FLY
			return ACTIVE_FPS
		5, 10: # PAUSED, DIAGNOSTICS
			return PAUSED_FPS
		_: # TITLE, LOST, CLEAR, WARDROBE, GOALS, CHAPTERS
			return MENU_FPS
