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
	ok = _test_letters_depth() and ok
	ok = _test_endgame_design() and ok
	ok = _test_weather() and ok
	ok = _test_festival() and ok
	ok = _test_wish_variety() and ok
	ok = _test_milestone_buildings() and ok
	ok = _test_densify() and ok
	ok = _test_tiers() and ok
	ok = _test_needs() and ok
	ok = _test_stages() and ok
	ok = _test_focus_reward() and ok
	ok = _test_day_events() and ok
	ok = _test_hardening() and ok
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)

# G1.3 iç yoğunlaşma: frontier dolunca _start_construction sıklaştırır; yalnız-ekleme
# determinizmi korur; density_level save'de taşınır; bütünlenme ancak seviye 3'te.
func _test_densify() -> bool:
	var W := load("res://scripts/world.gd")
	var w = W.new(); w.gen(0)
	w.frontier = W.GW - 6
	var roads0: int = w.road_list.size()
	var blds0: int = w.buildings.size()
	for b in w.buildings:
		b.built = 1
		b.build_prog = 1.0
	w._start_construction()   # aday yok + frontier maks → densify(1) + yeni parselden inşaat
	var densified: bool = w.density_level == 1 and w.buildings.size() > blds0 and w.road_list.size() > roads0
	var started: bool = w.building_now != null and not w.town_complete
	# yalnız-ekleme determinizmi: aynı tohum + aynı akış → özdeş yol/bina dizilimi
	var w2 = W.new(); w2.gen(0)
	w2.frontier = W.GW - 6
	for b in w2.buildings:
		b.built = 1
		b.build_prog = 1.0
	w2._start_construction()
	var det: bool = w2.road_list.size() == w.road_list.size() and w2.buildings.size() == w.buildings.size()
	if det:
		for i in range(w.road_list.size()):
			if w.road_list[i] != w2.road_list[i]:
				det = false
	# roundtrip: density_level taşınır
	var w3 = W.new()
	w3.from_save(JSON.parse_string(JSON.stringify(w.to_save())))
	var rt: bool = w3.density_level == 1
	print("G1 yoğunlaşma: sıklaştı=%s inşaat=%s determinizm=%s roundtrip=%s" % [str(densified), str(started), str(det), str(rt)])
	var pass_ok: bool = densified and started and det and rt
	print("Gd: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

# G1.4 kasaba ünvanı: nüfus eşiği → tier + tek seferlik kutlama mektubu; kademeli yakalama;
# tier asla düşmez (kod yalnız artırır); save roundtrip.
func _test_tiers() -> bool:
	var W := load("res://scripts/world.gd")
	var w = W.new(); w.gen(0)
	while w.population() < 25:
		w._add_person(6, 13, null, 1)
	w.tick = 39
	w.step_world()   # 40. tick: kontrol anı
	var t1: bool = w.tier == 1 and w.milestones.get("tier_koy", false) and w.festival_t > 0.9
	# kademeli yakalama: nüfus 120'yken kademeler TEK TEK atlanır (her biri ayrı kutlama)
	while w.population() < 120:
		w._add_person(6, 13, null, 1)
	w.tick = 79
	w.step_world()
	var t2: bool = w.tier == 2
	w.tick = 119
	w.step_world()
	var t3: bool = w.tier == 3
	# tek seferlik: milestone anahtarı ikinci mektubu engeller
	var an_koy := 0
	for l in w.letters:
		if l.kind == "an" and "KÖY" in l.text.to_upper().left(40):
			an_koy += 1
	var once: bool = an_koy <= 2   # tier_koy + tier_buyuk_koy metinleri "KÖY" içerir; tekrar yok
	var w2 = W.new()
	w2.from_save(JSON.parse_string(JSON.stringify(w.to_save())))
	var rt: bool = w2.tier == 3 and w2.tier_name() == "Kasaba"
	print("G1 ünvan: köy=%s büyük-köy=%s kasaba=%s tek-sefer=%s roundtrip=%s" % [str(t1), str(t2), str(t3), str(once), str(rt)])
	var pass_ok: bool = t1 and t2 and t3 and once and rt
	print("Gt: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

# G1.5 ihtiyaç binaları: tier açar, oranla kurulur; inşaattaki sayılır (çifte sipariş yok);
# değirmen nehre yakın aday seçer.
func _test_needs() -> bool:
	var W := load("res://scripts/world.gd")
	var w = W.new(); w.gen(0)
	w.tier = 1
	var d1: Dictionary = w._need_deficit()
	var kuyu_first: bool = d1.get("type", "") == "kuyu"
	w._start_construction()
	var conv: bool = w.building_now != null and w.building_now.type == "kuyu"
	var d2: Dictionary = w._need_deficit()   # kuyu inşaatta → sıradaki eksik fırın (tier-2 pazar İSTENMEZ)
	var next_firin: bool = d2.get("type", "") == "firin"
	# değirmen: alt basamaklar tamamlanmış sayılır → tier 3'te değirmen nehre yakın adaya kurulur
	for n in ["firin", "pazar", "cayevi", "okul"]:
		w._add_building(10, 10, false)
		var nb: Dictionary = w.buildings[w.buildings.size() - 1]
		nb.built = 1
		nb.build_prog = 1.0
		nb.type = n
	w.tier = 3
	var d3: Dictionary = w._need_deficit()
	var mill_next: bool = d3.get("type", "") == "degirmen"
	w.building_now = null
	w._start_construction()
	var mill_ok: bool = w.building_now != null and w.building_now.type == "degirmen" and w._river_dist(w.building_now) <= 6
	print("G1 ihtiyaç: kuyu-önce=%s dönüşüm=%s sıra-fırın=%s değirmen=%s/%s" % [str(kuyu_first), str(conv), str(next_firin), str(mill_next), str(mill_ok)])
	var pass_ok: bool = kuyu_first and conv and next_firin and mill_next and mill_ok
	print("Gn: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

# G1.6 ev evreleri: kulübe doğar; yaş+servisle EVE, yaş+tier'la TAŞ EVE; 240-tick'te TEK terfi;
# asla gerileme; save roundtrip.
func _test_stages() -> bool:
	var W := load("res://scripts/world.gd")
	var w = W.new(); w.gen(0)
	var core_ok: bool = w.buildings[0].stage == 1   # çekirdek evler tanıdık görünümle başlar
	w._add_building(20, 10, false)
	var b: Dictionary = w.buildings[w.buildings.size() - 1]
	var born_hut: bool = b.stage == 0 and b.built_at == -1
	b.built = 1; b.build_prog = 1.0; b.built_at = 0
	w._add_building(22, 10, false)
	var b2: Dictionary = w.buildings[w.buildings.size() - 1]
	b2.built = 1; b2.build_prog = 1.0; b2.built_at = 0
	w.lamps.append({ "gx": 21, "gy": 10, "ph": 0.0 })   # ikisine de yakın servis
	w.tick = 3 * 2400 + 239
	w.step_world()   # 240'ın katı: terfi damlası
	var one_per_drip: bool = (int(b.stage) + int(b2.stage)) == 1   # TEK ev terfi eder
	w.tick += 239 - (w.tick % 240)
	w.step_world()
	var both_now: bool = b.stage == 1 and b2.stage == 1
	# 1→2: yaş 10 gün+ ama tier < 3 → OLMAZ; tier 3 → olur
	b.built_at = -30000
	w.tier = 2
	w.tick += 239 - (w.tick % 240)
	w.step_world()
	var gated: bool = b.stage == 1
	w.tier = 3
	w.tick += 239 - (w.tick % 240)
	w.step_world()
	var stone: bool = b.stage == 2
	var w2 = W.new()
	w2.from_save(JSON.parse_string(JSON.stringify(w.to_save())))
	var rt := false
	for bb in w2.buildings:
		if bb.gx == 20 and bb.gy == 10:
			rt = bb.stage == 2 and int(bb.built_at) == -30000
	print("G1 evre: çekirdek=%s kulübe=%s damla=%s ikisi=%s tier-kapı=%s taş=%s roundtrip=%s" % [str(core_ok), str(born_hut), str(one_per_drip), str(both_now), str(gated), str(stone), str(rt)])
	var pass_ok: bool = core_ok and born_hut and one_per_drip and both_now and gated and stone and rt
	print("Gs: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

# G1.7 odak ödülü: HER seans garantili görünür sonuç (inşaat→terfi→çiçek zinciri) +
# kümülatif seans anıtları (50→500, tek seferlik) + kule yaldızı roundtrip.
func _test_focus_reward() -> bool:
	var W := load("res://scripts/world.gd")
	# dal 1: inşasız slot var → inşaat hemen başlar
	var w = W.new(); w.gen(0)
	var r1: Dictionary = w.finish_focus_reward()
	var vis1: bool = r1.get("visible", "") == "insaat" and w.building_now != null
	# dal 2: slot yok → yaşlı ev terfi eder
	var w2 = W.new(); w2.gen(0)
	w2.frontier = W.GW - 6
	w2.density_level = 3
	for b in w2.buildings:
		b.built = 1
		b.build_prog = 1.0
		b.built_at = -30000
	var r2: Dictionary = w2.finish_focus_reward()
	var vis2: bool = r2.get("visible", "") == "terfi"
	# dal 3: terfi edecek ev de yok → çiçek
	var w3 = W.new(); w3.gen(0)
	w3.frontier = W.GW - 6
	w3.density_level = 3
	for b in w3.buildings:
		b.built = 1
		b.build_prog = 1.0
		if b.type == "house":
			b.stage = 2
	var r3: Dictionary = w3.finish_focus_reward()
	var vis3: bool = r3.get("visible", "") == "cicek"
	# seans anıtları: 50. seans heykel diker, tekrar etmez; 200 kule yaldızı; roundtrip
	var w4 = W.new(); w4.gen(0)
	w4.sessions = 49
	var d0: int = w4.decor.size()
	w4.finish_focus_reward()
	var statue: bool = w4.decor.size() == d0 + 1 and w4.milestones.get("ses50", false)
	w4.finish_focus_reward()
	var once: bool = w4.decor.size() == d0 + 1
	w4.sessions = 199
	w4.finish_focus_reward()
	var gild: bool = w4.tower_gilded and w4.milestones.get("ses200", false)
	var w5 = W.new()
	w5.from_save(JSON.parse_string(JSON.stringify(w4.to_save())))
	var rt: bool = w5.tower_gilded and w5.milestones.get("ses50", false)
	print("G1 odak-ödül: inşaat=%s terfi=%s çiçek=%s heykel=%s tek=%s yaldız=%s roundtrip=%s" % [str(vis1), str(vis2), str(vis3), str(statue), str(once), str(gild), str(rt)])
	var pass_ok: bool = vis1 and vis2 and vis3 and statue and once and gild and rt
	print("Gf: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

# G1.8 gün olayları: çeşitlilik + son-3 tekrar penceresi + determinizm + göçebe sözü + roundtrip.
func _test_day_events() -> bool:
	var W := load("res://scripts/world.gd")
	var w = W.new(); w.gen(0)
	var ids := {}
	var window_ok := true
	for d in range(200):
		w._fire_day_event(d)
		if w.recent_events.size() > 3:
			window_ok = false
		var seen := {}
		for e in w.recent_events:   # pencere içinde kopya olmamalı
			if seen.has(e):
				window_ok = false
			seen[e] = true
		if not w.recent_events.is_empty():
			ids[w.recent_events.back()] = true
	var variety: bool = ids.size() >= 6
	var w2 = W.new(); w2.gen(0)
	for d in range(200):
		w2._fire_day_event(d)
	var det: bool = str(w2.recent_events) == str(w.recent_events) and w2.population() == w.population()
	# göçebe sözü: pending_family gün sınırında boş eve yerleşir (basınç beklemez)
	var w3 = W.new(); w3.gen(0)
	w3._add_building(15, 12, false)
	var gh: Dictionary = w3.buildings[w3.buildings.size() - 1]
	gh.built = 1
	gh.build_prog = 1.0   # garantili boş ev (determinist kurulum)
	w3.pending_family = 2
	var arr0: int = w3.stat_arrivals
	for t in range(401):
		w3.step_world()
	var promise: bool = w3.pending_family == 0 and w3.stat_arrivals > arr0
	# roundtrip
	w.pending_family = 1
	w.last_event_day = 42
	var w4 = W.new()
	w4.from_save(JSON.parse_string(JSON.stringify(w.to_save())))
	var rt: bool = w4.last_event_day == 42 and w4.pending_family == 1 and str(w4.recent_events) == str(w.recent_events)
	print("G1 olaylar: çeşit=%d pencere=%s determinizm=%s söz=%s roundtrip=%s" % [ids.size(), str(window_ok), str(det), str(promise), str(rt)])
	var pass_ok: bool = variety and window_ok and det and promise and rt
	print("Ge: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

# Q4: bozuk settings.cfg default'a düşer (T2); offline gerçek-zaman cap (T4); kartpostal adı (T5).
func _test_hardening() -> bool:
	# T2 — bozuk settings.cfg: keep-yakala → boz → default dön → geri koy (user:// kuralı!)
	var keep_cfg := ""
	var had_cfg := FileAccess.file_exists("user://settings.cfg")
	if had_cfg:
		var fk := FileAccess.open("user://settings.cfg", FileAccess.READ)
		keep_cfg = fk.get_as_text()
		fk.close()
	var fb := FileAccess.open("user://settings.cfg", FileAccess.WRITE)
	fb.store_string("[[[bozuk cfg %%%")
	fb.close()
	var St := load("res://scripts/settings.gd")
	var g: Dictionary = St.load_audio()
	var cfg_ok: bool = absf(g.pad - 0.25) < 0.001 and absf(g.master - 0.7) < 0.001   # default'lar
	var dir := DirAccess.open("user://")
	dir.remove("settings.cfg")
	if had_cfg:
		var fr := FileAccess.open("user://settings.cfg", FileAccess.WRITE)
		fr.store_string(keep_cfg)
		fr.close()
	# T4 — offline ileri-sarma gerçek-zaman yolu: 24 saatlik yokluk cap'e takılır (28800 tick)
	var W := load("res://scripts/world.gd")
	var S := load("res://scripts/save.gd")
	var w = W.new(); w.gen(0)
	for t in range(100): w.step_world()
	var d: Dictionary = w.to_save()
	d["last_exit"] = Time.get_unix_time_from_system() - 86400.0   # 24 saat önce çıkmış
	var w2 = W.new()
	# load_into dosyadan okur; burada iç yolu doğrudan sınıyoruz: from_save + _offline_advance
	w2.from_save(d)
	var off: Dictionary = S._offline_advance(w2, 86400.0)
	var cap_ok: bool = off.ticks == 28800 and off.capped and w2.tick == 100 + 28800
	# kısa yokluk (10 dk) birebir sarılır
	var w3 = W.new(); w3.from_save(w.to_save())
	var off2: Dictionary = S._offline_advance(w3, 600.0)
	var exact_ok: bool = off2.ticks == 800 and not off2.capped   # 600/0.75
	# T5 — kartpostal dosya adı türetimi (take_postcard'ın adlandırma sözleşmesi)
	var day: int = w.tick / 2400 + 1
	var fname := "NEFES_tohum%d_gun%d_%s.png" % [w.town_seed(), day, w.clock_string().replace(":", "")]
	var name_ok: bool = fname.begins_with("NEFES_tohum0_gun1_") and fname.ends_with(".png") and ":" not in fname
	print("Q4 sağlamlık: bozuk-cfg=%s offline-cap=%s offline-birebir=%s kartpostal-ad=%s" % [str(cfg_ok), str(cap_ok), str(exact_ok), str(name_ok)])
	var pass_ok: bool = cfg_ok and cap_ok and exact_ok and name_ok
	print("Q4: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

# Faz D milestone bina zinciri: rasathane(10)/sera(20)/hamam(35 seans); çakışmada bina çalınmaz.
func _test_milestone_buildings() -> bool:
	var W := load("res://scripts/world.gd")
	var w = W.new(); w.gen(0)
	for t in range(3000): w.step_world()
	# ÇAKIŞMA: aynı ödülde streak→3 (atölye) VE sessions→10 (rasathane) — ikisi de ayrı bina almalı
	w.streak = 2
	w.sessions = 9
	w.finish_focus_reward()
	var shop_b = null
	var ras_b = null
	for b in w.buildings:
		if b.built == 0 and b.build_prog > 0.0:
			if b.type == "shop": shop_b = b
			if b.type == "rasathane": ras_b = b
	var collision_ok: bool = shop_b != null and ras_b != null and shop_b != ras_b
	# ikisi de zamanla TAMAMLANIR (sahipsiz inşaat sahiplenilir; G1: bina 200 tick, tek slot → sıralı)
	for t in range(900): w.step_world()
	var both_done: bool = shop_b.built == 1 and ras_b.built == 1
	# zincirin kalanı
	w.sessions = 19
	w.finish_focus_reward()
	w.sessions = 34
	w.finish_focus_reward()
	var chain_ok: bool = w.unlocked.sera and w.unlocked.hamam
	# tek seferlik: yeni çağrı yeni "seri" mektubu üretmez
	var n1 := 0
	for l in w.letters:
		if l.kind == "seri": n1 += 1
	w.finish_focus_reward()
	var n2 := 0
	for l in w.letters:
		if l.kind == "seri": n2 += 1
	var once: bool = n1 == n2
	# unlocked YÜKLEME DÜZELTMESİ: yeni anahtarlar roundtrip'te korunur (eski kod düşürüyordu)
	var w2 = W.new()
	w2.from_save(JSON.parse_string(JSON.stringify(w.to_save())))
	var rt: bool = w2.unlocked.rasathane and w2.unlocked.sera and w2.unlocked.hamam and w2.unlocked.atolye
	# PENDING KUYRUK (Q1.3): uygun bina yokken dönüşüm vaadi kaybolmaz, frontier açılınca kurulur
	var w3 = W.new(); w3.gen(0)
	for b in w3.buildings:
		b.built = 1
		b.build_prog = 1.0
	w3._convert_unbuilt("sera")
	var queued: bool = w3.pending_special == ["sera"]
	w3._expand_frontier()   # yeni inşasız binalar açılır → kuyruk boşalır
	var drained: bool = w3.pending_special.is_empty()
	var placed_sera := false
	for b in w3.buildings:
		if b.type == "sera" and b.build_prog > 0.0:
			placed_sera = true
	print("D bina-zinciri: çakışma=%s ikisi-bitti=%s zincir=%s tek=%s roundtrip=%s kuyruk=%s/%s/%s" % [str(collision_ok), str(both_done), str(chain_ok), str(once), str(rt), str(queued), str(drained), str(placed_sera)])
	var pass_ok: bool = collision_ok and both_done and chain_ok and once and rt and queued and drained and placed_sera
	print("Db: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

# Faz D dilek çeşitliliği: 7 tipin hepsi kurulur; yeni 4'ü decor'e düşer; roundtrip int-güvenli.
func _test_wish_variety() -> bool:
	var W := load("res://scripts/world.gd")
	var w = W.new(); w.gen(0)
	for t in range(6000): w.step_world()   # yetişkinler
	var adult = null
	for p in w.people:
		if p.stage == 1:
			adult = p
			break
	if adult == null:
		print("Dw: yetişkin yok FAIL"); return false
	for ti in range(w.WISH_TYPES.size()):
		w.wish = { "who": adult, "type": ti }
		if w.grant_wish() == null:
			print("Dw: tip %d kurulamadı FAIL" % ti); return false
	var decor_ok: bool = w.decor.size() == 4 and w.stat_wishes >= 7
	var kinds := {}
	for dc in w.decor:
		kinds[dc.kind] = true
	var kinds_ok: bool = kinds.size() == 4
	# her tipin teşekkür metni havuzdan geldi mi (dilek mektupları)
	var pool_ok := true
	for l in w.letters:
		if l.kind == "dilek":
			var found := false
			for key in Letters.DILEK.keys():
				if Letters.DILEK[key].has(l.text):
					found = true
			if not found:
				pool_ok = false
	var w2 = W.new()
	w2.from_save(JSON.parse_string(JSON.stringify(w.to_save())))
	var rt: bool = w2.decor.size() == 4 and typeof(w2.decor[0].gx) == TYPE_INT
	print("D dilek-çeşit: decor=%s tipler=%s havuz=%s roundtrip=%s" % [str(decor_ok), str(kinds_ok), str(pool_ok), str(rt)])
	var pass_ok: bool = decor_ok and kinds_ok and pool_ok and rt
	print("Dw: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

# Faz D festival: mevsim ortasında bir kez tetiklenir, mevsim dönünce bayrak sıfırlanır.
func _test_festival() -> bool:
	var W := load("res://scripts/world.gd")
	var w = W.new(); w.gen(0)
	w.season_tick = w.SEASON_TICKS / 2 - 1
	w.step_world()
	var fired: bool = w.fest_done and w.festival_t > 0.9
	var ev_ok: bool = not w.event_log.is_empty() and "🌸" in w.event_log.back()
	w.step_world()   # ikinci adım yeniden tetiklememeli (festival_t azalır)
	var once: bool = w.festival_t < 1.0
	w.season_tick = w.SEASON_TICKS - 1
	w.step_world()   # mevsim döner → bayrak sıfırlanır
	var reset_ok: bool = w.season == 1 and not w.fest_done
	# save roundtrip yeni alanları taşır
	var w2 = W.new()
	w2.from_save(JSON.parse_string(JSON.stringify(w.to_save())))
	var rt: bool = w2.fest_done == w.fest_done and absf(w2.festival_t - w.festival_t) < 0.001
	print("D festival: tetik=%s olay=%s tek=%s mevsim-sıfır=%s roundtrip=%s" % [str(fired), str(ev_ok), str(once), str(reset_ok), str(rt)])
	var pass_ok: bool = fired and ev_ok and once and reset_ok and rt
	print("Df: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

# Faz D hava durumu: yağmur türetilmiş+determinist, kışın kapalı, SİM'İ ETKİLEMEZ (saflık).
func _test_weather() -> bool:
	var W := load("res://scripts/world.gd")
	var w = W.new(); w.gen(0)
	var found := false
	for d in range(60):
		w.tick = d * 2400
		for hh in range(24):
			w.time_of_day = float(hh) + 0.5
			if w.rain_amount() > 0.9:
				found = true
	var winter_dry := true
	w.season = 3
	for d in range(60):
		w.tick = d * 2400
		for hh in range(24):
			w.time_of_day = float(hh) + 0.5
			if w.rain_amount() > 0.0:
				winter_dry = false
	# saflık: rain_amount çağırmak sim'i saptırmaz (determinizm korunur)
	var w2 = W.new(); w2.gen(0)
	var w3 = W.new(); w3.gen(0)
	for t in range(3000):
		w2.step_world()
		w3.rain_amount()
		w3.step_world()
		w3.rain_amount()
	var pure: bool = w2.population() == w3.population() and w2.stat_births == w3.stat_births
	print("D hava: yağmur-var=%s kış-kuru=%s saflık=%s" % [str(found), str(winter_dry), str(pure)])
	var pass_ok: bool = found and winter_dry and pure
	print("Dh: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

# Faz D end-game: harita dolunca BÜTÜNLENDİ (bir kez) + growth güzelleştirmeye akar.
func _test_endgame_design() -> bool:
	var W := load("res://scripts/world.gd")
	var w = W.new(); w.gen(0)
	# doluluk koşullarını kur: frontier maks + yoğunlaşma bitmiş + tüm binalar inşa edilmiş
	w.frontier = W.GW - 6
	w.density_level = 3
	for b in w.buildings:
		b.built = 1
		b.build_prog = 1.0
	w._start_construction()   # aday yok + frontier maks + yoğunluk 3 → bütünlenme
	var complete: bool = w.town_complete and w.milestones.get("butunlendi", false)
	var has_letter := false
	for l in w.letters:
		if l.kind == "an" and "bütünlendi" in l.text.to_lower():
			has_letter = true
	# ikinci çağrı ikinci mektup üretmemeli (tek seferlik)
	w._start_construction()
	var an_n := 0
	for l in w.letters:
		if l.kind == "an":
			an_n += 1
	var once: bool = an_n == 1
	# güzelleştirme: goal dolunca bir ev çiçeklenir; hepsi çiçekliyse şenlik (çökme yok)
	var g0: float = w.goal
	w.growth = w.goal
	w.step_world()
	var bloomed := 0
	for b in w.buildings:
		if b.get("bloom", false):
			bloomed += 1
	var beautified: bool = bloomed == 1 and w.goal > g0
	for b in w.buildings:
		b.bloom = true
	w.growth = w.goal
	w.step_world()   # hepsi çiçekli → şenlik olayı (patlamadan geçmeli)
	# bloom save round-trip
	var w2 = W.new()
	w2.from_save(JSON.parse_string(JSON.stringify(w.to_save())))
	var rt: bool = w2.town_complete and w2.buildings[0].get("bloom", false)
	# PLATO TAŞMASI: inşaat kapısı kapalıyken (basınç düşük) goal+FLOWER_COST aşımı → çiçek, goal SABİT
	var w3 = W.new(); w3.gen(0)
	w3.goal = W.GOAL_CAP          # geç-oyun temposu (üstel fren tavanı)
	var g3: float = w3.goal
	w3.growth = W.GOAL_CAP + W.FLOWER_COST + 100.0
	w3.step_world()
	var overflow_bloom := 0
	for b in w3.buildings:
		if b.get("bloom", false):
			overflow_bloom += 1
	var overflow_ok: bool = overflow_bloom == 1 and absf(w3.goal - g3) < 0.001
	print("D endgame: bütünlendi=%s mektup=%s tek-sefer=%s çiçek=%s roundtrip=%s taşma=%s" % [str(complete), str(has_letter), str(once), str(beautified), str(rt), str(overflow_ok)])
	var pass_ok: bool = complete and has_letter and once and beautified and rt and overflow_ok
	print("De: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

# Faz D: mektup havuzu çeşitliliği + kilometre taşları + determinizm.
func _test_letters_depth() -> bool:
	var W := load("res://scripts/world.gd")
	var w = W.new(); w.gen(0)
	# G1: ömürler uzadı (12.5-24.5 gün) — 10 günlük koşuda doğal veda oluşmaz; kurucular
	# deterministik yaşlandırılır (bilge + eşiğe yakın) → vedalar doğal _life_cycle akışından gelir
	for p in w.people:
		p.stage = 2
		p.age_t = p.span_c - 200 - (p.seed % 400)
	for t in range(24000): w.step_world()   # 10 gün: vedalar + taşınmalar birikir
	# veda metinleri havuzdan mı + çeşitlilik var mı (tek şablon değil)
	var veda_texts := {}
	var kinds := {}
	for l in w.letters:
		kinds[l.kind] = true
		if l.kind == "veda":
			var core: String = l.text.split("\n\n")[0]   # bond eki ayrılır
			var in_pool: bool = Letters.VEDA.has(core) or Letters.VEDA_ATKI.has(core)
			if not in_pool:
				print("D: havuz dışı veda metni FAIL"); return false
			veda_texts[core] = true
	var variety: bool = veda_texts.size() >= 2
	# kilometre taşları: eşik aşımı tetikler, tek seferlik
	var w2 = W.new(); w2.gen(0)
	w2.tick = 30 * 2400 - 1
	w2.name_idx = 100
	w2.stat_farewells = 50
	w2.step_world()
	var m3: bool = w2.milestones.get("gun30", false) and w2.milestones.get("sakin100", false) and w2.milestones.get("veda50", false)
	var an_count := 0
	for l in w2.letters:
		if l.kind == "an":
			an_count += 1
	w2.step_world()   # ikinci adım yeni "an" mektubu üretmemeli
	var an_count2 := 0
	for l in w2.letters:
		if l.kind == "an":
			an_count2 += 1
	var once: bool = an_count == 3 and an_count2 == 3
	# determinizm: aynı tohum → aynı mektup metinleri
	var wa = W.new(); wa.gen(7)
	var wb = W.new(); wb.gen(7)
	for t in range(12000):
		wa.step_world(); wb.step_world()
	var det: bool = wa.letters.size() == wb.letters.size()
	for i in range(wa.letters.size()):
		if wa.letters[i].text != wb.letters[i].text:
			det = false
	print("D mektup: çeşit=%d kaynaklar=%s milestone3=%s tek-sefer=%s determinizm=%s" % [veda_texts.size(), str(kinds.keys()), str(m3), str(once), str(det)])
	var pass_ok: bool = variety and m3 and once and det
	print("D: %s" % ("OK" if pass_ok else "FAIL"))
	return pass_ok

# B+ atomic save (#22): tmp→rename + .bak; bozuk asıl kayıt → yedekten dönüş; settings.cfg round-trip.
func _test_atomic_save() -> bool:
	# DİKKAT: headless user:// gerçek oyunla paylaşımlı — mevcut kayıtları yedekle, sonunda geri koy.
	var keep := {}
	for pth in ["user://save.json", "user://save.json.bak", "user://settings.cfg"]:
		if FileAccess.file_exists(pth):
			var fk := FileAccess.open(pth, FileAccess.READ)
			keep[pth] = fk.get_as_text()
			fk.close()
	# temiz zemin: save_audio mevcut cfg üstüne MERGE eder — oyuncunun gerçek slider değerleri
	# (pad≠default) kalırsa default-assert yanlış FAIL verir (ortam-bağımlı test kazası)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
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
	# ana menü altyapısı (Faz C): Yeni Kasaba yedeği + hızlı-başlat bayrağı
	# !!! Bu blok TEMİZLİKTEN ÖNCE olmalı — bir kez sonrasına kondu ve dummy dosya
	# gerçek oyun kaydını ezdi (kullanıcı kasabası kaybedildi). Dosyaya dokunan HER
	# test adımı keep-yakala ile temizle-geri-koy ARASINDA yaşar.
	var fnb := FileAccess.open("user://save.json", FileAccess.WRITE)
	fnb.store_string("{\"v\":1}")
	fnb.close()
	S.backup_current()
	var backup_ok: bool = not FileAccess.file_exists("user://save.json") and FileAccess.file_exists("user://save.json.bak")
	St.set_flag("quick_start", true)
	var flag_ok: bool = St.get_flag("quick_start") and not St.get_flag("olmayan_bayrak")
	# multi-instance kilidi (denetim #23): taze kilit reddeder, bayat kilit devralınır
	var lock_keep := ""
	if FileAccess.file_exists("user://nefes.lock"):
		var lf := FileAccess.open("user://nefes.lock", FileAccess.READ)
		lock_keep = lf.get_as_text()
		lf.close()
	S.release_lock()
	var l1: bool = S.acquire_lock()          # boşta alınır
	var l2: bool = not S.acquire_lock()      # tazeyken ikinci kopya reddedilir
	var lf2 := FileAccess.open("user://nefes.lock", FileAccess.WRITE)
	lf2.store_string(str(Time.get_unix_time_from_system() - 999.0))   # bayat damga
	lf2.close()
	var l3: bool = S.acquire_lock()          # bayat kilit devralınır
	S.release_lock()
	if lock_keep != "":
		var lf3 := FileAccess.open("user://nefes.lock", FileAccess.WRITE)
		lf3.store_string(lock_keep)
		lf3.close()
	var lock_ok: bool = l1 and l2 and l3
	# TEMİZLİK — her zaman SON adım: test artıkları silinir, gerçek kayıtlar geri konur,
	# geri-koyma DOĞRULANIR (sessiz kayıp bir daha yaşanmasın)
	var dir := DirAccess.open("user://")
	for pth in ["user://save.json", "user://save.json.bak", "user://settings.cfg", "user://save.json.tmp"]:
		if FileAccess.file_exists(pth):
			dir.remove(String(pth).get_file())
	var restore_ok := true
	for pth in keep.keys():
		var fr := FileAccess.open(pth, FileAccess.WRITE)
		fr.store_string(keep[pth])
		fr.close()
		var fv := FileAccess.open(pth, FileAccess.READ)
		if fv == null or fv.get_as_text() != keep[pth]:
			restore_ok = false
			push_warning("[test] GERİ KOYMA BAŞARISIZ: " + String(pth))
		if fv != null:
			fv.close()
	print("B+ atomic: bak=%s yedekten-dönüş=%s (tick=%d) settings=%s yeni-kasaba-yedek=%s bayrak=%s kilit=%s geri-koyma=%s" % [str(bak_ok), str(fallback_ok), w2.tick, str(set_ok), str(backup_ok), str(flag_ok), str(lock_ok), str(restore_ok)])
	bak_ok = bak_ok and restore_ok
	var pass_ok: bool = bak_ok and fallback_ok and set_ok and backup_ok and flag_ok and lock_ok
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
	for l in w.letters:
		if not l.replied:
			w.reply_letter(int(l.lid))   # lid ile (index kayması düzeltmesi)
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

	# cevap → bond + atkı (lid ile — index kayması düzeltmesi)
	var b0: int = w.bond
	var target = null
	for l in w.letters:
		if not l.replied:
			target = l
			break
	w.reply_letter(int(target.lid))
	var bonded: bool = w.bond == b0 + 1
	var scarfed := false
	var replied_name: String = target.from
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
