extends SceneTree
# NEFES end-game testi (STEAM_ROADMAP Faz 0, denetim #29): 365 gün hızlandırılmış koşu.
# G1: 30-günlük büyüme testi uzun vadeyi görmez; burada ölçülenler:
#   - çökme(=0)/patlama(>380) yok; gün-365 nüfusu 130-260 (kasaba YIL boyunca büyümüş olmalı)
#   - 30-günlük pencere ortalamaları monoton artar (±%10 tolerans — büyüme hissi assert'i)
#   - bellek sınırları: letters ≤ LETTER_CAP, mem_trees ≤ 40 (şişme = FAIL)
#   - step_world süresi KİŞİ-BAŞINA düz kalır (nüfus meşru büyür — O(n²) sızıntısını yine yakalar)
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

	var pmax := 0
	var ever_zero := false
	var ever_explode := false
	var max_letters := 0
	var max_memtrees := 0
	var day_us: Array[int] = []
	var day_pop: Array[int] = []
	var lapse_counts: Array[int] = [_built_count(w)]

	for day in range(365):
		var d0 := Time.get_ticks_usec()
		for t in range(TICKS_PER_DAY):
			w.step_world()
			var pnow: int = w.population()
			if pnow <= 0: ever_zero = true
			if pnow > 380: ever_explode = true
		day_us.append(Time.get_ticks_usec() - d0)
		day_pop.append(w.population())
		max_letters = maxi(max_letters, w.letters.size())
		max_memtrees = maxi(max_memtrees, w.mem_trees.size())
		pmax = maxi(pmax, w.population())
		if TIMELAPSE_DAYS.has(day + 1):
			lapse_counts.append(_built_count(w))

	# --- büyüme (G1): gün-365 nüfusu bantta + 30-günlük pencere ortalamaları monoton (±%10) ---
	var win_avgs: Array[float] = []
	for wstart in range(0, 360, 30):
		var s := 0.0
		for i in range(wstart, wstart + 30):
			s += day_pop[i]
		win_avgs.append(s / 30.0)
	var mono_pop := true
	for i in range(1, win_avgs.size()):
		if win_avgs[i] < win_avgs[i - 1] * 0.9:
			mono_pop = false
	# tier: gün-365'te en az Küçük Şehir (nüfus 180 eşiği) — ünvan sistemi yıl içinde işlemiş olmalı
	var band_ok: bool = w.population() >= 130 and w.population() <= 260 and pmax <= 340 \
		and w.tier >= 4 and mono_pop and not ever_zero and not ever_explode
	var mem_ok: bool = max_letters <= w.LETTER_CAP and max_memtrees <= 40

	# --- perf düzlüğü KİŞİ-BAŞINA: nüfus meşru büyür; O(n²) sızıntısını yine yakalar ---
	var early := 0.0
	for i in range(3, 13): early += day_us[i]
	early /= 10.0
	var late := 0.0
	for i in range(355, 365): late += day_us[i]
	late /= 10.0
	var early_pc := early / maxf(1.0, win_avgs[0])
	var late_pc := late / maxf(1.0, win_avgs[win_avgs.size() - 1])
	var perf_ok: bool = late_pc <= early_pc * 3.0

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
	print("  büyüme: son=%d (hedef 130-260)  tepe=%d (tavan 340)  30-gün pencereleri=%s monoton=%s  çökme=%s patlama=%s -> %s" % [w.population(), pmax, str(win_avgs.map(func(x): return int(x))), str(mono_pop), str(ever_zero), str(ever_explode), "OK" if band_ok else "FAIL"])
	print("  bellek: letters max=%d (tavan %d)  mem_trees max=%d (tavan 40) -> %s" % [max_letters, w.LETTER_CAP, max_memtrees, "OK" if mem_ok else "FAIL"])
	print("  perf (kişi-başı): erken=%.1fus/kişi  geç=%.1fus/kişi (x%.2f) -> %s" % [early_pc, late_pc, late_pc / maxf(0.001, early_pc), "OK" if perf_ok else "FAIL"])
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
