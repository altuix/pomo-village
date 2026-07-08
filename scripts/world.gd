class_name World
extends RefCounted
## NEFES saf sim (ANAYASA: sim render'dan ayrı, saf, test edilebilir; node okumaz).
## HTML v15 gen()/stepWorld() gridi buraya taşındı. Tüm rastgelelik _h/_hf'ten (randi/randf YOK).
## Grid koordinatları; piksel/easing/kozmetik (kuş/bulut/kar) render'ın (town_view) işi.
## A0 kapsamı: dünya üretimi + büyüme→inşaat + yürüyüş + gece eğrisi. Yaşam döngüsü = A1.

const GW := 64
const GH := 26
const TICKS_PER_DAY := 2400

# --- tohum (salt): aynı tohum = aynı kasaba. salt=0 → HTML-özdeş ayar davranışı. ---
var _salt := 0
func _h(x: int) -> int: return Rng.h(x ^ _salt)
func _hf(x: int) -> float: return float(_h(x) % 10000) / 10000.0

# --- dünya durumu ---
var tick := 0
var time_of_day := 17.2
var season := 0
var season_tick := 0
var frontier := 0
var growth := 0.0
var goal := 12.0
var growth_mult := 1.0            # A3 odak seansı ×1.5
var light_curve := 0.0
var last_hour := -1
var chime_t := 0.0

var road_set := {}                # Vector2i -> true
var road_list: Array[Vector2i] = []
var river: Array[Vector2i] = []
var river_set := {}
var plaza_cells: Array[Vector2i] = []
var landmark := Vector2i(11, 13)
var buildings: Array = []         # Array[Dictionary]
var lamps: Array = []
var trees: Array = []
var fountains: Array = []
var people: Array = []            # Array[Dictionary]
var mem_trees: Array = []
var decor: Array = []             # dilek objeleri: bank/kuş yuvası/posta kutusu/rüzgâr gülü {gx,gy,kind}
var movers: Array = []            # people dict ref'leri
var building_now = null           # yükselen bina (Dictionary) ya da null

# --- istatistik sayaçları (offline özet + albüm için) ---
var stat_births := 0
var stat_farewells := 0
var stat_arrivals := 0
var stat_wishes := 0   # gerçekleşen dilekler (albüm: kurulan objeler gen objeleriyle aynı listede — sayaç ayırt eder)

# --- isim / olay / mektup (A1) ---
var name_idx := 0
var event_log: Array[String] = []      # son ~5 olay (UI: A7)
var letters: Array = []                # {from, text, kind, replied} — kaynak veda (A1); dilek/odak + UI = A4

# --- odak seansı + seri (A3; B+ istatistik + kalıcılık) ---
var streak := 0
var sessions := 0
var unlocked := { "atolye": false, "kutuphane": false }
var best_streak := 0
var stat_focus_min := 0          # toplam odak dakikası
var today_focus_min := 0
var focus_day := -1              # YYYYMMDD; SERİ TANIMI: aynı gün art arda, gün değişince nazik sıfır (kazanılan kalır)
# aktif seans kalıcılığı (main yazar/yorumlar; sim OKUMAZ — kapanışta seans yanmasın)
var focus_until := 0.0           # unix bitiş zamanı
var focus_phase := ""            # "" | "work" | "break"
var focus_mode := 0

# --- kule melodisi (A5) ---
var melody: Array = [0, 2, 4, 2, -1, 3, 1, 0]
var melody_saved := false
var concert_done := false

# --- dilek + bond (A4) ---
var wish = null                        # {"who": person, "type": idx} ya da null
var bond := 0
var milestones := {}                   # uzun-vade anları (gun30/sakin100/veda50/butunlendi — tek seferlik)
var town_complete := false             # harita doldu: growth artık güzelleştirmeye akar (end-game, Faz D)
# teşekkür metinleri Letters.DILEK havuzunda (tek kaynak; Faz D çeşitlilik)
const WISH_TYPES := [
	{ "k": "çeşme", "txt": "meydana küçük bir çeşme" },
	{ "k": "ağaç",  "txt": "sokağıma bir ağaç" },
	{ "k": "fener", "txt": "kapımın önüne bir fener" },
	{ "k": "bank",  "txt": "ağacın altına bir bank" },
	{ "k": "kuş yuvası", "txt": "bahçeme bir kuş yuvası" },
	{ "k": "posta kutusu", "txt": "kapıma bir posta kutusu" },
	{ "k": "rüzgâr gülü", "txt": "çatıma bir rüzgâr gülü" },
]

const SEASON_NAMES := ["ilkbahar", "yaz", "sonbahar", "kış"]
const FLOWER_COST := 2400.0       # bir çiçeğin emeği (~3 oyun-günü growth; plato ödül temposu)
const FLOWER_OVERFLOW := 7200.0   # taşma kanalı yalnız goal bunu aşınca (plato) açılır
var rain_was := false             # yağmur geçiş olayı için (save'e girmez; tek sahte geçiş zararsız)
var festival_t := 0.0             # festival nabzı 1→0 (render gözlemler; chime_t deseni)
var fest_done := false            # bu mevsim festivali oldu mu (mevsim dönünce sıfırlanır)
const FEST_EVENTS := ["🌸 Çiçek Günü — meydan taçyaprağı içinde", "💧 Dere Şenliği — kâğıt kayıklar yarışıyor",
	"🎃 Hasat Akşamı — meydanda uzun sofra kuruldu", "🏮 Fener Gecesi — ışıklar karda süzülüyor"]

func population() -> int:
	return people.size()

func town_seed() -> int:
	return _salt   # kartpostal/paylaşım: aynı tohum = aynı kasaba

func clock_string() -> String:
	var hh := int(floor(time_of_day))
	var mm := int(floor(fmod(time_of_day, 1.0) * 60.0))
	return "%02d:%02d" % [hh, mm]

func status_text() -> String:
	if building_now != null:
		return "yeni bir ev yükseliyor…"
	if not movers.is_empty():
		return "biri taşınıyor…"
	var ev := evening()
	if ev > 0.7:
		return "kasaba ışıl ışıl"
	if ev > 0.3:
		return "akşam çöküyor, ışıklar yanıyor"
	if ev > 0.0:
		return "huzurlu bir akşamüstü"
	return "huzurlu bir gün"   # öğlen "akşam" yazıyordu (HTML port kalıntısı)

