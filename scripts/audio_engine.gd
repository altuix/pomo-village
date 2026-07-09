extends Node
## NEFES ses motoru v2 — LOFI REVİZYONU (playtest: "sesler çok kötü" → ses-tasarım reçetesi).
## %100 SENTEZ (telif yok). Sim'e DOKUNMAZ; gürültü iç LCG (randf DEĞİL).
## v2 mimarisi:
##  · Pad: Rhodes-vari (temel + 2f + kısa 6f "tine" partial'ı) + one-pole lowpass (sıcaklık)
##    + PENTATONİK-UYUMLU AKOR rotasyonu (C6/9, Am7, Dsus2, Em-add; 61.3s ortak-katsız).
##  · Vinyl yüzeyi: seyrek crackle + hafif hiss (pad açıkken) — lofi kimliği.
##  · Tape wobble: global pitch drift (wow+flutter) — hiçbir tekrar birebir aynı duyulmaz.
##  · Ucuz reverb: 3 lowpass-feedback comb (yalnız pad+olay send'i) — kuru "bip" bitti.
##  · GAIN DRIFT (playtest isteği): kanal başına ortak-katsız yavaş ±%25 dalgalanma —
##    loop hissi kırılır. Blok hızında (CPU ihmal).
##  · Olay sesleri: oktav aşağı + smoothstep atak + alt-oktav destek + LP — "telefon bipi" bitti.
##  · CC0 AMBIENT YUVASI: assets/ambient/rain.ogg | stream.ogg varsa sentez yerine loop çalar
##    (kullanıcı onayıyla; kaynak+lisans ASSETS.md'ye yazılmalı). Yoksa sentez fallback.

const RATE := 22050.0
const PAD_PERIODS := [19.7, 26.3, 33.1, 43.7, 53.9, 71.3]  # ortak-katsız döngüler; son = kök drone
const ROOT_FREQ := 65.4                                     # C2 kök
const CHORD_PERIOD := 61.3                                  # akor rotasyonu (ortak-katsız)
# pentatonik-uyumlu lofi akorları (Hz): C6/9, Am7, Dsus2, Em(add) — her nota C-pentatonikle konsonant
const CHORDS := [
	[130.8, 164.8, 196.0, 293.7],
	[110.0, 130.8, 164.8, 196.0],
	[146.8, 196.0, 220.0, 293.7],
	[164.8, 196.0, 220.0, 329.6],
]
const CHIME_PERIOD := 27.7
# kanal-başına drift periyotları (ortak-katsız — asla hizalanmaz; playtest "loop hissi" isteği)
const DRIFT_PERIODS := { "rain": 23.3, "stream": 31.7, "pad": 41.9, "cricket": 17.1 }

var gains := { "rain": 0.0, "stream": 0.0, "pad": 0.0, "cricket": 0.0, "music": 0.0, "master": 0.7 }
var evening := 0.0
var weather_rain := 0.0
var focus_active := false

