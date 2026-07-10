class_name SteamBridge
extends RefCounted
## Steam köprüsü (H3 — Faz F): GÜVENLİ-YOKLUK ilkesi. GodotSteam GDExtension kuruluysa ve
## Steam açıksa başlatır; değilse HER çağrı sessiz no-op — oyun Steam'siz birebir aynı çalışır
## (testler/headless etkilenmez). Gerçek App ID gelince steam_appid.txt güncellenir (şimdilik
## 480 = Spacewar test ID). Achievement kimlikleri docs/ACHIEVEMENTS.md ile birebir.

static var _steam: Object = null
static var _ready := false

static func boot() -> void:
	# ClassDB üzerinden: addon yoksa "Steam" sınıfı hiç yoktur — derleme bağımlılığı doğmaz
	if not ClassDB.class_exists("Steam"):
		return
	_steam = ClassDB.instantiate("Steam")
	if _steam == null:
		return
	var init: Dictionary = _steam.steamInitEx(480, true)
	# status 0 = OK; Steam kapalıysa/çalışmıyorsa sessizce vazgeç (cozy: kullanıcıyı rahatsız etme)
	if int(init.get("status", 1)) != 0:
		_steam = null
		return
	_ready = true
	print("[steam] bağlandı: %s" % str(init.get("verbal", "")))

static func tick() -> void:
	if _ready:
		_steam.run_callbacks()

static var _sent := {}   # oturum içi tekrar-gönderim önleme (poll idempotent kalsın)

static func unlock(ach: String) -> void:
	if not _ready or _sent.has(ach):
		return
	_sent[ach] = true
	_steam.setAchievement(ach)
	_steam.storeStats()

static func is_active() -> bool:
	return _ready
