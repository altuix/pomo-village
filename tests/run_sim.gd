extends SceneTree
# NEFES sim hızlı-ileri testi (headless — saf sim, GPU yok).
# G1 kuralı: kasaba BÜYÜR — gün-30 nüfusu gün-3'ten +20 yüksek ve 60-130 bandında;
# çökme(=0), patlama(>380 — POP_SOFT_CAP 320 + pay) ya da ani çöküş (tepe'nin %60 altı) = regresyon.
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

	# --- büyüme testi (G1: "20-90 dengesi" yerine görünür büyüme) ---
	# İlk WARMUP_DAYS gün başlangıç rampası (kasaba 4'ten uyanır) → trend kıyası gün-3'ten.
	const WARMUP_DAYS := 3
	w.gen(seed_val)
	var total := days * TICKS_PER_DAY
	var ever_zero := false
	var ever_explode := false
	var samples: Array[int] = []
	for t in range(total):
		w.step_world()
		var pnow: int = w.population()
		if pnow <= 0: ever_zero = true
		if pnow > 380: ever_explode = true
		if t % TICKS_PER_DAY == 0:
			samples.append(pnow)
	var pend: int = w.population()
	# ani çöküş: hiçbir günlük örnek o ana dek görülen tepenin %60 altına düşmez (kuşak dalgası regresyonu)
	var peak := 0
	var drawdown_ok := true
	for i in range(WARMUP_DAYS, samples.size()):
		peak = maxi(peak, samples[i])
		if samples[i] < int(peak * 0.6):
			drawdown_ok = false
	var p3: int = samples[WARMUP_DAYS]
	print("== büyüme (%d gün, tohum %d) ==" % [days, seed_val])
	print("  günlük örnekler: ", samples)
	print("  gün-%d=%d → son=%d (hedef: +20 ve 60-130)  ani-çöküş=%s" % [WARMUP_DAYS, p3, pend, str(not drawdown_ok)])
	print("  çökme=%s  patlama=%s" % [str(ever_zero), str(ever_explode)])
	var band_ok: bool = pend >= p3 + 20 and pend >= 60 and pend <= 130 and drawdown_ok and not ever_zero and not ever_explode
	print("  büyüme bandı: %s" % ("OK" if band_ok else "FAIL"))

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