var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback = null
var _rng := 0x1234abcd
var _t := 0.0
# pad durumu (blok-hızında hesaplanan katman parametreleri)
var _pad_ph := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _pad_ph2 := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _pad_ph6 := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _pad_cyc := [-1, -1, -1, -1, -1, -1]
var _pad_freq := [130.8, 164.8, 196.0, 220.0, 261.6, 65.4]
var _pad_rest := [false, false, false, false, false, false]   # olasılıksal sus (%25 — doku nefes alır)
var _pad_lp := 0.0
var _chime_cycle := -1
# vinyl + tape
var _crackle := 0.0
var _hiss_lp := 0.0
# reverb: 3 lowpass-feedback comb (asal uzunluklar — metalik rezonans çakışmasın)
var _cb1 := PackedFloat32Array()
var _cb2 := PackedFloat32Array()
var _cb3 := PackedFloat32Array()
var _ci1 := 0
var _ci2 := 0
var _ci3 := 0
var _clp1 := 0.0
var _clp2 := 0.0
var _clp3 := 0.0
# drift (blok hızında güncellenir)
var _drift := { "rain": 1.0, "stream": 1.0, "pad": 1.0, "cricket": 1.0 }
# diğer kanallar
var _lp := 0.0
var _lp2 := 0.0
var _cr_timer := 0.0
var _cr_env := 0.0
var _cr_ph := 0.0
var _ev_lp := 0.0
var _voices: Array = []
# CC0 ambient yuvası (dosya varsa sentez yerine)
var _amb := {}   # kanal -> AudioStreamPlayer
# CC0 lofi müzik kanalı (G5): assets/music/ altındaki parçalar sırayla; arada sessiz nefes
var _music: AudioStreamPlayer = null
var _music_tracks: Array = []
var _music_i := -1
var _music_gap_until := 6.0     # ilk parça birkaç sn sonra başlar (açılışta sessizlik)

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.15
	_player.stream = gen
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback()
	_cb1.resize(1687); _cb2.resize(1861); _cb3.resize(2053)
	# CC0 ambient loop yuvası: dosyayı assets/ambient/ altına bırak, otomatik devreye girer
	for ch in ["rain", "stream"]:
		var pth := "res://assets/ambient/%s.ogg" % ch
		if ResourceLoader.exists(pth):
			var p := AudioStreamPlayer.new()
			p.stream = load(pth)
			if p.stream is AudioStreamOggVorbis:
				(p.stream as AudioStreamOggVorbis).loop = true
			p.volume_db = -80.0
			add_child(p)
			p.play()
			_amb[ch] = p
	# CC0 lofi müzik: assets/music/ altındaki tüm .ogg/.mp3'leri yükle (sıralı çalınır)
	var mdir := DirAccess.open("res://assets/music")
	if mdir != null:
		var names := mdir.get_files()
		names.sort()   # 01_.. 02_.. deterministik sıra
		for fn in names:
			if fn.ends_with(".ogg") or fn.ends_with(".mp3"):
				var st := load("res://assets/music/" + fn)
				if st != null:
					_music_tracks.append(st)
	if not _music_tracks.is_empty():
		_music = AudioStreamPlayer.new()
		_music.volume_db = -80.0
		add_child(_music)
		_music.finished.connect(_on_music_finished)

func _on_music_finished() -> void:
	# parça bitti → 20-40sn sessiz nefes, sonra sıradaki (loop hissi kırılır — playtest)
	_music_gap_until = _t + 20.0 + 20.0 * Rng.hf(_music_i * 131 + 7)

func _noise() -> float:
	_rng = (_rng * 1103515245 + 12345) & 0x7fffffff
	return float(_rng) / float(0x40000000) - 1.0

func _tri(ph: float) -> float:
	return 4.0 * absf(ph - 0.5) - 1.0

## Yavaş value-noise drift: her periyotta hash hedefi, smoothstep yaklaşma (blok hızında çağrılır)
func _drift_val(ch: String, per: float) -> float:
	var cyc := int(_t / per)
	var t0 := 0.75 + 0.5 * Rng.hf(cyc * 131 + ch.hash() % 997)
	var t1 := 0.75 + 0.5 * Rng.hf((cyc + 1) * 131 + ch.hash() % 997)
	var u := fmod(_t, per) / per
	u = u * u * (3.0 - 2.0 * u)
	return lerpf(t0, t1, u)

