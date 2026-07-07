class_name SaveGame
extends RefCounted
## NEFES kayıt (CLAUDE.md: user://save.json) + offline "sen yokken" ileri-sarma.
## Tam durum serileştirilir (world.to_save/from_save). Offline: geçen gerçek süre → deterministik
## step_world ileri-sar (sınırlı — çok uzun boot beklemesini önle), doğum/veda/gelen say.

const PATH := "user://save.json"
const TICK_DT := 0.75
const OFFLINE_CAP := 20000   # ~8 oyun günü / ~4 gerçek saat; aşınca "capped" işaretlenir

static func has_save() -> bool:
	return FileAccess.file_exists(PATH)

static func save(world: World) -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(world.to_save(), "\t"))
	f.close()
	return true

## Kaydı world'e yükler + offline ilerletir. Döner: {ok, elapsed_sec, offline:{...}}
static func load_into(world: World) -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return { "ok": false }
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return { "ok": false }
	var txt := f.get_as_text()
	f.close()
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY:
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
