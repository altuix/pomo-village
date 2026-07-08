extends Node
## NEFES ses motoru — %100 SENTEZ (telif yok), runtime AudioStreamGenerator (HTML WebAudio portu).
## 4 ambient kanal (yağmur/dere/pad/cırcır) slider'lı + olay sesleri (odak/seri/lamba/mektup/veda/doğum).
## Sim'e DOKUNMAZ (yan çıktı). Gürültü için iç LCG (randf DEĞİL) — determinizmi etkilemez.

const RATE := 22050.0
const PAD_F := [130.8, 164.8, 196.0, 246.9]   # detune akor (Do-Mi-Sol-Si)

var gains := { "rain": 0.0, "stream": 0.0, "pad": 0.0, "cricket": 0.0, "master": 0.7 }
var evening := 0.0                              # cırcır × evening (geceyle nefes alır)

var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback = null
var _rng := 0x1234abcd
var _t := 0.0
var _pad_ph := [0.0, 0.0, 0.0, 0.0]
var _lp := 0.0
var _lp2 := 0.0
var _cr_timer := 0.0
var _cr_env := 0.0
var _cr_ph := 0.0
var _voices: Array = []                          # {freq, phase, age, dur, vol, type, delay}

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.15
	_player.stream = gen
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback()

func _noise() -> float:
	_rng = (_rng * 1103515245 + 12345) & 0x7fffffff
	return float(_rng) / float(0x40000000) - 1.0

func _tri(ph: float) -> float:
	return 4.0 * absf(ph - 0.5) - 1.0

func _process(_d: float) -> void:
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	var dt := 1.0 / RATE
	for i in range(n):
		var s := 0.0
		var nz := _noise()
		# 🌧 yağmur: alçak-geçiren gürültü
		_lp += (nz - _lp) * 0.08
		s += _lp * gains.rain * 0.5
		# 💧 dere: bantgeçiren (fark) + yavaş LFO fokurtu
		_lp2 += (nz - _lp2) * 0.02
		var lfo := 0.5 + 0.5 * sin(_t * 0.3 * TAU)
		s += (_lp - _lp2) * gains.stream * 0.6 * lfo
		# 🎹 lo-fi pad: detune üçgen akor + tremolo
		var trem := 0.85 + 0.15 * sin(_t * 0.11 * TAU)
		var pad := 0.0
		for k in range(4):
			_pad_ph[k] += PAD_F[k] * dt
			if _pad_ph[k] > 1.0:
				_pad_ph[k] -= 1.0
			pad += _tri(_pad_ph[k])
		s += pad * 0.05 * gains.pad * trem
		# 🦗 gece cırcırı: seyrek blip × evening
		var cg: float = gains.cricket * evening
		_cr_timer -= dt
		if _cr_timer <= 0.0:
			if cg > 0.02 and _noise() > 0.0:
				_cr_env = 1.0
				_cr_ph = 0.0
			_cr_timer = 0.3 + (_noise() + 1.0) * 0.3
		if _cr_env > 0.0:
			_cr_ph += 4400.0 * dt
			s += sin(_cr_ph * TAU) * _cr_env * 0.03 * cg
			_cr_env -= dt * 7.0
		# olay sesleri
		s += _mix_voices(dt)
		s = clampf(s * gains.master, -1.0, 1.0)
		_pb.push_frame(Vector2(s, s))
		_t += dt

func _mix_voices(dt: float) -> float:
	var out := 0.0
	var keep: Array = []
	for v in _voices:
		if v.delay > 0.0:
			v.delay -= dt
			keep.append(v)
			continue
		v.age += dt
		if v.age > v.dur + 0.05:
			continue
		var env := 0.0
		if v.age < 0.02:
			env = v.age / 0.02
		else:
			env = exp(-(v.age - 0.02) * 5.0 / v.dur)
		v.phase += v.freq * dt
		var w: float = _tri(fmod(v.phase, 1.0)) if v.type == "triangle" else sin(v.phase * TAU)
		out += w * env * v.vol
		keep.append(v)
	_voices = keep
	return out

# ---- genel arayüz ----
func set_gain(ch: String, val: float) -> void:
	if gains.has(ch):
		gains[ch] = clampf(val, 0.0, 1.0)

func _tone(freq: float, dur: float, vol: float, type: String = "sine", delay: float = 0.0) -> void:
	if _voices.size() > 48:
		return
	_voices.append({ "freq": freq, "phase": 0.0, "age": 0.0, "dur": dur, "vol": vol, "type": type, "delay": delay })

func event(kind: String) -> void:
	match kind:
		"focusDone":
			var fs := [523.0, 659.0, 784.0, 1046.0]
			for i in range(fs.size()):
				_tone(fs[i], 0.9, 0.10, "sine", i * 0.14)
		"unlock":
			var fu := [392.0, 523.0, 659.0, 784.0, 1046.0]
			for i in range(fu.size()):
				_tone(fu[i], 1.0, 0.09, "triangle", i * 0.11)
		"lamp":
			_tone(1800.0, 0.06, 0.03, "sine")
		"letter":
			_tone(2600.0, 0.10, 0.04, "sine")
		"breakEnd":   # mola bitti: nazik iki-nota iniş (davet, alarm değil — cozy)
			_tone(659.0, 0.5, 0.07, "sine")
			_tone(523.0, 0.7, 0.06, "sine", 0.18)
		"farewell":
			_tone(392.0, 1.6, 0.07, "sine")
			_tone(494.0, 1.6, 0.05, "sine", 0.05)
		"birth":
			_tone(659.0, 0.35, 0.08, "triangle")
			_tone(880.0, 0.5, 0.08, "triangle", 0.12)

func play_tone(note: int) -> void:
	if note >= 0 and note < Melody.SCALE.size():
		_tone(Melody.SCALE[note], 0.25, 0.10, "triangle")

func play_melody(mel: Array) -> void:
	for i in range(mel.size()):
		var n: int = mel[i]
		if n >= 0 and n < Melody.SCALE.size():
			_tone(Melody.SCALE[n], 0.32, 0.09, "triangle", i * 0.22)