func unreplied_letters() -> int:
	var n := 0
	for l in letters:
		if not l.replied:
			n += 1
	return n

# ============================================================ ÜRETİM
func gen(seed_val: int = 0) -> void:
	_salt = seed_val
	tick = 0
	time_of_day = 17.2
	season = 0
	season_tick = 0
	growth = 0.0
	goal = 12.0
	growth_mult = 1.0
	last_hour = -1
	chime_t = 0.0
	road_set = {}
	road_list = []
	river = []
	river_set = {}
	plaza_cells = []
	buildings = []
	lamps = []
	trees = []
	fountains = []
	people = []
	mem_trees = []
	decor = []
	movers = []
	building_now = null
	name_idx = 0
	event_log = []
	letters = []
	wish = null
	bond = 0
	milestones = {}
	town_complete = false
	streak = 0
	sessions = 0
	unlocked = { "atolye": false, "kutuphane": false }
	best_streak = 0
	stat_focus_min = 0
	today_focus_min = 0
	focus_day = -1
	focus_until = 0.0
	focus_phase = ""
	focus_mode = 0
	melody = [0, 2, 4, 2, -1, 3, 1, 0]
	melody_saved = false
	concert_done = false
	stat_births = 0
	stat_farewells = 0
	stat_arrivals = 0
	stat_wishes = 0
	rain_was = false
	festival_t = 0.0
	fest_done = false

	frontier = int(floor(GW * 0.30))

	# nehir (sinüs, 2 hücre)
	for gy in range(GH):
		var cx := 2 + int(round(sin(gy * 0.35) * 1.2))
		for k in range(2):
			var rc := Vector2i(cx + k, gy)
			river.append(rc)
			river_set[rc] = true

	_build_road_network(GW)

	var spine_y := int(floor(GH * 0.5))
	landmark = Vector2i(int(floor(frontier * 0.6)), spine_y)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			plaza_cells.append(landmark + Vector2i(dx, dy))

	# yol-kenarı binalar (organik, bağlı)
	var occ := {}
	for r in road_list:
		if r.x >= frontier:
			continue
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var b: Vector2i = r + d
			if b.x < 5 or b.y < 1 or b.x >= frontier or b.y >= GH - 1:
				continue
			if road_set.has(b) or river_set.has(b) or occ.has(b):
				continue
			if plaza_cells.has(b):
				continue
			if _hf(b.x * 97 + b.y * 61) < 0.45:   # boşluk → bahçe/ağaç
				continue
			occ[b] = true
			var shop := _hf(b.x * 3 + b.y * 7) < 0.18
			_add_building(b.x, b.y, shop)

	# yalnız küçük çekirdek uyanık başlar; kalanı zamanla inşa/uyanır
	buildings.sort_custom(func(a, b): return (a.gx * GH + a.gy) < (b.gx * GH + b.gy))
	for i in range(buildings.size()):
		var b: Dictionary = buildings[i]
		b.awake = i < 6
		b.built = 1 if i < 6 else 0
		b.lit_frac = 0.0
		b.build_prog = 1.0 if b.awake else 0.0

	# ağaçlar bahçe boşluklarını doldurur
	for gx in range(5, frontier):
		for gy in range(1, GH - 1):
			var c := Vector2i(gx, gy)
			if occ.has(c) or road_set.has(c) or river_set.has(c) or plaza_cells.has(c):
				continue
			if _hf(gx * 31 + gy * 17) < 0.12:
				trees.append({"gx": gx, "gy": gy, "s": _h(gx * 7 + gy) % 3, "sway": _hf(gx + gy)})

	# lambalar yol üzerinde
	for r in road_list:
		if r.x < frontier and _h(r.x * 7 + r.y * 13) % 5 == 0:
			lamps.append({"gx": r.x, "gy": r.y, "ph": _hf(r.x * r.y) * TAU})

	# çekirdek: 2 küçük aile (2'şer kişi) uyanık evlerde
	var core := []
	for b in buildings:
		if b.awake and b.type == "house":
			core.append(b)
			if core.size() >= 2:
				break
	for hb in core:
		hb.cap = maxi(3, hb.cap)
		for k in range(2):
			var p := _add_person(hb.gx, hb.gy, hb, 1)
			hb.members.append(p)

func _build_road_network(max_x: int) -> void:
	road_set = {}
	road_list = []
	var spine_y := int(floor(GH * 0.5))
	# omurga: tüm harita boyunca hafif meandering, 2 hücre kalın
	for gx in range(GW):
		var y := spine_y + int(round(sin(gx * 0.18) * 2.0))
		_add_road(gx, y)
		_add_road(gx, y + 1)
	# dikey dal sokakları (yalnız kasaba alanında)
	var bx := 8
	while bx < max_x:
		var length := 4 + _h(bx * 7) % 6
		var dir := 1 if (_h(bx) % 2) else -1
		var x := bx
		var y := spine_y
		for s in range(length):
			y += dir
			if y < 2 or y >= GH - 2:
				break
			x += (_h(bx * 13 + s) % 3) - 1
			_add_road(x, y)
		bx += 6 + (_h(bx) % 3)
	# birkaç yatay ara sokak
	var by := 4
	while by < GH - 3:
		if abs(by - spine_y) >= 3:
			var x0 := 8 + _h(by) % 6
			var x1 := mini(max_x, x0 + 8 + _h(by * 3) % 10)
			var yy := by
			for x in range(x0, x1):
				yy += (_h(x * by) % 3) - 1
				yy = clampi(yy, 2, GH - 3)
				_add_road(x, yy)
		by += 7

