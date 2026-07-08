class_name SaveGame
extends RefCounted
## NEFES kayıt (CLAUDE.md: user://save.json) + offline "sen yokken" ileri-sarma.
## Tam durum serileştirilir (world.to_save/from_save). Offline: geçen gerçek süre → deterministik
## step_world ileri-sar (sınırlı — çok uzun boot beklemesini önle), doğum/veda/gelen say.

const PATH := "user://save.json"
const BAK := "user://save.json.bak"
const TICK_DT := 0.75
# 28800 tick = 12 oyun günü ≈ 6 gerçek saatlik yokluğa kadar birebir ileri-sarma (denetim #26:
# eski 20000 bir gecelik uykuda bile hep 'capped' gösteriyordu). Boot senkron maliyeti ~2.6s (M4 ölçümü).
const OFFLINE_CAP := 28800
const LOCK := "user://nefes.lock"
const LOCK_STALE_SEC := 150.0   # canlılık damgası 60sn'de bir; çökmüş kopyanın kilidi ~2.5dk'da düşer

## Multi-instance kilidi (denetim #23): damga taze ise başka kopya çalışıyor demektir.
static func acquire_lock() -> bool:
	if FileAccess.file_exists(LOCK):
		var f := FileAccess.open(LOCK, FileAccess.READ)
		if f != null:
			var ts := f.get_as_text().to_float()
			f.close()
			if Time.get_unix_time_from_system() - ts < LOCK_STALE_SEC:
				return false
	touch_lock()
	return true

static func touch_lock() -> void:
	var f := FileAccess.open(LOCK, FileAccess.WRITE)
	if f != null:
		f.store_string(str(Time.get_unix_time_from_system()))
		f.close()

static func release_lock() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("nefes.lock"):
		dir.remove("nefes.lock")

static func has_save() -> bool:
	return FileAccess.file_exists(PATH) or FileAccess.file_exists(BAK)

## ATOMİK yazım: tmp'ye yaz → eski kayıt .bak'a → tmp asıl adına. Yazım ortasında
## crash/elektrik kesintisi = eski kayıt sağlam kalır (B+ denetim #22).
static func save(world: World) -> bool:
	var f := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		push_warning("[save] geçici dosya açılamadı — kayıt atlandı")
		return false
	var d: Dictionary = world.to_save()
	d["app"] = ProjectSettings.get_setting("application/config/version", "dev")   # denetim #25
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		push_warning("[save] user:// açılamadı — kayıt atlandı")
		return false
	if dir.file_exists("save.json"):
		if dir.file_exists("save.json.bak"):
			dir.remove("save.json.bak")
		dir.rename("save.json", "save.json.bak")
	dir.rename("save.json.tmp", "save.json")
	return true

## Yeni Kasaba öncesi: mevcut kayıt .bak'a alınır (cozy: yanlışlıkla kayıp yok — ana menü onayı söyler).
static func backup_current() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("save.json"):
		if dir.file_exists("save.json.bak"):
			dir.remove("save.json.bak")
		dir.rename("save.json", "save.json.bak")

static func _read_state(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return null
	# şema kontrolü: zorunlu anahtarlar yoksa kayıt BOZUK sayılır (yarım/yabancı JSON from_save'i
	# çökertiyordu — 'seed' erişimi patlar); bozuk → yedek/taze-kasaba yoluna düşer (kural 9)
	for req in ["seed", "tick", "people", "buildings"]:
		if not (d as Dictionary).has(req):
			push_warning("[load] kayıtta zorunlu alan yok ('%s') — bozuk sayılıyor: %s" % [req, path])
			return null
	return d

## Kaydı world'e yükler + offline ilerletir. Döner: {ok, elapsed_sec, offline:{...}}
static func load_into(world: World) -> Dictionary:
	var d: Variant = _read_state(PATH)
	if d == null:
		# bozuk/eksik asıl kayıt sessizce yutulmaz: logla + yedekten dön (kural 9)
		push_warning("[load] save.json bozuk ya da yok — yedek (.bak) deneniyor")
		d = _read_state(BAK)
	if d == null:
		return { "ok": false }
	# migrasyon iskeleti (denetim #25): gelecekte v>1 formatı buradan dönüştürülür
	if int(d.get("v", 1)) > 1:
		push_warning("[load] kayıt daha yeni bir NEFES sürümünden (v%d) — elden geldiğince yükleniyor" % int(d.get("v", 1)))
	world.from_save(d)
	var last_exit := float(d.get("last_exit", 0.0))
	var now := Time.get_unix_time_from_system()
	var elapsed := maxf(0.0, now - last_exit) if last_exit > 0.0 else 0.0
	var offline := _offline_advance(world, elapsed)
	return { "ok": true, "elapsed_sec": elapsed, "offline": offline }

static func _offline_advance(world: World, elapsed_sec: float) -> Dictionary:
	var ticks := int(elapsed_sec / TICK_DT)
	var capped := ticks > OFFLINE_CAP
	ticks = mini(ticks, OFFLINE_CAP)
	var b0 := world.stat_births
	var f0 := world.stat_farewells
	var a0 := world.stat_arrivals
	var p0 := world.population()
	for i in range(ticks):
		world.step_world()
	return {
		"ticks": ticks, "capped": capped,
		"births": world.stat_births - b0,
		"farewells": world.stat_farewells - f0,
		"arrivals": world.stat_arrivals - a0,
		"pop_before": p0, "pop_after": world.population(),
	}
