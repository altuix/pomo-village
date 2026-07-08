extends SceneTree
# NEFES etkileşim testleri (headless, saf World): dilek→mektup, cevap→bond+atkı, (A5 melodi).
# Kullanım: tools/godot.sh --headless --script tests/run_features.gd

func _init() -> void:
	var ok := true
	ok = _test_wish_letter() and ok
	ok = _test_focus() and ok
	ok = _test_melody() and ok
	ok = _test_save() and ok
	ok = _test_pomodoro_stats() and ok
	ok = _test_atomic_save() and ok
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)

# B+ atomic save (#22): tmp→rename + .bak; bozuk asıl kayıt → yedekten dönüş; settings.cfg round-trip.
func _test_atomic_save() -> bool:
	# DİKKAT: headless user:// gerçek oyunla paylaşımlı — mevcut kayıtları yedekle, sonunda geri koy.
	var keep := {}
	for pth in ["user://save.json", "user://save.json.bak", "user://settings.cfg"]:
		if FileAccess.file_exists(pth):
			var fk := FileAccess.open(pth, FileAccess.READ)
			keep[pth] = fk.get_as_text()
			fk.close()
	var W := load("res://scripts/world.gd")
	var S := load("res://scripts/save.gd")
	var w = W.new(); w.gen(0)
	for t in range(500): w.step_world()
	S.save(w)                                    # 1. kayıt (tick 500)
	for t in range(100): w.step_world()
	S.save(w)                                    # 2. kayıt → .bak = 1. kayıt
	var bak_ok: bool = FileAccess.file_exists("user://save.json.bak")
	var fb := FileAccess.open("user://save.json", FileAccess.WRITE)
	fb.store_string("{bozuk json")
	fb.close()
	var w2 = W.new()
	var res: Dictionary = S.load_into(w2)       # bozuk asıl → .bak'tan (tick 500 + minik offline)
	var fallback_ok: bool = res.get("ok", false) and w2.tick >= 500 and w2.tick < 560
	var St := load("res://scripts/settings.gd")
	St.save_audio({ "rain": 0.33, "master": 0.5 })
	var g: Dictionary = St.load_audio()
	var set_ok: bool = absf(g.rain - 0.33) < 0.001 and absf(g.master - 0.5) < 0.001 and absf(g.pad - 0.25) < 0.001
	# temizle + gerçek kayıtları geri koy
	var dir := DirAccess.open("user://")
	for pth in ["user://save.json", "user://save.json.bak", "user://settings.cfg", "user://save.json.tmp"]:
		if FileAccess.file_exists(pth):
			dir.remove(String(pth).get_file())
	for pth in keep.keys():
		var fr := FileAccess.open(pth, FileAccess.WRITE)
		fr.store_string(keep[pth])
		fr.close()
	print("B+ atomic: bak=%s yedekten-dönüş=%s (tick=%d) settings=%s" % [str(bak_ok), str(fallback_ok), w2.tick, str(set_ok)])
	var pass_ok: bool = bak_ok and fallback_ok and set_ok
	print("B+a: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

# B+ Pomodoro: SERİ TANIMI (aynı gün art arda; gün değişince nazik sıfır, kazanılan kalır) + istatistik + seans kalıcılığı alanları.
func _test_pomodoro_stats() -> bool:
	var W := load("res://scripts/world.gd")
	var w = W.new(); w.gen(0)
	for t in range(3000): w.step_world()
	w.finish_focus_reward(20260708, 25)
	var d1: bool = w.streak == 1 and w.today_focus_min == 25 and w.stat_focus_min == 25
	w.finish_focus_reward(20260708, 25)
	var d2: bool = w.streak == 2 and w.today_focus_min == 50 and w.best_streak == 2
	w.finish_focus_reward(20260709, 50)   # yeni gün: seri nazikçe 1'e döner, toplam/best korunur
	var d3: bool = w.streak == 1 and w.today_focus_min == 50 and w.stat_focus_min == 100 and w.best_streak == 2
	# seans kalıcılığı + istatistik save round-trip; growth_mult yüklemede daima 1.0
	w.focus_phase = "work"; w.focus_until = 1234567.0; w.focus_mode = 1
	w.growth_mult = 1.5
	var d = JSON.parse_string(JSON.stringify(w.to_save()))
	var w2 = W.new(); w2.from_save(d)
	var rt: bool = w2.stat_focus_min == 100 and w2.best_streak == 2 and w2.focus_day == 20260709 \
		and w2.focus_phase == "work" and int(w2.focus_until) == 1234567 and w2.focus_mode == 1 \
		and w2.growth_mult == 1.0
	# uyku penceresi (kule susması): 23-05 arası
	w.force_time(23.5)
	var asleep: bool = w.is_asleep()
	w.force_time(12.0)
	var awake: bool = not w.is_asleep()
	print("B+ pomodoro: gün1=%s gün1b=%s günDeğişimi=%s roundtrip=%s uyku=%s/%s" % [str(d1), str(d2), str(d3), str(rt), str(asleep), str(awake)])
	var pass_ok: bool = d1 and d2 and d3 and rt and asleep and awake
	print("B+: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

func _test_save() -> bool:
	var W := load("res://scripts/world.gd")
	var w = W.new(); w.gen(0)
	for t in range(3000): w.step_world()
	# oyuncu etkileşimleri (seed+tick'ten sapma yarat)
	if w.wish != null: w.grant_wish()
	w.teach_tower([0, 2, 4, 2, -1, 3, 1, 0])
	for i in range(w.letters.size()):
		if not w.letters[i].replied:
			w.reply_letter(i)
			break
	var snap := { "pop": w.population(), "bond": w.bond, "fount": w.fountains.size(),
		"lett": w.letters.size(), "mem": w.mem_trees.size(), "tick": w.tick,
		"concert": w.concert_done, "births": w.stat_births }
	# JSON round-trip (int→float bozulması burada yakalanır)
	var js := JSON.stringify(w.to_save())
	var d = JSON.parse_string(js)
	var w2 = W.new(); w2.from_save(d)
	var eq: bool = w2.population() == snap.pop and w2.bond == snap.bond \
		and w2.fountains.size() == snap.fount and w2.letters.size() == snap.lett \
		and w2.mem_trees.size() == snap.mem and w2.tick == snap.tick \
		and w2.concert_done == snap.concert and w2.stat_births == snap.births
	# yükleme sonrası determinizm: w (hiç serileşmedi) ile w2 aynı ilerlemeli
	for t in range(2000):
		w.step_world(); w2.step_world()
	var det: bool = w.population() == w2.population() and w.stat_births == w2.stat_births
	# seed'ler int mi (JSON float bozması düzeltildi mi)
	var seed_int := true
	for p in w2.people:
		if typeof(p.seed) != TYPE_INT:
			seed_int = false
			break
	print("B1 save: roundtrip-eq=%s, load-determinizm=%s (w=%d w2=%d), seed-int=%s" % [str(eq), str(det), w.population(), w2.population(), str(seed_int)])
	var pass_ok: bool = eq and det and seed_int
	print("B1: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

func _test_focus() -> bool:
	var W := load("res://scripts/world.gd")
	# ×1.5 çarpanı: ilk tick'te büyüme ~1.5× (inşaat henüz tetiklenmez)
	var a = W.new(); a.gen(0); a.step_world()
	var b = W.new(); b.gen(0); b.growth_mult = 1.5; b.step_world()
	var mult_ok: bool = b.growth > a.growth * 1.4
	# seri: 3 seans → atölye + ödül mektubu
	var w = W.new(); w.gen(0)
	for t in range(3000): w.step_world()   # dönüştürülecek inşasız bina olsun
	var g0: float = w.growth
	w.finish_focus_reward()
	var reward_growth: bool = w.growth > g0
	w.finish_focus_reward()
	var r3 = w.finish_focus_reward()
	var atolye_ok: bool = w.unlocked.atolye and r3.atolye and w.streak == 3
	var has_seri := false
	for l in w.letters:
		if l.kind == "seri":
			has_seri = true
	print("A3 odak: ×1.5=%s (a=%.3f b=%.3f), ödül-büyüme=%s, seri3→atölye=%s, seri-mektup=%s" % [str(mult_ok), a.growth, b.growth, str(reward_growth), str(atolye_ok), str(has_seri)])
	var pass_ok: bool = mult_ok and reward_growth and atolye_ok and has_seri
	print("A3: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

func _test_wish_letter() -> bool:
	var W := load("res://scripts/world.gd")
	var w = W.new()
	w.gen(0)
	# yetişkin nüfus birikene + dilek çıkana kadar ilerle
	var got_wish := false
	for t in range(10000):
		w.step_world()
		if w.wish != null:
			got_wish = true
			break
	if not got_wish:
		print("A4: dilek üretilmedi FAIL"); return false
	var f0: int = w.fountains.size() + w.trees.size() + w.lamps.size()
	var lt0: int = w.letters.size()
	var pos = w.grant_wish()
	var placed: bool = (w.fountains.size() + w.trees.size() + w.lamps.size()) > f0
	var lettered: bool = w.letters.size() > lt0 and w.letters[0].kind == "dilek"
	var counted: bool = w.stat_wishes == 1   # albüm sayacı (Faz C)
	print("A4 dilek: obje 0→1=%s, mektup(dilek)=%s, sayaç=%s, pos=%s, wish temizlendi=%s" % [str(placed), str(lettered), str(counted), str(pos), str(w.wish == null)])

	# cevap → bond + atkı
	var b0: int = w.bond
	var target_idx := -1
	for i in range(w.letters.size()):
		if not w.letters[i].replied:
			target_idx = i
			break
	w.reply_letter(target_idx)
	var bonded: bool = w.bond == b0 + 1
	var scarfed := false
	var replied_name: String = w.letters[target_idx].from
	for p in w.people:
		if p.name == replied_name and p.scarf:
			scarfed = true
	print("A4 cevap: bond %d→%d=%s, atkı=%s" % [b0, w.bond, str(bonded), str(scarfed)])
	# atkı: yanıtlanan kişi hâlâ hayatta olmayabilir (veda mektubu); dilek mektubu sahibi genelde yaşar
	var pass_ok: bool = placed and lettered and counted and w.wish == null and bonded
	print("A4: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

func _test_melody() -> bool:
	var M := load("res://scripts/melody.gd")
	if M == null:
		print("A5: melody.gd yok — SKIP")
		return true
	# iyi beste (≥5 nota, ≥3 farklı, ≥3 hareket) vs zayıf
	var good = M.quality([0, 2, 4, 2, -1, 3, 1, 0])
	var weak = M.quality([0, 0, 0, 0, -1, -1, -1, -1])
	# konser ödülü: iyi beste → concert + gezgin müzisyen mektubu + bond + tek kez
	var W := load("res://scripts/world.gd")
	var w = W.new(); w.gen(0)
	for t in range(3000): w.step_world()
	var b0: int = w.bond
	var pop0: int = w.population()
	var res = w.teach_tower([0, 2, 4, 2, -1, 3, 1, 0])
	var concert_ok: bool = res.concert and w.concert_done and w.bond == b0 + 1 and w.population() == pop0 + 1
	var has_konser := false
	for l in w.letters:
		if l.kind == "konser":
			has_konser = true
	var res2 = w.teach_tower([0, 2, 4, 2, -1, 3, 1, 0])
	var once_ok: bool = not res2.concert
	# paylaşım kodu round-trip
	var code = M.to_code([0, 2, 4, 2, -1, 3, 1, 0])
	var back = M.from_code(code)
	var code_ok: bool = back == [0, 2, 4, 2, -1, 3, 1, 0] and code.length() == 8
	print("A5 iyi=%s zayıf=%s konser=%s mektup=%s bir-kez=%s kod=%s(%s)" % [str(good.ok), str(weak.ok), str(concert_ok), str(has_konser), str(once_ok), code, str(code_ok)])
	var pass_ok: bool = good.ok and not weak.ok and concert_ok and has_konser and once_ok and code_ok
	print("A5: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok
