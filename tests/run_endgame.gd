extends SceneTree
# NEFES end-game testi (STEAM_ROADMAP Faz 0, denetim #29): 365 gün hızlandırılmış koşu.
# 30-günlük pop-band uzun vadeyi görmez; burada ölçülenler:
#   - çökme(=0)/patlama(>150) yok; denge bandı 20-90 uzun vadede de tutar
#   - bellek sınırları: letters ≤ LETTER_CAP, mem_trees ≤ 40 (şişme = FAIL)
#   - step_world süresi düz kalır (son 10 gün ort ≤ ilk 10 gün ort × 3 — O(n²) sızıntısı yakalar)
#   - 365. günde save→load→save roundtrip eşit (uzun save int/float bozulması)
#   - growth akıbeti LOGLANIR (kasaba dolunca sessiz no-op görünür kılınır; tasarım Faz D)
#   - timelapse günlerinde (0/3/7/14/30/60/120/365) İNŞA EDİLMİŞ bina sayısı monoton artar
#     (lit_count DEĞİL: aile vedasıyla ev kararır → uyanık sayısı dalgalanır; inşa geri alınmaz)
# Kullanım: tools/godot.sh --headless --script tests/run_endgame.gd -- [seed=20260707]

const TICKS_PER_DAY := 2400
const TIMELAPSE_DAYS := [0, 3, 7, 14, 30, 60, 120, 365]

func _init() -> void:
	var seed_val := 20260707
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", false, 1)
		if kv.size() == 2 and kv[0] == "seed":
			seed_val = int(kv[1])

	var W := load("res://scripts/world.gd")
	var w = W.new()
	w.gen(seed_val)

	var pmin := 9999
	var pmax := 0
	var ever_zero := false
	var ever_explode := false
	var max_letters := 0
	var max_memtrees := 0
	var day_us: Array[int] = []
	var lapse_counts: Array[int] = [_built_count(w)]

	for day in range(365):
		var d0 := Time.get_ticks_usec()
		for t in range(TICKS_PER_DAY):
			w.step_world()
			var pnow: int = w.population()
			if pnow <= 0: ever_zero = true
			if pnow > 150: ever_explode = true
		day_us.append(Time.get_ticks_usec() - d0)
		max_letters = maxi(max_letters, w.letters.size())
		max_memtrees = maxi(max_memtrees, w.mem_trees.size())
		if day >= 3:
			pmin = mini(pmin, w.population())
			pmax = maxi(pmax, w.population())
		if TIMELAPSE_DAYS.has(day + 1):
			lapse_counts.append(_built_count(w))

	# --- band + bellek ---
	var band_ok: bool = pmin >= 20 and pmax <= 90 and not ever_zero and not ever_explode
	var mem_ok: bool = max_letters <= w.LETTER_CAP and max_memtrees <= 40

	# --- perf düzlüğü: son 10 gün ort ≤ (gün 3-13 ort) × 3 ---
	var early := 0.0
	for i in range(3, 13): early += day_us[i]
	early /= 10.0
	var late := 0.0
	for i in range(355, 365): late += day_us[i]
	late /= 10.0
	var perf_ok: bool = late <= early * 3.0

	# --- 365. gün roundtrip (last_exit zamana bağlı → kıyastan çıkar) ---
	var d1: Dictionary = w.to_save()
	d1.erase("last_exit")
	var w2 = W.new()
	w2.from_save(JSON.parse_string(JSON.stringify(w.to_save())))
	var d2: Dictionary = w2.to_save()
	d2.erase("last_exit")
	# growth_mult yüklemede bilinçli 1.0'a zorlanır (B+ bug 3) → kıyas için eşitle
	d1.growth_mult = 1.0
	var rt_ok: bool = JSON.stringify(d1) == JSON.stringify(d2)

	# --- timelapse monotonluğu: ev sayısı hiçbir örnekte azalmaz ---
	var mono_ok := true
	for i in range(1, lapse_counts.size()):
		if lapse_counts[i] < lapse_counts[i - 1]:
			mono_ok = false

	# --- growth akıbeti (assert değil, GÖRÜNÜR ölçüm — end-game tasarımı Faz D) ---
	var unbuilt := 0
	for b in w.buildings:
		if b.built == 0:
			unbuilt += 1
	print("== endgame (365 gün, tohum %d) ==" % seed_val)
	print("  denge (gün 3+): min=%d max=%d son=%d  çökme=%s patlama=%s -> %s" % [pmin, pmax, w.population(), str(ever_zero), str(ever_explode), "OK" if band_ok else "FAIL"])
	print("  bellek: letters max=%d (tavan %d)  mem_trees max=%d (tavan 40) -> %s" % [max_letters, w.LETTER_CAP, max_memtrees, "OK" if mem_ok else "FAIL"])
	print("  perf: gün 3-13 ort=%.1fms  son 10 gün ort=%.1fms (x%.2f) -> %s" % [early / 1000.0, late / 1000.0, late / maxf(1.0, early), "OK" if perf_ok else "FAIL"])
	print("  roundtrip (365. gün): %s" % ("OK" if rt_ok else "FAIL"))
	print("  timelapse ev sayıları %s monoton -> %s" % [str(lapse_counts), "OK" if mono_ok else "FAIL"])
	print("  growth akıbeti: frontier=%d/%d  goal=%.0f  growth=%.0f  inşasız bina=%d  (dolunca ne olacağı Faz D tasarımı)" % [w.frontier, w.GW, w.goal, w.growth, unbuilt])

	var ok: bool = band_ok and mem_ok and perf_ok and rt_ok and mono_ok
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)

func _built_count(w) -> int:
	var n := 0
	for b in w.buildings:
		if b.built == 1:
			n += 1
	return n