func _add_road(x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= GW or y >= GH:
		return
	var c := Vector2i(x, y)
	if not road_set.has(c):
		road_set[c] = true
		road_list.append(c)

func _add_building(gx: int, gy: int, shop: bool) -> void:
	buildings.append({
		"gx": gx, "gy": gy,
		"roof_type": _h(gx + gy * 3) % 3,
		"roof": _h(gx * 17 + gy * 7) % 5,
		"seed": _h(gx * 99 + gy),
		"type": "shop" if shop else "house",
		"chimney": _h(gx * 7 + gy) % 3 == 0,
		"awake": false, "built": 0, "build_prog": 0.0, "lit_frac": 0.0, "bloom": false,
		"cap": 2 + (_h(gx * 13 + gy * 7) % 3),   # HANE kapasitesi 2-4
		"members": [],
	})

func _add_person(gx: int, gy: int, home, stage: int) -> Dictionary:
	var seed := _h((people.size() + 1) * 99 + tick * 7)
	var p := {
		"x": float(gx), "y": float(gy), "tx": gx, "ty": gy,
		"col": _h(seed * 31) % 6, "seed": seed, "moving": false,
		"home": home, "name": Names.at(name_idx), "stage": stage, "age_t": 0,
		"span_a": 2000 + _h(seed) % 900,          # çocuk→yetişkin (~1 gün)
		"span_b": 7000 + _h(seed * 3) % 9000,     # yetişkin→bilge (~3-6.5 gün, geniş varyans)
		"span_c": 4500 + _h(seed * 7) % 2500,     # bilge→veda (~2-3 gün)
		"wants_home": false, "steps": 0, "scarf": false,
	}
	people.append(p)
	name_idx += 1
	return p

# ============================================================ HANE YARDIMCILARI
func total_cap() -> int:
	var c := 0
	for b in buildings:
		if b.built == 1 and b.type == "house":
			c += int(b.cap)
	return c

func housing_pressure() -> float:
	var c := total_cap()
	return 1.0 if c == 0 else float(people.size()) / float(c)

func empty_houses() -> Array:
	var out := []
	for b in buildings:
		if b.built == 1 and b.type == "house" and b.members.is_empty():
			out.append(b)
	return out

func lit_count() -> int:
	var n := 0
	for b in buildings:
		if b.awake:
			n += 1
	return n

# ============================================================ SİM ADIMI
func step_world() -> void:
	tick += 1
	time_of_day = fmod(17.2 + float(tick) / TICKS_PER_DAY * 24.0, 24.0)
	season_tick += 1
	if season_tick >= 1200:
		season_tick = 0
		season = (season + 1) % 4
		fest_done = false
	var ev := evening()

	# pencere programı: akşam yanar, 23-05 UYKU (ışık bütçesi)
	var t24 := time_of_day
	var sleep := 0.0
	if t24 >= 23.0 or t24 < 5.0:
		sleep = minf(1.0, ((t24 - 23.0) if t24 >= 23.0 else (t24 + 1.0)) / 2.0)
	light_curve = ev * (1.0 - sleep * 0.55)
	for b in buildings:
		if b.awake:
			var t := (0.04 + ev * 0.72) * (1.0 - sleep * 0.85)
			b.lit_frac += (t - b.lit_frac) * 0.03

	# yükselen bina
	if building_now != null:
		building_now.build_prog = minf(1.0, building_now.build_prog + 0.02)
		if building_now.build_prog >= 1.0:
			building_now.built = 1
			_queue_move_in(building_now)
			building_now = null

	# taşınanlar yürür
	for m in movers.duplicate():
		_step_mover(m)

	# büyüme birikir; KULLANICI ÇALIŞTIKÇA (odak) ×1.5
	growth += (0.28 + ev * 0.22) * growth_mult
	var homeless := false
	for p in people:
		if p.wants_home and not p.moving:
			homeless = true
			break
	# KURAL: inşaat yalnız konut sıkışıklığında (Banished dersi). goal ×1.18 KORUNUR:
	# yumuşak eğri (×1.10) denendi — harita doluyor ama nüfus kapasiteyi takip edip 94-104'e
	# taşıyor (20-90 bandı kırılıyor). Çözüm bant dengesine dokunmaz: platoda biriken fazla
	# emek ÇİÇEĞE akar (aşağıda taşma kanalı) — "growth boşa akar" şikâyeti görünür ödüle döner.
	# PLATO TAŞMASI: goal üstel şişmişken (aktif büyüme bitti) biriken emek çiçeğe akar —
	# sabit maliyet (goal'e bağlı değil; 3×goal eşiği denendi: 365 günde hiç tetiklenmiyordu).
	# Plato ~gün 100'de başlar → ~3 günde bir çiçek; aktif büyüme fazı etkilenmez (goal küçükken kapalı).
	if goal > FLOWER_OVERFLOW and growth >= FLOWER_OVERFLOW and not town_complete:
		growth -= FLOWER_COST
		_beautify()
	if growth >= goal:
		if town_complete:
			# END-GAME (Faz D): kasaba bütünlendi — emek güzelleştirmeye akar (cozy: bitiş duvarı yok)
			growth -= goal
			goal *= 1.10
			_beautify()
		elif building_now == null and (housing_pressure() >= 0.75 or (homeless and empty_houses().is_empty())):
			growth -= goal
			goal *= 1.18
			_start_construction()


	_move_people()
	_life_cycle()

	# DİLEK: arada bir yetişkin bir şey diler (AL-5 nazik; zorlamasız)
	if wish == null and tick % 700 == 0:
		var cands := []
		for p in people:
			if p.stage == 1 and not p.moving:
				cands.append(p)
		if not cands.is_empty() and _hf(tick * 31) < 0.6:
			var who = cands[_h(tick) % cands.size()]
			wish = { "who": who, "type": _h(tick * 7) % WISH_TYPES.size() }
			_push_event("💭 %s bir dilek tuttu" % who.name)

	# MEVSİM FESTİVALİ (Faz D): mevsim ortasında küçük şenlik — sakinler meydana, olay + seyrek mektup.
	# Mevsimler hızlı döner (1200 tick) → mektup %15 şansla (spam değil, sürpriz kalsın).
	if season_tick == 600 and not fest_done:
		fest_done = true
		festival_t = 1.0
		_push_event(FEST_EVENTS[season])
		if _hf(tick * 43) < 0.15:
			_push_letter({ "from": "Kasaba halkı", "who": -1, "kind": "festival", "replied": false,
				"text": Letters.FESTIVAL[season] })
		for p in people:
			if not p.moving and _hf(p.seed + tick) < 0.4:
				p.x = clampf(landmark.x + float(_h(p.seed) % 7) - 3.0, 0.0, float(GW - 1))
				p.y = clampf(landmark.y + float(_h(p.seed * 3) % 7) - 3.0, 0.0, float(GH - 1))
	if festival_t > 0.0:
		festival_t -= 0.005   # ~200 tick şenlik nabzı

	# yağmur geçişleri (görsel/ses katmanının olay bildirimi; sim durumuna etkimez)
	var raining := rain_amount() > 0.1
	if raining and not rain_was:
		_push_event("🌧 kasabaya yağmur geldi")
	elif rain_was and not raining:
		_push_event("🌦 yağmur dindi — toprak kokusu")
	rain_was = raining

	# uzun-vade anları (Faz D): tek seferlik kutlamalar
	if tick >= 30 * TICKS_PER_DAY and not milestones.get("gun30", false):
		_milestone("gun30", "🕯 kasabanın 30. günü — meydanda mum ışığı")
	if name_idx >= 100 and not milestones.get("sakin100", false):
		_milestone("sakin100", "💯 100. komşu aramızda")
	if stat_farewells >= 50 and not milestones.get("veda50", false):
		_milestone("veda50", "🌳 50. anı ağacı — çayır artık bir koru")

	# saat başı: kule nabzı (görsel çan/kuş A2; melodi A5)
	var hr := int(floor(time_of_day))
	if hr != last_hour:
		last_hour = hr
		chime_t = 1.0
	if chime_t > 0.0:
		chime_t -= 0.02

# ============================================================ SAVE / LOAD (B1)
# Not: oyuncu etkileşimleri (dilek/mektup/odak/konser) dünyayı seed+tick'ten saptırır →
# saf replay yetmez, TAM durum serileştirilir. ref'ler index'e çevrilir; JSON int→float
# bozulmasına karşı yüklemede int-kritik alanlar zorlanır.
const _PERSON_INT := ["col", "seed", "stage", "age_t", "span_a", "span_b", "span_c", "steps", "tx", "ty", "home"]
const _BLD_INT := ["gx", "gy", "roof_type", "roof", "seed", "cap", "built"]

func _vec_list(arr: Array) -> Array:
	var out := []
	for v in arr:
		out.append([v.x, v.y])
	return out

func _to_vec_list(arr: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pair in arr:
		out.append(Vector2i(int(pair[0]), int(pair[1])))
	return out

func to_save() -> Dictionary:
	# Döngüsel ref (person.home ↔ building.members) → dict'i anahtar/karşılaştırma yapma (recursion!).
	# Geçici _sid index damgası ile identity üzerinden serileştir.
	for i in range(people.size()):
		people[i]["_sid"] = i
	for i in range(buildings.size()):
		buildings[i]["_sid"] = i
	var sp := []
	for p in people:
		var d: Dictionary = p.duplicate()
		d.erase("_sid")
		d.home = (p.home["_sid"] if p.home != null else -1)
		sp.append(d)
	var sb := []
	for b in buildings:
		var d: Dictionary = b.duplicate()
		d.erase("_sid")
		var mem := []
		for m in b.members:
			mem.append(m["_sid"])
		d.members = mem
		sb.append(d)
	var bn_idx: int = (building_now["_sid"] if building_now != null else -1)
	var wsh = ({ "who": wish.who["_sid"], "type": int(wish.type) } if wish != null else null)
	for p in people:
		p.erase("_sid")
	for b in buildings:
		b.erase("_sid")
	return {
		"v": 1, "seed": _salt, "tick": tick, "time_of_day": time_of_day,
		"season": season, "season_tick": season_tick, "frontier": frontier,
		"growth": growth, "goal": goal, "growth_mult": growth_mult,
		"light_curve": light_curve, "last_hour": last_hour, "chime_t": chime_t,
		"festival_t": festival_t, "fest_done": fest_done,
		"name_idx": name_idx, "bond": bond, "streak": streak, "sessions": sessions,
		"best_streak": best_streak, "stat_focus_min": stat_focus_min,
		"today_focus_min": today_focus_min, "focus_day": focus_day,
		"focus_until": focus_until, "focus_phase": focus_phase, "focus_mode": focus_mode,
		"unlocked": unlocked.duplicate(), "melody": melody.duplicate(),
		"melody_saved": melody_saved, "concert_done": concert_done,
		"stat_births": stat_births, "stat_farewells": stat_farewells, "stat_arrivals": stat_arrivals,
		"stat_wishes": stat_wishes,
		"landmark": [landmark.x, landmark.y],
		"road_list": _vec_list(road_list), "river": _vec_list(river), "plaza_cells": _vec_list(plaza_cells),
		"buildings": sb, "people": sp,
		"lamps": lamps.duplicate(true), "trees": trees.duplicate(true),
		"fountains": fountains.duplicate(true), "mem_trees": mem_trees.duplicate(true),
		"decor": decor.duplicate(true),
		"building_now": bn_idx,
		"wish": wsh,
		"letters": letters.duplicate(true),
		"milestones": milestones.duplicate(),
		"town_complete": town_complete,
		"last_exit": Time.get_unix_time_from_system(),
	}

func from_save(d: Dictionary) -> void:
	_salt = int(d.seed)
	tick = int(d.tick)
	time_of_day = float(d.time_of_day)
	season = int(d.season)
	season_tick = int(d.season_tick)
	frontier = int(d.frontier)
	growth = float(d.growth)
	goal = float(d.goal)
	# Odak seansı yüklemede restore edilmiyor → kaydedilen ×1.5 hayalet kalmasın (bug: growth_mult sızıntısı).
	growth_mult = 1.0
	light_curve = float(d.light_curve)
	last_hour = int(d.last_hour)
	chime_t = float(d.chime_t)
	festival_t = float(d.get("festival_t", 0.0))
	fest_done = bool(d.get("fest_done", false))
	name_idx = int(d.name_idx)
	bond = int(d.bond)
	streak = int(d.streak)
	sessions = int(d.sessions)
	# B+ alanları eski save'lerde yok → .get default (sessiz veri kaybı değil, bilinçli geriye-uyum)
	best_streak = int(d.get("best_streak", streak))
	stat_focus_min = int(d.get("stat_focus_min", 0))
	today_focus_min = int(d.get("today_focus_min", 0))
	focus_day = int(d.get("focus_day", -1))
	focus_until = float(d.get("focus_until", 0.0))
	focus_phase = str(d.get("focus_phase", ""))
	focus_mode = int(d.get("focus_mode", 0))
	unlocked = { "atolye": bool(d.unlocked.atolye), "kutuphane": bool(d.unlocked.kutuphane) }
	melody = []
	for n in d.melody:
		melody.append(int(n))
	melody_saved = bool(d.melody_saved)
	concert_done = bool(d.concert_done)
	stat_births = int(d.stat_births)
	stat_farewells = int(d.stat_farewells)
	stat_arrivals = int(d.stat_arrivals)
	stat_wishes = int(d.get("stat_wishes", 0))
	milestones = (d.get("milestones", {}) as Dictionary).duplicate()
	town_complete = bool(d.get("town_complete", false))
	landmark = Vector2i(int(d.landmark[0]), int(d.landmark[1]))
	road_list = _to_vec_list(d.road_list)
	road_set = {}
	for c in road_list:
		road_set[c] = true
	river = _to_vec_list(d.river)
	river_set = {}
	for c in river:
		river_set[c] = true
	plaza_cells = _to_vec_list(d.plaza_cells)
	# JSON tüm sayıları float yapar (kritik tuzak 2) → int-kritik alanlar burada da zorlanır
	# (roundtrip eşitliği + dizi indeksi güvenliği; endgame testi yakaladı)
	lamps = []
	for sd in d.lamps:
		var L: Dictionary = (sd as Dictionary).duplicate(true)
		L.gx = int(L.gx); L.gy = int(L.gy)
		lamps.append(L)
	trees = []
	for sd in d.trees:
		var T: Dictionary = (sd as Dictionary).duplicate(true)
		T.gx = int(T.gx); T.gy = int(T.gy); T.s = int(T.s)
		trees.append(T)
	fountains = []
	for sd in d.fountains:
		var F: Dictionary = (sd as Dictionary).duplicate(true)
		F.gx = int(F.gx); F.gy = int(F.gy)
		fountains.append(F)
	mem_trees = []
	for sd in d.mem_trees:
		var M: Dictionary = (sd as Dictionary).duplicate(true)
		M.gx = int(M.gx); M.gy = int(M.gy)
		mem_trees.append(M)
	decor = []
	for sd in d.get("decor", []):
		var DC: Dictionary = (sd as Dictionary).duplicate(true)
		DC.gx = int(DC.gx); DC.gy = int(DC.gy)
		decor.append(DC)
	letters = []
	for sd in d.letters:
		var L2: Dictionary = (sd as Dictionary).duplicate(true)
		L2.who = int(L2.get("who", -1))
		letters.append(L2)
	# binalar (members geçici olarak index)
	buildings = []
	for sd in d.buildings:
		var b: Dictionary = (sd as Dictionary).duplicate(true)
		for k in _BLD_INT:
			b[k] = int(b[k])
		buildings.append(b)
	# sakinler (home geçici olarak index)
	people = []
	for sd in d.people:
		var p: Dictionary = (sd as Dictionary).duplicate(true)
		for k in _PERSON_INT:
			p[k] = int(p[k])
		people.append(p)
	# ref relink
	for b in buildings:
		var mem := []
		for pi in b.members:
			var ii := int(pi)
			if ii >= 0 and ii < people.size():
				mem.append(people[ii])
		b.members = mem
	for p in people:
		var hi: int = p.home
		p.home = buildings[hi] if hi >= 0 and hi < buildings.size() else null
	var bn := int(d.building_now)
	building_now = buildings[bn] if bn >= 0 and bn < buildings.size() else null
	movers = []
	for p in people:
		if p.moving:
			movers.append(p)
	if d.wish == null:
		wish = null
	else:
		var wi := int(d.wish.who)
		wish = { "who": people[wi], "type": int(d.wish.type) } if wi >= 0 and wi < people.size() else null

## Doğrulama/capture: belirli bir saati sabitle + ışığı kararlı hale getir (deterministik).
func force_time(tod: float) -> void:
	time_of_day = tod
	var ev := evening()
	var t24 := time_of_day
	var sleep := 0.0
	if t24 >= 23.0 or t24 < 5.0:
		sleep = minf(1.0, ((t24 - 23.0) if t24 >= 23.0 else (t24 + 1.0)) / 2.0)
	light_curve = ev * (1.0 - sleep * 0.55)
	for b in buildings:
		if b.awake:
			b.lit_frac = (0.04 + ev * 0.72) * (1.0 - sleep * 0.85)

func evening() -> float:
	var t := time_of_day
	if t >= 8.0 and t < 17.0: return 0.0                 # gündüz
	if t >= 17.0 and t < 21.0: return (t - 17.0) / 4.0   # alacakaranlık
	if t >= 21.0 or t < 5.0: return 1.0                  # gece
	return 1.0 - (t - 5.0) / 3.0                          # şafak

## Hava durumu (Faz D denetim #19): görsel+ses katmanı — SİM'E ETKİMEZ (denge/determinizm korunur).
## Saf türetim: ~%28 gün yağmurlu (günlük hash), gün içinde 3-6 saatlik pencere, 30dk rampa.
## Kışın yağmur yok (kar zaten yağıyor).
func rain_amount() -> float:
	if season == 3:
		return 0.0
	var day := tick / TICKS_PER_DAY
	if _hf(day * 67 + 5) > 0.28:
		return 0.0
	var h0 := 6.0 + float(_h(day * 13) % 12)
	var dur := 3.0 + float(_h(day * 29) % 4)
	var dt_in := time_of_day - h0
	if dt_in < 0.0 or dt_in > dur:
		return 0.0
	return clampf(minf(dt_in / 0.5, (dur - dt_in) / 0.5), 0.0, 1.0)

## Kasaba uyku penceresi (23-05): kule de susar (ışık bütçesi ruhu; step_world sleep penceresiyle aynı).
func is_asleep() -> bool:
	return time_of_day >= 23.0 or time_of_day < 5.0

func _start_construction() -> void:
	var cand := []
	for b in buildings:
		if b.built == 0:
			cand.append(b)
	cand.sort_custom(func(a, b): return _dist(a) < _dist(b))
	if not cand.is_empty():
		building_now = cand[0]
		building_now.build_prog = 0.01
	elif frontier < GW - 8:
		_expand_frontier()
	elif not town_complete:
		# harita doldu + inşasız bina yok → KASABA BÜTÜNLENDİ (bir kez; growth güzelleştirmeye döner)
		town_complete = true
		_milestone("butunlendi", "🎊 KASABA BÜTÜNLENDİ — son ev de yuvasını buldu")

func _dist(b: Dictionary) -> int:
	return abs(b.gx - landmark.x) + abs(b.gy - landmark.y)

func _expand_frontier() -> void:
	var old := frontier
	frontier = mini(GW - 6, frontier + 5)
	var occ := {}
	for b in buildings:
		occ[Vector2i(b.gx, b.gy)] = true
	for r in road_list:
		if r.x < old or r.x >= frontier:
			continue
		for d in [Vector2i(0, -1), Vector2i(0, 1)]:
			var b: Vector2i = r + d
			if b.x < 5 or b.y < 1 or b.x >= frontier or b.y >= GH - 1:
				continue
			if road_set.has(b) or river_set.has(b) or occ.has(b):
				continue
			if _hf(b.x * 97 + b.y * 61) < 0.5:
				continue
			occ[b] = true
			_add_building(b.x, b.y, _hf(b.x * 3 + b.y * 7) < 0.18)
	for r in road_list:
		if r.x >= old and r.x < frontier and _h(r.x * 7 + r.y * 13) % 5 == 0:
			lamps.append({"gx": r.x, "gy": r.y, "ph": _hf(r.x * r.y) * TAU})

func _queue_move_in(b: Dictionary) -> void:
	# yeni ev: %60 aile taşınır, %40 boş kalır (kuşak/göç bekler)
	if b.type != "house":
		b.awake = true
		return
	if _hf(b.seed * 17) < 0.4:
		return   # sahibini bekliyor
	for k in range(2):
		var p := _add_person(landmark.x, landmark.y, b, 1)
		p.age_t = _h(p.seed * 11) % 3000
		p.tx = b.gx
		p.ty = b.gy
		p.moving = true
		p.steps = k * 2
		b.members.append(p)
		movers.append(p)
	stat_arrivals += 1
	if not b.members.is_empty():
		_maybe_move_letter(b.members[0], b.seed * 23 + tick)

func _step_mover(p: Dictionary) -> void:
	p.steps += 1
	var d0: float = abs(p.x - p.tx) + abs(p.y - p.ty)
	if d0 <= 1.0 or p.steps > 90:
		p.x = float(p.tx)
		p.y = float(p.ty)
		p.moving = false
		if p.home != null and not p.home.awake:
			p.home.awake = true
		movers.erase(p)
		return
	# mesafeyi azaltan yol hücrelerini tercih et (nehir geçilmez — 90 adım emniyeti yine de var)
	var cand := []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = int(p.x) + d.x
		var ny: int = int(p.y) + d.y
		if nx >= 0 and ny >= 0 and nx < GW and ny < GH and not river_set.has(Vector2i(nx, ny)):
			cand.append(Vector2i(nx, ny))
	var better := []
	for c in cand:
		if abs(c.x - p.tx) + abs(c.y - p.ty) < d0:
			better.append(c)
	var road := []
	for c in better:
		if road_set.has(c):
			road.append(c)
	var pick: Array = road if not road.is_empty() else (better if not better.is_empty() else cand)
	if not pick.is_empty():
		var o: Vector2i = pick[_h(p.seed + p.steps) % pick.size()]
		p.x = float(o.x)
		p.y = float(o.y)

func _move_people() -> void:
	# gündüz rutini: gündüz sakinler evde/az gezer, akşam sokağa dökülür (DEVIR eksik giderildi)
	var move_chance := 0.12 + evening() * 0.40
	for p in people:
		if p.moving:
			continue
		if _hf(p.seed + tick) < move_chance:
			var opts := []
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = int(p.x) + d.x
				var ny: int = int(p.y) + d.y
				if nx >= 0 and ny >= 0 and nx < GW and ny < GH and road_set.has(Vector2i(nx, ny)):
					opts.append(Vector2i(nx, ny))
			if not opts.is_empty():
				var o: Vector2i = opts[_h(p.seed + tick) % opts.size()]
				p.x = float(o.x)
				p.y = float(o.y)
		p.x = clampf(p.x, 0.0, float(frontier))
		p.y = clampf(p.y, 0.0, float(GH - 1))

# ============================================================ YAŞAM DÖNGÜSÜ (A1)
func _push_event(t: String) -> void:
	event_log.append(t)
	if event_log.size() > 5:
		event_log.pop_front()

## Mektup tavanı (denetim #27: sınırsız büyüme = uzun save şişmesi). Tavan aşılınca önce
## en eski YANITLANMIŞ düşer (duygusal çekirdek yanıtsızlar korunur); kalıcı arşiv = albüm (Faz C).
const LETTER_CAP := 100
func _push_letter(l: Dictionary) -> void:
	letters.push_front(l)
	if letters.size() <= LETTER_CAP:
		return
	for i in range(letters.size() - 1, -1, -1):
		if letters[i].replied:
			letters.remove_at(i)
			return
	letters.pop_back()   # hepsi yanıtsızsa en eskisi düşer (sınır sınırdır)

## Taşınma mektubu (Faz D): yeni yuva kuran/gelen %35 şansla yazar (3 çağrı yeri: aile/kuşak/göç).
func _maybe_move_letter(p: Dictionary, salt: int) -> void:
	if _hf(salt) < 0.35:
		_push_letter({ "from": p.name, "who": p.seed, "kind": "taşınma", "replied": false,
			"text": Letters.pick(Letters.TASINMA, _h(salt * 13)) })

## Uzun-vade anı (Faz D): tek seferlik kutlama mektubu + olay.
func _milestone(key: String, ev_text: String) -> void:
	if milestones.get(key, false):
		return
	milestones[key] = true
	_push_letter({ "from": "Kasaba halkı", "who": -1, "kind": "an", "replied": false, "text": Letters.AN[key] })
	_push_event(ev_text)

## End-game güzelleştirme (Faz D): her goal bir evi çiçeklendirir; hepsi çiçekliyse nazik şenlik.
## Cozy ilke: "bitti" duvarı yok — kasaba tamamlandıktan sonra emek görünür küçük ödüllere akar.
func _beautify() -> void:
	for b in buildings:
		if b.built == 1 and not b.get("bloom", false):
			b.bloom = true
			_push_event("🌸 bir evin pencereleri çiçeklendi")
			return
	_push_event("🎪 meydanda küçük bir şenlik kuruldu")

func _life_cycle() -> void:
	# yaşlanma + nazik veda (determinist tohumlu)
	for p in people.duplicate():
		if p.moving:
			continue
		p.age_t += 1
		if p.stage == 0 and p.age_t > p.span_a:
			p.stage = 1
			p.age_t = 0
			p.wants_home = true
			_push_event("🌿 %s büyüdü, kendine yuva arıyor" % p.name)
		elif p.stage == 1 and p.age_t > p.span_b:
			p.stage = 2
			p.age_t = 0
			_push_event("🕰 %s artık kasabanın bilgesi" % p.name)
		elif p.stage == 2 and p.age_t > p.span_c:
			_pass_away(p)

	# KUŞAK: büyüyen çocuk boş bir eve taşınır → yeni hane
	if tick % 40 == 0:
		var seeker = null
		for p in people:
			if p.wants_home and not p.moving and p.stage == 1:
				seeker = p
				break
		if seeker != null:
			var eh := empty_houses()
			if not eh.is_empty():
				var nb: Dictionary = eh[0]
				if seeker.home != null:
					seeker.home.members.erase(seeker)
				seeker.home = nb
				nb.members.append(seeker)
				seeker.tx = nb.gx
				seeker.ty = nb.gy
				seeker.moving = true
				seeker.steps = 0
				movers.append(seeker)
				seeker.wants_home = false
				_push_event("🏡 %s kendi yuvasına taşındı" % seeker.name)
				_maybe_move_letter(seeker, seeker.seed * 41 + tick)

	# GÖÇ: boş ev + gevşek nüfus → yeni aile (kasaba asla ölmez; boşsa hızlanır)
	var mig_every := 400 if housing_pressure() < 0.45 else 800
	if tick % mig_every == 0 and housing_pressure() < 0.75:
		var eh := empty_houses()
		if not eh.is_empty() and _hf(tick * 13) < 0.5:
			var nb: Dictionary = eh[0]
			for k in range(2):
				var p := _add_person(0, int(floor(GH * 0.5)), nb, 1)
				p.age_t = _h(p.seed * 11) % 3000
				p.tx = nb.gx
				p.ty = nb.gy
				p.moving = true
				p.steps = k * 2
				nb.members.append(p)
				movers.append(p)
			stat_arrivals += 1
			_push_event("🧳 uzaktan yeni bir aile geldi")
			if not nb.members.is_empty():
				_maybe_move_letter(nb.members[0], nb.seed * 29 + tick)

	# DOĞUM (Banished): 2+ yetişkinli, yeri olan evde yavaş şans; tek doğum/kontrol
	if tick % 40 == 0:
		for b in buildings:
			if b.built != 1 or b.type != "house":
				continue
			var adults := 0
			for m in b.members:
				if m.stage == 1:
					adults += 1
			if adults >= 2 and b.members.size() < int(b.cap) and _hf(b.seed + tick) < 0.10:
				var c := _add_person(b.gx, b.gy, b, 0)
				b.members.append(c)
				stat_births += 1
				_push_event("🌱 %s dünyaya geldi" % c.name)
				if _hf(b.seed * 5 + tick) < 0.30:
					for m in b.members:
						if m.stage == 1:   # mektup ebeveynden gelir
							_push_letter({ "from": m.name, "who": m.seed, "kind": "doğum", "replied": false,
								"text": Letters.pick(Letters.DOGUM, _h(tick * 17 + c.seed)) })
							break
				break

func _pass_away(p: Dictionary) -> void:
	# nazik veda: yıldıza karışır, çayıra anı ağacı, evde yer boşalır
	people.erase(p)
	movers.erase(p)
	# dilek sahibi vefat ettiyse dileği sessizce kapat (yoksa to_save silinmiş kişiye erişip patlar)
	if wish != null and wish.who == p:
		wish = null
	stat_farewells += 1
	if p.home != null:
		p.home.members.erase(p)
		if p.home.members.is_empty():
			p.home.awake = false
			p.home.lit_frac = 0.0
			_push_event("🌒 bir evin ışıkları söndü")
	_plant_memory_tree(p)
	_push_event("✦ %s yıldızlara karıştı — çayıra bir anı ağacı dikildi" % p.name)
	# veda mektubu (duygusal çekirdek) — havuzdan determinist seçim; atkı sahibine kişisel ton
	var vtxt: String = Letters.pick(Letters.VEDA_ATKI if p.scarf else Letters.VEDA, _h(p.seed * 31))
	if bond >= 5 and _hf(p.seed * 7 + tick) < 0.4:
		vtxt += Letters.pick(Letters.BOND_EK, _h(p.seed * 3))
	_push_letter({ "from": p.name, "who": p.seed, "kind": "veda", "replied": false, "text": vtxt })

# ============================================================ KULE MELODİSİ (A5)
## Kuleye öğret: kule saat başı bu melodiyi çalar. İyi beste → Meydan Konseri (bir kez).
func teach_tower(mel: Array) -> Dictionary:
	melody = mel.duplicate()
	melody_saved = true
	_push_event("🎼 kule yeni melodini öğrendi")
	var q := Melody.quality(mel)
	if q.ok and not concert_done:
		concert_done = true
		# sakinler kuleye akın eder
		for p in people:
			if not p.moving and _hf(p.seed) < 0.7:
				p.x = clampf(landmark.x + float(_h(p.seed) % 5) - 2.0, 0.0, float(GW - 1))
				p.y = clampf(landmark.y + float(_h(p.seed * 3) % 5) - 2.0, 0.0, float(GH - 1))
		bond += 1
		# Gezgin Müzisyen kasabaya yerleşir
		var home = null
		var eh := empty_houses()
		if not eh.is_empty():
			home = eh[0]
		var muz := _add_person(landmark.x, landmark.y, home, 1)
		muz.name = "Gezgin Müzisyen"
		if home != null:
			home.members.append(muz)
		_push_letter({ "from": "Gezgin Müzisyen", "who": muz.seed, "kind": "konser", "replied": false,
			"text": "Melodini kulenin tepesinden dinledim. Yıllardır yol alırım, böylesine yürekten bir ezgi az duydum. Bu akşam meydanda herkes senin şarkınla dans etti. Ben de artık burada kalıyorum." })
		_push_event("🎻 MEYDAN KONSERİ! Gezgin Müzisyen kasabaya yerleşti")
		return { "concert": true, "quality": q }
	elif not q.ok:
		_push_event("🎼 kule öğrendi — ipucu: ≥5 nota, ≥3 farklı ses, iniş-çıkış")
	return { "concert": false, "quality": q }

# ============================================================ ODAK SEANSI (A3)
## Seans bitişi ödülü: anında inşaat + seri + atölye/kütüphane + kutlama mektubu. Cozy: cezasız.
## day (YYYYMMDD, main verir; -1 = gün takibi yok/test): SERİ TANIMI aynı gün art arda —
## gün değişince seri nazikçe sıfırlanır, kazanılan ödüller kalır. minutes → istatistik.
func finish_focus_reward(day: int = -1, minutes: int = 0) -> Dictionary:
	if day >= 0 and day != focus_day:
		streak = 0
		today_focus_min = 0
		focus_day = day
	stat_focus_min += minutes
	today_focus_min += minutes
	growth += goal                       # ödül: bir inşaat hemen
	sessions += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	var res := { "atolye": false, "kutuphane": false }
	if streak >= 3 and not unlocked.atolye:
		unlocked.atolye = true
		res.atolye = true
		for b in buildings:
			if b.built == 0:
				b.type = "shop"
				building_now = b
				b.build_prog = 0.01
				break
		_push_letter({ "from": "Kasaba halkı", "who": -1, "kind": "seri", "replied": false,
			"text": "Üç seanslık emeğinin şerefine bir ATÖLYE kuruyoruz. Ellerine sağlık." })
		_push_event("🔨 seri ödülü: Atölye kuruluyor")
	if streak >= 5 and not unlocked.kutuphane:
		unlocked.kutuphane = true
		res.kutuphane = true
		# kütüphane gerçekten yükselsin (atölye gibi): inşasız bir binayı "library" tipine çevir + inşaatı başlat
		for b in buildings:
			if b.built == 0:
				b.type = "library"
				building_now = b
				b.build_prog = 0.01
				break
		_push_letter({ "from": "Kasaba halkı", "who": -1, "kind": "seri", "replied": false,
			"text": "Beş seans! Meydanda bir KÜTÜPHANE yükseliyor. Kasaba seninle akıllanıyor." })
		_push_event("📚 seri ödülü: Kütüphane yükseliyor")
	_push_letter({ "from": "Kasaba halkı", "who": -1, "kind": "odak", "replied": false,
		"text": Letters.pick(Letters.ODAK, _h(sessions * 97 + tick)) })
	_push_event("🎉 odak seansı tamamlandı — kasaba kutluyor")
	return res

# ============================================================ DİLEK + MEKTUP (A4)
## Dileği gerçekleştir: obje sakinin evinin yanına kurulur + teşekkür mektubu. Grid pos döner (juice için).
func grant_wish():
	if wish == null:
		return null
	var who = wish.who
	var home = who.home
	var px: int = (home.gx + 1) if home != null else landmark.x
	var py: int = (home.gy + 1) if home != null else landmark.y
	px = clampi(px, 0, GW - 1)
	py = clampi(py, 0, GH - 1)
	var t: Dictionary = WISH_TYPES[wish.type]
	match t.k:
		"çeşme": fountains.append({ "gx": px, "gy": py })
		"ağaç": trees.append({ "gx": px, "gy": py, "s": 1, "sway": _hf(px + py) })
		"fener": lamps.append({ "gx": px, "gy": py, "ph": _hf(px * py) * TAU })
		_: decor.append({ "gx": px, "gy": py, "kind": t.k })   # bank/kuş yuvası/posta kutusu/rüzgâr gülü
	_push_letter({ "from": who.name, "who": who.seed, "kind": "dilek", "replied": false,
		"text": Letters.pick(Letters.DILEK[t.k], _h(tick * 11 + px)) })
	stat_wishes += 1
	_push_event("🌟 %s'nın dileği gerçek oldu" % who.name)
	wish = null
	return Vector2i(px, py)

func wish_text() -> String:
	if wish == null:
		return ""
	return "💭 %s: \"keşke %s olsa\" — dokun, gerçekleştir" % [wish.who.name, WISH_TYPES[wish.type].txt]

## Mektuba içtenlikle yanıt: bond+1, sakin atkı kazanır (bağın görünür nişanı).
func reply_letter(idx: int) -> void:
	if idx < 0 or idx >= letters.size():
		return
	var l = letters[idx]
	if l.replied:
		return
	l.replied = true
	bond += 1
	# atkıyı isimle değil kalıcı seed'le ver (aynı isimde iki sakin olabilir; JSON int→float'a karşı int())
	var who_seed := int(l.get("who", -1))
	if who_seed >= 0:
		for p in people:
			if p.seed == who_seed:
				p.scarf = true
				break
	_push_event("💛 %s yanıtını aldı" % l.from)

func _plant_memory_tree(p: Dictionary) -> void:
	for t2 in range(40):
		var gx: int = frontier + 2 + _h(p.seed + t2) % maxi(1, GW - frontier - 4)
		var gy: int = 2 + _h(p.seed * 3 + t2) % maxi(1, GH - 4)
		if not road_set.has(Vector2i(gx, gy)):
			mem_trees.append({"gx": gx, "gy": gy, "name": p.name})
			if mem_trees.size() > 40:
				mem_trees.pop_front()
			return
