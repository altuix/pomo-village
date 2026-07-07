extends SceneTree
# NEFES sim hızlı-ileri testi (headless — saf sim, GPU yok).
# Anayasa kuralı: 30 günde nüfus 20-90 bandında dalgalanmalı; çökme(=0) veya patlama(>150) = regresyon.
# Ayrıca determinizm: aynı tohum → N adım sonra özdeş nüfus.
#
# Kullanım: tools/godot.sh --headless --script tests/run_sim.gd -- [days=30] [seed=20260707]
#
# Beklenen World API (A0'da scripts/world.gd sağlar):
#   World.new(); world.gen(seed:int); world.step_world(); world.population()->int

const TICKS_PER_DAY := 2400

func _init() -> void:
	var days := 30
	var seed_val := 20260707
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", false, 1)
		if kv.size() != 2: continue
		if kv[0] == "days": days = int(kv[1])
		if kv[0] == "seed": seed_val = int(kv[1])

	var WorldScript := load("res://scripts/world.gd")
	if WorldScript == null:
		print("run_sim: scripts/world.gd henüz yok — A0'da bağlanacak (şimdilik SKIP).")
		quit(0); return

	var w = WorldScript.new()
	if not w.has_method("gen") or not w.has_method("step_world") or not w.has_method("population"):
		print("run_sim: world.gd API eksik (gen/step_world/population) — SKIP.")
		quit(0); return

	# --- pop-band testi ---
	# İlk WARMUP_DAYS gün başlangıç rampasıdır (kasaba 4'ten uyanır) → denge-durumu bandından hariç.
	# Denge bandı 20-90; ayrıca HİÇBİR anda çökme(=0) veya patlama(>150) olmamalı.
	const WARMUP_DAYS := 3
	w.gen(seed_val)
	var total := days * TICKS_PER_DAY
	var pmin := 9999
	var pmax := 0
	var ever_zero := false
	var ever_explode := false
	var samples: Array[int] = []
	for t in range(total):
		w.step_world()
		var pnow: int = w.population()
		if pnow <= 0: ever_zero = true
		if pnow > 150: ever_explode = true
		if t % TICKS_PER_DAY == 0:
			samples.append(pnow)
			var day := t / TICKS_PER_DAY
			if day >= WARMUP_DAYS:
				pmin = min(pmin, pnow)
				pmax = max(pmax, pnow)
	var pend: int = w.population()
	print("== pop-band (%d gün, tohum %d) ==" % [days, seed_val])
	print("  günlük örnekler: ", samples)
	print("  denge (gün %d+): min=%d  max=%d  son=%d" % [WARMUP_DAYS, pmin, pmax, pend])
	print("  çökme=%s  patlama=%s" % [str(ever_zero), str(ever_explode)])
	var band_ok: bool = pmin >= 20 and pmax <= 90 and pend > 0 and not ever_zero and not ever_explode
	print("  20-90 bandı (denge): %s" % ("OK" if band_ok else "FAIL"))

	# --- determinizm testi ---
	var a = WorldScript.new(); a.gen(seed_val)
	var b = WorldScript.new(); b.gen(seed_val)
	for i in range(5000):
		a.step_world(); b.step_world()
	var det_ok: bool = a.population() == b.population()
	print("== determinizm (5000 adım) ==")
	print("  A.pop=%d  B.pop=%d -> %s" % [a.population(), b.population(), ("OK" if det_ok else "FAIL")])

	var ok: bool = band_ok and det_ok
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
