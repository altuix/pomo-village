extends Node
## NEFES ses motoru — %100 SENTEZ (telif yok), runtime AudioStreamGenerator (HTML WebAudio portu).
## 4 ambient kanal (yağmur/dere/pad/cırcır) slider'lı + olay sesleri (odak/seri/lamba/mektup/veda/doğum).
## Sim'e DOKUNMAZ (yan çıktı). Gürültü için iç LCG (randf DEĞİL) — determinizmi etkilemez.

const RATE := 22050.0
# Generative pad (Eno 'Music for Airports' modeli): her ses ortak-katsız döngüsünde TEK
# pentatonik nota çalar → katmanlar asla aynı hizaya gelmez, uzun süre tekrarsız cozy ambient.
const PAD_SCALE := [130.8, 146.8, 164.8, 196.0, 220.0]   # pentatonik alt oktav (C-D-E-G-A)
const PAD_PERIODS := [19.7, 26.3, 33.1, 43.7, 53.9]      # ortak-katsız süreler (sn)
const CHIME_PERIOD := 27.7                                # kule arası serpinti döngüsü

var gains := { "rain": 0.0, "stream": 0.0, "pad": 0.0, "cricket": 0.0, "master": 0.7 }
var evening := 0.0                              # cırcır × evening (geceyle nefes alır)
var focus_active := false                       # odak seansında 5. pad katmanı (üst oktav) açılır

var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback = null
var _rng := 0x1234abcd
var _t := 0.0
var _pad_ph := [0.0, 0.0, 0.0, 0.0, 0.0]
var _pad_cyc := [-1, -1, -1, -1, -1]
var _pad_freq := [130.8, 164.8, 196.0, 220.0, 261.6]
var _chime_cycle := -1
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
	# SESSİZLİK ATLAMASI (perf: always-on uygulamada boşa sinüs hesaplama — nişin 1 no'lu şikâyeti CPU):
	# hiçbir kanal duyulmuyorken buffer sıfırla doldurulur; _t akmaya devam eder (döngüler tutarlı).
	var audible: bool = gains.master > 0.001 and (gains.rain > 0.001 or gains.stream > 0.001 \
		or gains.pad > 0.001 or gains.cricket * evening > 0.001 or not _voices.is_empty())
	if not audible:
		for i in range(n):
			_pb.push_frame(Vector2.ZERO)
		_t += n * dt
		return
	# 🗼 kule arası serpinti: ~28sn'de bir tek kısık pentatonik nota (determinist Rng — sim'e dokunmaz)
	var ccyc := int(_t / CHIME_PERIOD)
	if ccyc != _chime_cycle:
		_chime_cycle = ccyc
		if gains.pad > 0.02 and Rng.hf(ccyc * 17) < 0.55:
			_tone(Melody.SCALE[Rng.h(ccyc * 31) % Melody.SCALE.size()], 1.4, 0.03, "sine")
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
		# 🎹 generative pad: ses başına döngü zarfı sin(π·t) — sınırda 0 → nota değişimi tıksız;
		# nota seçimi döngü sayısından Rng.h (frekans yalnız döngü değişince hesaplanır — CPU)
		var pad := 0.0
		var nv := 5 if focus_active else 4   # odak: üst-oktav 5. katman (vertical layering)
		for k in range(nv):
			var per: float = PAD_PERIODS[k]
			var cyc := int(_t / per)
			if cyc != _pad_cyc[k]:
				_pad_cyc[k] = cyc
				_pad_freq[k] = PAD_SCALE[Rng.h(cyc * 7 + k * 131) % PAD_SCALE.size()] * (2.0 if k == 4 else 1.0)
			var env := sin(fmod(_t, per) / per * PI)
			_pad_ph[k] += _pad_freq[k] * dt
			if _pad_ph[k] > 1.0:
				_pad_ph[k] -= 1.0
			pad += _tri(_pad_ph[k]) * env
		s += pad * 0.055 * gains.pad * (0.8 + 0.3 * evening)   # akşam pad hafif dolgunlaşır
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
		"camera":   # kartpostal deklanşörü: çift minik tık
			_tone(1200.0, 0.04, 0.05, "sine")
			_tone(900.0, 0.05, 0.05, "sine", 0.06)
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
