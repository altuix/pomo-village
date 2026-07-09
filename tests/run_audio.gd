extends SceneTree
# NEFES ses motoru smoke (G5): müzik kanalı yüklenir, gain ayarlanır, birkaç frame işler,
# çökme olmaz. Müzik parçaları assets/music/ altından bulunur. Dummy audio driver'la koşar:
#   tools/godot.sh --headless --audio-driver Dummy --script tests/run_audio.gd

var _eng = null
var _n := 0

func _init() -> void:
	var Eng := load("res://scripts/audio_engine.gd")
	_eng = Eng.new()
	get_root().add_child(_eng)   # _ready müzik parçalarını yükler

func _process(_d: float) -> bool:
	_n += 1
	if _n < 3:
		# ses açık: müzik + pad + ambient gain'leri
		_eng.set_gain("music", 0.5)
		_eng.set_gain("pad", 0.25)
		_eng.set_gain("master", 0.7)
		_eng.evening = 0.6
		return false
	var tracks: int = _eng._music_tracks.size()
	var has_player: bool = _eng._music != null
	var gain_ok: bool = absf(_eng.gains.music - 0.5) < 0.001
	# müzik kanalı gain dict'te + tracks bulundu + player kuruldu + set_gain çalışıyor
	var ok: bool = tracks >= 1 and has_player and gain_ok
	print("ses: müzik-parça=%d player=%s gain=%s" % [tracks, str(has_player), str(gain_ok)])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
