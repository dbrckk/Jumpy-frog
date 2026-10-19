extends Node
## Original, offline, license-free procedural soundtrack. Audio is synthesized once,
## cached as mono PCM, and played from a small voice pool (never in the render loop).
const SAMPLE_RATE := 22050
const VOICE_COUNT := 6

var voices: Array[AudioStreamPlayer] = []
var ambience: AudioStreamPlayer
var music: AudioStreamPlayer
var samples: Dictionary = {}
var muted := false
var paused := false
var mobile_safe_mode := false
var haptics_enabled := true
var biome_id := 0
var last_vibration_ms := -100000
var next_voice := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	# Native Android OpenSL ES crashed in the device audio callback.
	# Do not instantiate players, or allocate/play WAV streams on Android
	# while its audio driver is configured as Dummy in project.godot.
	mobile_safe_mode = OS.has_feature("android")
	if mobile_safe_mode:
		muted = true
		return
	rng.seed = 0xC0FFEE
	for event_name in ["jump", "land", "splash", "coin", "friend", "combo", "warning", "lose", "ui", "boost", "victory"]:
		samples[event_name] = _synthesize(event_name)
	for i in range(VOICE_COUNT):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = -13.0
		add_child(player)
		voices.append(player)
	ambience = AudioStreamPlayer.new()
	ambience.bus = "Master"
	ambience.volume_db = -29.0
	ambience.stream = _ambient_loop()
	add_child(ambience)
	ambience.play()
	music = AudioStreamPlayer.new()
	music.bus = "Master"
	music.volume_db = -27.0
	music.stream = _melody_loop()
	add_child(music)
	music.play()

func set_haptics(enabled: bool) -> void:
	haptics_enabled = enabled

func set_biome(index: int) -> void:
	biome_id = clampi(index, 0, 5)
	if music != null:
		music.pitch_scale = [1.0, 1.05, 0.94, 0.87, 1.09, 1.12][biome_id]
	if ambience != null:
		ambience.pitch_scale = [1.0, 1.06, 0.94, 0.84, 1.1, 1.16][biome_id]

func set_muted(value: bool) -> void:
	muted = value or mobile_safe_mode
	for voice in voices:
		voice.volume_db = -80.0 if muted else -13.0
	if ambience != null:
		ambience.volume_db = -80.0 if muted else -29.0
	if music != null:
		music.volume_db = -80.0 if muted else -27.0

func set_paused(value: bool) -> void:
	paused = value
	if ambience != null:
		ambience.stream_paused = value
	if music != null:
		music.stream_paused = value

func play_event(event_name: String, intensity: float = 0.0) -> void:
	if mobile_safe_mode:
		if haptics_enabled and not paused:
			var now := Time.get_ticks_msec()
			if now - last_vibration_ms >= 75:
				last_vibration_ms = now
				match event_name:
					"jump": Input.vibrate_handheld(18)
					"land": Input.vibrate_handheld(25)
					"boost": Input.vibrate_handheld(37)
					"coin": Input.vibrate_handheld(14)
					"friend": Input.vibrate_handheld(46)
					"victory": Input.vibrate_handheld(85)
					"lose", "splash": Input.vibrate_handheld(65)
		return
	if muted or paused or voices.is_empty() or not samples.has(event_name):
		return
	var voice: AudioStreamPlayer = voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stop()
	voice.stream = samples[event_name]
	voice.pitch_scale = clampf(1.0 + rng.randf_range(-0.042, 0.042) + intensity * 0.035, 0.85, 1.22)
	voice.play()

