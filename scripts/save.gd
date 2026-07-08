class_name SaveGame
extends RefCounted
## NEFES kayıt (CLAUDE.md: user://save.json) + offline "sen yokken" ileri-sarma.
## Tam durum serileştirilir (world.to_save/from_save). Offline: geçen gerçek süre → deterministik
## step_world ileri-sar (sınırlı — çok uzun boot beklemesini önle), doğum/veda/gelen say.

const PATH := "user://save.json"
const BAK := "user://save.json.bak"
const TICK_DT := 0.75
const OFFLINE_CAP := 20000   # ~8 oyun günü / ~4 gerçek saat; aşınca "capped" işaretlenir

static func has_save() -> bool:
	return FileAccess.file_exists(PATH) or FileAccess.file_exists(BAK)

## ATOMİK yazım: tmp'ye yaz → eski kayıt .bak'a → tmp asıl adına. Yazım ortasında
## crash/elektrik kesintisi = eski kayıt sağlam kalır (B+ denetim #22).
static func save(world: World) -> bool:
	var f := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		push_warning("[save] geçici dosya açılamadı — kayıt atlandı")
		return false
	f.store_string(JSON.stringify(world.to_save(), "\t"))
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

static func _read_state(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return d if typeof(d) == TYPE_DICTIONARY else null

## Kaydı world'e yükler + offline ilerletir. Döner: {ok, elapsed_sec, offline:{...}}
static func load_into(world: World) -> Dictionary:
	var d: Variant = _read_state(PATH)
	if d == null:
		# bozuk/eksik asıl kayıt sessizce yutulmaz: logla + yedekten dön (kural 9)
		push_warning("[load] save.json bozuk ya da yok — yedek (.bak) deneniyor")
		d = _read_state(BAK)
	if d == null:
		return { "ok": false }
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
