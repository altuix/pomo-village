class_name Settings
extends RefCounted
## Kullanıcı ayarları (user://settings.cfg) — save.json'dan AYRI: kasaba durumu değil cihaz tercihi.
## B+ denetim #21: slider'lar kalıcı; ilk açılış default'ları sıfır değil (keşfedilebilirlik —
## oyun sessiz açılınca ses motoru hiç fark edilmiyordu).

const PATH := "user://settings.cfg"
const AUDIO_DEFAULTS := { "rain": 0.0, "stream": 0.20, "pad": 0.25, "cricket": 0.20, "master": 0.7 }

static func load_audio() -> Dictionary:
	var cfg := ConfigFile.new()
	var out := AUDIO_DEFAULTS.duplicate()
	if cfg.load(PATH) == OK:
		for k in out.keys():
			out[k] = clampf(float(cfg.get_value("audio", k, out[k])), 0.0, 1.0)
	return out

static func save_audio(gains: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # mevcut/gelecek diğer bölümler korunur (dosya yoksa boştan başlar)
	for k in gains.keys():
		cfg.set_value("audio", k, gains[k])
	if cfg.save(PATH) != OK:
		push_warning("[settings] settings.cfg yazılamadı")