func _synthesize(event_name: String) -> AudioStreamWAV:
	var durations := {
		"jump": 0.24, "land": 0.22, "splash": 0.49, "coin": 0.32,
		"friend": 0.58, "combo": 0.52, "warning": 0.47,
		"lose": 0.65, "ui": 0.12, "boost": 0.26, "victory": 0.9
	}
	var duration: float = durations[event_name]
	var n := int(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var filtered := 0.0
	var phase := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var p := float(i) / maxf(float(n - 1), 1.0)
		var ramp := minf(1.0, t * 110.0)
		var e := ramp * pow(maxf(0.0, 1.0 - p), 1.75)
		var noise: float = rng.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, 0.18)
		var filtered_noise := noise * 0.25 + filtered * 0.75
		var sample_value := 0.0
		var freq := 300.0
		match event_name:
			"jump":
				freq = 275.0 + 570.0 * p * p
				e *= 0.80
				sample_value = sin(phase) * 0.76 + sin(phase * 2.0) * 0.15
			"land":
				freq = 260.0 * pow(0.46, p)
				e *= 0.94
				sample_value = sin(phase) * 0.82 + filtered_noise * 0.23
			"splash":
				freq = 195.0 - 70.0 * p
				e = ramp * pow(1.0 - p, 1.65)
				sample_value = filtered_noise * 0.83 + sin(phase) * 0.21
			"coin":
				freq = 760.0 if p < 0.44 else 1120.0
				e *= 0.78
				sample_value = sin(phase) * 0.78 + sin(phase * 2.02) * 0.10
			"friend":
				freq = 490.0 if p < 0.31 else (620.0 if p < 0.61 else 830.0)
				e *= 0.82
				sample_value = sin(phase) * 0.65 + sin(phase * 2.0) * 0.13 + sin(phase * 3.0) * 0.06
			"combo":
				freq = 520.0 if p < 0.25 else (655.0 if p < 0.5 else (785.0 if p < 0.75 else 1045.0))
				e *= 0.75
				sample_value = sin(phase) * 0.66 + sin(phase * 2.0) * 0.18
			"warning":
				freq = 355.0 + 48.0 * sin(TAU * 4.2 * t)
				e = minf(1.0, t * 14.0) * pow(1.0 - p, 1.2)
				sample_value = sin(phase) * 0.62 + sin(phase * 0.52) * 0.20
			"lose":
				freq = 420.0 * pow(0.27, p)
				e = ramp * pow(1.0 - p, 1.1)
				sample_value = sin(phase) * 0.55 + filtered_noise * (0.28 + p * 0.22)
			"ui":
				freq = 600.0 * pow(1.20, p)
				e *= 0.37
				sample_value = sin(phase)
			"boost":
				freq = 260.0 + 750.0 * pow(p, 0.75)
				e *= 0.67
				sample_value = sin(phase) * 0.72 + sin(phase * 1.5) * 0.15
			"victory":
				freq = 440.0 if p < 0.28 else (554.37 if p < 0.52 else (659.25 if p < 0.77 else 880.0))
				e = ramp * pow(1.0 - p, 0.95)
				sample_value = sin(phase) * 0.58 + sin(phase * 2.0) * 0.12
		phase += TAU * freq / SAMPLE_RATE
		var value := int(clampf(sample_value * e * 10500.0, -32767.0, 32767.0))
		if value < 0:
			value += 65536
		bytes[i * 2] = value & 255
		bytes[i * 2 + 1] = (value >> 8) & 255
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = SAMPLE_RATE
	result.stereo = false
	result.data = bytes
	return result

func _ambient_loop() -> AudioStreamWAV:
	# Frequencies are integer multiples of 1/4 Hz, so the four-second loop
	# repeats with no discontinuous edge, including its slow shoreline swell.
	var seconds := 4
	var n: int = SAMPLE_RATE * seconds
	var raw := PackedByteArray()
	raw.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var swell := 0.50 + 0.35 * sin(TAU * 0.25 * t - 0.8)
		var babble := (sin(TAU * 5.0 * t + 0.8) +
				0.42 * sin(TAU * 10.25 * t) +
				0.22 * sin(TAU * 17.0 * t + 0.7))
		var breeze := (sin(TAU * 0.75 * t) * sin(TAU * 42.0 * t) +
				0.3 * sin(TAU * 61.25 * t)) * 0.32
		var chirp := sin(TAU * 880.0 * t + 0.16 * sin(TAU * 1.0 * t))
		var bird_gate := pow(maxf(0.0, sin(TAU * 0.5 * t)), 16.0)
		var sample := (babble * 0.16 * swell + breeze * 0.10 +
				chirp * bird_gate * 0.025)
		var value := int(clampf(sample * 14000.0, -32767.0, 32767.0))
		if value < 0:
			value += 65536
		raw[i * 2] = value & 255
		raw[i * 2 + 1] = (value >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = n
	stream.data = raw
	return stream

func _melody_loop() -> AudioStreamWAV:
	# Original quietly plucked pentatonic theme, rendered once as an eight-second loop.
	var scale_notes := [261.63, 293.66, 329.63, 392.0, 440.0, 523.25]
	var phrase := [0, 2, 3, 5, 4, 2, 1, 3, 4, 3, 2, 0, 2, 1, 3, 0]
	var count := SAMPLE_RATE * 8
	var raw := PackedByteArray()
	raw.resize(count * 2)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var beat := int(floor(t * 2.0))
		var note_t := fposmod(t, 0.5)
		var freq: float = scale_notes[phrase[beat % phrase.size()]]
		var envelope := (1.0 - exp(-note_t * 110.0)) * exp(-note_t * 9.0)
		var pluck := sin(TAU * freq * note_t) + sin(TAU * freq * 2.0 * note_t) * 0.20
		var bass := sin(TAU * freq * 0.5 * t) * 0.12 * (0.5 + 0.5 * cos(TAU * t * 0.25))
		var sample := (pluck * envelope * 0.23 + bass * 0.17) * minf(1.0, t * 3.0)
		var value := int(clampf(sample * 13500.0, -32767.0, 32767.0))
		if value < 0:
			value += 65536
		raw[i * 2] = value & 255
		raw[i * 2 + 1] = (value >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	stream.data = raw
	return stream