func _process(_d: float) -> void:
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	var dt := 1.0 / RATE
	# --- BLOK HIZI: drift + wobble + pad katman parametreleri (örnek başına DEĞİL — CPU) ---
	for ch in DRIFT_PERIODS.keys():
		_drift[ch] = _drift_val(ch, DRIFT_PERIODS[ch])
	var wobble := 1.0 + 0.003 * sin(_t * 0.7 * TAU) + 0.0012 * sin(_t * 6.3 * TAU)
	var chord: Array = CHORDS[Rng.h(int(_t / CHORD_PERIOD) * 37) % CHORDS.size()]
	var pad_gain: float = gains.pad * _drift.pad * (0.8 + 0.3 * evening)
	var rain_gain: float = maxf(gains.rain, weather_rain * 0.35) * _drift.rain
	var stream_gain: float = gains.stream * _drift.stream
	var cricket_gain: float = gains.cricket * evening * _drift.cricket
	# CC0 ambient dosyası varsa o kanalın sentezi kapanır, loop sesi drift'li sürülür
	if _amb.has("rain"):
		_amb.rain.volume_db = linear_to_db(clampf(rain_gain * gains.master, 0.0001, 1.0))
		rain_gain = 0.0
	if _amb.has("stream"):
		_amb.stream.volume_db = linear_to_db(clampf(stream_gain * gains.master, 0.0001, 1.0))
		stream_gain = 0.0
	# CC0 LOFI MÜZİK (G5): sıradaki parça sessiz nefesten sonra başlar; müzik çalarken pad kısılır
	var music_on := false
	if _music != null:
		if gains.music > 0.001:
			if not _music.playing and _t >= _music_gap_until:
				_music_i = (_music_i + 1) % _music_tracks.size()
				_music.stream = _music_tracks[_music_i]
				_music.play()
			if _music.playing:
				music_on = true
				# gain drift'i müziğe de uygulanır (ortak-katsız pad periyodu — hafif nefes)
				var mg: float = gains.music * gains.master * (0.9 + 0.1 * _drift.pad)
				_music.volume_db = linear_to_db(clampf(mg, 0.0001, 1.0))
		elif _music.playing:
			_music.stop()
	if music_on:
		pad_gain *= 0.3   # ducking: müzik varken sentez pad geri çekilir (çamurlaşmasın)
	# katman parametreleri: env/amp'ler blok başına (yavaş değişirler)
	var lay_amp := []
	var lay_a2 := []
	var lay_a6 := []
	for k in range(6):
		var per: float = PAD_PERIODS[k]
		var cyc := int(_t / per)
		if cyc != _pad_cyc[k]:
			_pad_cyc[k] = cyc
			_pad_rest[k] = (k < 5) and Rng.hf(cyc * 53 + k * 17) < 0.25   # kök hariç %25 sus
			_pad_freq[k] = ROOT_FREQ if k == 5 else chord[Rng.h(cyc * 7 + k * 131) % chord.size()] * (2.0 if k == 4 else 1.0)
		var tk := fmod(_t, per) / per
		var age := tk * per
		var env := sin(tk * PI)
		if _pad_rest[k] or (k == 4 and not focus_active):
			env = 0.0
		lay_amp.append(env * (0.6 if k == 5 else 1.0))
		lay_a2.append(0.35 * exp(-age * 0.6))    # 2f gövde partial'ı (yavaş söner)
		lay_a6.append(0.12 * exp(-age * 3.0))    # 6f "tine" ping'i (döngü başında parlar)
	# kule arası serpinti
	var ccyc := int(_t / CHIME_PERIOD)
	if ccyc != _chime_cycle:
		_chime_cycle = ccyc
		if gains.pad > 0.02 and Rng.hf(ccyc * 17) < 0.55:
			_tone(Melody.SCALE[Rng.h(ccyc * 31) % Melody.SCALE.size()], 1.4, 0.03, "sine")
	# SESSİZLİK ATLAMASI (perf): duyulur kanal yoksa sıfır bas, hesap yapma
	var audible: bool = gains.master > 0.001 and (rain_gain > 0.001 or stream_gain > 0.001 \
		or pad_gain > 0.001 or cricket_gain > 0.001 or not _voices.is_empty())
	if not audible:
		for i in range(n):
			_pb.push_frame(Vector2.ZERO)
		_t += n * dt
		return
	var k_lp := 0.203   # pad one-pole (fc≈800Hz — lofi sıcaklığı)
	var k_ev := 0.51    # olay LP (fc≈2500Hz)
	for i in range(n):
		var s := 0.0
		var nz := _noise()
		# 🌧 yağmur (sentez fallback)
		if rain_gain > 0.001:
			_lp += (nz - _lp) * 0.08
			s += _lp * rain_gain * 0.5
		# 💧 dere
		if stream_gain > 0.001:
			_lp2 += (nz - _lp2) * 0.02
			s += (_lp - _lp2) * stream_gain * 0.6 * (0.5 + 0.5 * sin(_t * 0.3 * TAU))
		# 🎹 Rhodes-vari akorlu pad (partial'lar + LP)
		var pad := 0.0
		if pad_gain > 0.001:
			for k in range(6):
				var a: float = lay_amp[k]
				if a <= 0.001:
					continue
				var f: float = _pad_freq[k] * wobble
				_pad_ph[k] = fmod(_pad_ph[k] + f * dt, 1.0)
				_pad_ph2[k] = fmod(_pad_ph2[k] + f * 2.0 * dt, 1.0)
				var v: float = sin(_pad_ph[k] * TAU) + lay_a2[k] * sin(_pad_ph2[k] * TAU)
				if lay_a6[k] > 0.01:
					_pad_ph6[k] = fmod(_pad_ph6[k] + f * 6.0 * dt, 1.0)
					v += lay_a6[k] * sin(_pad_ph6[k] * TAU)
				pad += v * a
			_pad_lp += (pad - _pad_lp) * k_lp
			s += _pad_lp * 0.06 * pad_gain
			# vinyl yüzeyi: crackle + hiss (yalnız pad açıkken — lofi kimliği)
			if _noise() > 0.9993:
				_crackle = 0.15 * signf(_noise())
			_crackle *= 0.86
			_hiss_lp += (nz - _hiss_lp) * 0.3
			s += (_crackle + _hiss_lp * 0.004) * pad_gain
		# 🦗 gece cırcırı (yumuşatılmış: 3800Hz + vibrato)
		if cricket_gain > 0.001:
			_cr_timer -= dt
			if _cr_timer <= 0.0:
				if _noise() > 0.0:
					_cr_env = 1.0
					_cr_ph = 0.0
				_cr_timer = 0.3 + (_noise() + 1.0) * 0.3
			if _cr_env > 0.0:
				_cr_ph += (3800.0 + 60.0 * sin(_t * 30.0)) * dt
				s += sin(_cr_ph * TAU) * _cr_env * 0.03 * cricket_gain
				_cr_env -= dt * 7.0
		# olay sesleri (LP'den geçer — "bip" sertliği gider)
		var ev_raw := _mix_voices(dt)
		_ev_lp += (ev_raw - _ev_lp) * k_ev
		# ucuz reverb: pad+olay send → 3 comb (kuru miks bitti)
		var send := _pad_lp * 0.04 * pad_gain + _ev_lp * 0.8
		var c1 := _cb1[_ci1]; _clp1 += (c1 - _clp1) * 0.4; _cb1[_ci1] = send + _clp1 * 0.42; _ci1 = (_ci1 + 1) % 1687
		var c2 := _cb2[_ci2]; _clp2 += (c2 - _clp2) * 0.4; _cb2[_ci2] = send + _clp2 * 0.42; _ci2 = (_ci2 + 1) % 1861
		var c3 := _cb3[_ci3]; _clp3 += (c3 - _clp3) * 0.4; _cb3[_ci3] = send + _clp3 * 0.42; _ci3 = (_ci3 + 1) % 2053
		s += _ev_lp + (c1 + c2 + c3) * 0.083   # wet ≈ 0.25/3
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
		# smoothstep atak (12ms — lineer rampın tık'ı gitti) + exp decay
		var env := 0.0
		if v.age < 0.012:
			var u: float = v.age / 0.012
			env = u * u * (3.0 - 2.0 * u)
		else:
			env = exp(-(v.age - 0.012) * 5.0 / v.dur)
		v.phase += v.freq * dt
		var w: float = _tri(fmod(v.phase, 1.0)) if v.type == "triangle" else sin(v.phase * TAU)
		w += 0.3 * sin(fmod(v.phase * 0.5, 1.0) * TAU)   # alt-oktav destek: gövde/sıcaklık
		out += w * env * v.vol
		keep.append(v)
	_voices = keep
	return out

# ---- genel arayüz (değişmedi) ----
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
			_tone(900.0, 0.08, 0.03, "sine")     # 1800'dü — oktav aşağı (bip sertliği)
		"letter":
			_tone(1300.0, 0.12, 0.04, "sine")    # 2600'dü
		"breakEnd":
			_tone(659.0, 0.5, 0.07, "sine")
			_tone(523.0, 0.7, 0.06, "sine", 0.18)
		"camera":
			_tone(1200.0, 0.04, 0.05, "sine")
			_tone(900.0, 0.05, 0.05, "sine", 0.06)
		"festival":
			_tone(523.0, 0.4, 0.07, "triangle")
			_tone(659.0, 0.4, 0.07, "triangle", 0.12)
			_tone(784.0, 0.6, 0.08, "triangle", 0.24)
		"towerChime":
			_tone(392.0, 1.4, 0.05, "sine")
			_tone(784.0, 1.0, 0.02, "sine", 0.02)
		"build":
			_tone(196.0, 0.12, 0.07, "triangle")
			_tone(261.6, 0.18, 0.06, "triangle", 0.09)
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
