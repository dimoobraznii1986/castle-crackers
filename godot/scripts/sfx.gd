class_name Sfx
extends Node
## Sound effects made with code (no sound files needed).
## Later you can replace any sound with a real .wav or .ogg file.

const RATE := 22050

var streams := {}
var players: Array[AudioStreamPlayer] = []
var muted := false
var _last := {}


func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	streams["boom_big"] = _wav(_mix([_noise(1.3, 900.0, 50.0, 0.9), _tone(100.0, 28.0, 0.9, 0.8, "sine")]))
	streams["boom"] = _wav(_mix([_noise(0.8, 1000.0, 60.0, 0.75), _tone(120.0, 30.0, 0.55, 0.7, "sine")]))
	streams["boom_small"] = _wav(_mix([_noise(0.45, 1400.0, 90.0, 0.55), _tone(160.0, 50.0, 0.3, 0.45, "sine")]))
	streams["shoot"] = _wav(_mix([_noise(0.25, 2400.0, 200.0, 0.5), _tone(170.0, 45.0, 0.2, 0.5, "square")]))
	streams["bounce"] = _wav(_tone(320.0, 200.0, 0.09, 0.3, "triangle"))
	streams["clang"] = _wav(_mix([_tone(900.0, 620.0, 0.13, 0.3, "triangle"), _tone(1350.0, 900.0, 0.1, 0.12, "square")]))
	streams["chest"] = _wav(_mix(_seq([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.07, 0.16, 0.3, "triangle")))
	streams["secret"] = _wav(_mix(_seq([392.0, 523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0], 0.09, 0.2, 0.25, "square")))
	streams["splash"] = _wav(_noise(0.5, 2500.0, 300.0, 0.45, true))
	streams["click"] = _wav(_tone(700.0, 700.0, 0.04, 0.15, "square"))
	streams["build"] = _wav(_mix([_tone(220.0, 120.0, 0.1, 0.35, "square"), _delay(_tone(260.0, 140.0, 0.1, 0.3, "square"), 0.12)]))
	streams["drill"] = _wav(_noise(0.08, 3500.0, 1800.0, 0.2, true))
	streams["march"] = _wav(_mix(_seq([160.0, 160.0, 160.0, 160.0], 0.16, 0.06, 0.25, "square")))
	streams["turn"] = _wav(_mix([_tone(660.0, 660.0, 0.08, 0.2, "triangle"), _delay(_tone(990.0, 990.0, 0.12, 0.2, "triangle"), 0.09)]))
	streams["win"] = _wav(_mix(_seq([523.0, 523.0, 523.0, 659.0, 784.0, 659.0, 784.0, 1047.0], 0.15, 0.25, 0.3, "square")))
	streams["error"] = _wav(_tone(180.0, 140.0, 0.15, 0.25, "square"))
	streams["swoosh"] = _wav(_noise(0.14, 5000.0, 2200.0, 0.22, true))
	streams["rip"] = _wav(_mix([_noise(0.3, 4200.0, 900.0, 0.4, true), _tone(500.0, 200.0, 0.25, 0.15, "square")]))
	streams["thud"] = _wav(_mix([_noise(0.18, 600.0, 80.0, 0.5), _tone(110.0, 50.0, 0.15, 0.5, "sine")]))
	streams["sword"] = _wav(_mix([_noise(0.08, 6000.0, 3000.0, 0.25, true), _delay(_tone(1500.0, 1100.0, 0.16, 0.25, "triangle"), 0.05)]))
	streams["upgrade"] = _wav(_mix(_seq([392.0, 494.0, 587.0, 784.0, 988.0], 0.06, 0.18, 0.25, "triangle")))


func play(name: String, min_gap := 0.0, volume_db := 0.0) -> void:
	if muted or not streams.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if min_gap > 0.0 and now - float(_last.get(name, -10.0)) < min_gap:
		return
	_last[name] = now
	var player: AudioStreamPlayer = players[0]
	for p in players:
		if not p.playing:
			player = p
			break
	player.stream = streams[name]
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.93, 1.07)
	player.play()


# ---------------------------------------------------------------- synth helpers
func _env(t: float, dur: float) -> float:
	var attack := minf(1.0, t / 0.005)
	return attack * pow(0.001, t / dur)


func _noise(dur: float, f0: float, f1: float, vol: float, high := false) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := f0 * pow(f1 / f0, t / dur)
		var a := 1.0 - exp(-TAU * f / RATE)
		var x := randf() * 2.0 - 1.0
		lp += a * (x - lp)
		var s := (x - lp) if high else lp
		out[i] = s * vol * _env(t, dur) * (1.0 if high else 1.6)
	return out


func _tone(f0: float, f1: float, dur: float, vol: float, wave: String) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := f0 * pow(f1 / f0, t / dur)
		phase = fmod(phase + f / RATE, 1.0)
		var s: float
		match wave:
			"square":
				s = 1.0 if phase < 0.5 else -1.0
				s *= 0.5
			"triangle":
				s = 4.0 * absf(phase - 0.5) - 1.0
			_:
				s = sin(phase * TAU)
		out[i] = s * vol * _env(t, dur)
	return out


func _delay(a: PackedFloat32Array, sec: float) -> PackedFloat32Array:
	var pad := PackedFloat32Array()
	pad.resize(int(sec * RATE))
	pad.append_array(a)
	return pad


func _seq(freqs: Array, step: float, dur: float, vol: float, wave: String) -> Array:
	var parts := []
	for i in freqs.size():
		parts.append(_delay(_tone(freqs[i], freqs[i], dur, vol, wave), i * step))
	return parts


func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p in parts:
		for i in p.size():
			out[i] += p[i]
	return out


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
