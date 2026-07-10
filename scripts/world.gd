class_name World
extends RefCounted
## NEFES saf sim (ANAYASA: sim render'dan ayrı, saf, test edilebilir; node okumaz).
## HTML v15 gen()/stepWorld() gridi buraya taşındı. Tüm rastgelelik _h/_hf'ten (randi/randf YOK).
## Grid koordinatları; piksel/easing/kozmetik (kuş/bulut/kar) render'ın (town_view) işi.
## A0 kapsamı: dünya üretimi + büyüme→inşaat + yürüyüş + gece eğrisi. Yaşam döngüsü = A1.

const GW := 64
const GH := 26
const TICKS_PER_DAY := 2400
const SEASON_TICKS := 7 * TICKS_PER_DAY   # 1 mevsim = 7 gün → 1 yıl = 28 gün (yıl sayacı görünür hızda)
const DAYS_PER_YEAR := 28

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
var pending_special: Array = []   # bina bulunamayan özel dönüşümler (vaat kaybolmaz — frontier açılınca kurulur)
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
var letters: Array = []                # {lid, from, who, text, kind, replied} — kaynak veda (A1); dilek/odak + UI = A4
var letter_seq := 0                    # kalıcı mektup kimliği (lid) — UI index YAKALAMAZ (push_front kaydırır)

# --- odak seansı + seri (A3; B+ istatistik + kalıcılık) ---
var streak := 0
var sessions := 0
var unlocked := { "atolye": false, "kutuphane": false, "rasathane": false, "sera": false, "hamam": false }
# seri sonrası uzun-vade bina zinciri (Faz D): toplam seans eşikleriyle açılır
# "ev" = Loc anahtarı; mektup gövdesi Letters.MILESTONE_TXT'te (i18n H1 — metin tek kaynak)
const MILESTONE_BUILDINGS := [
	{ "key": "rasathane", "at": 10, "ev": "ev_rasathane" },
	{ "key": "sera", "at": 20, "ev": "ev_sera" },
	{ "key": "hamam", "at": 35, "ev": "ev_hamam" },
]
var best_streak := 0
var tower_gilded := false        # 200-seans ödülü: kule yaldızı (render bayrağı, G1.7)
# kümülatif seans ödülleri (G1.7 — Forest deseni): TOPLAM sayaç, zincir-kırılma kavramı YOK.
# İlk 3 basamak MILESTONE_BUILDINGS'te (bina); bunlar kalıcı süs/anıt olarak devam eder.
# "ev" = Loc anahtarı; mektup gövdesi Letters.SESSION_TXT'te (i18n H1 — metin tek kaynak)
const SESSION_REWARDS := [
	{ "at": 50, "kind": "heykel", "ev": "ev_ses50" },
	{ "at": 75, "kind": "kameriye", "ev": "ev_ses75" },
	{ "at": 100, "kind": "yuzyil_mesesi", "ev": "ev_ses100" },
	{ "at": 150, "kind": "fener_dizisi", "ev": "ev_ses150" },
	{ "at": 200, "kind": "kule_yaldizi", "ev": "ev_ses200" },
	{ "at": 300, "kind": "zafer_bahcesi", "ev": "ev_ses300" },
	{ "at": 500, "kind": "ebedi_alev", "ev": "ev_ses500" },
]
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
var density_level := 0                 # iç yoğunlaşma (G1.3): frontier dolunca kasaba içe sıklaşır (0-3)

# --- kasaba ünvanı (G1.4): nüfus eşikleri — asla düşmez, her atlama tek seferlik kutlama ---
var tier := 0
# ünvan adları Loc.t("tier%d")'den (i18n H1); "key" = ünvan kutlaması AN mektubu anahtarı
const TIERS := [
	{ "pop": 0, "key": "" },
	{ "pop": 25, "key": "tier_koy" },
	{ "pop": 60, "key": "tier_buyuk_koy" },
	{ "pop": 100, "key": "tier_kasaba" },
	{ "pop": 150, "key": "tier_kucuk_sehir" },
	{ "pop": 220, "key": "tier_sehir" },
]

# İhtiyaç binaları (G1.5 — Banished merdiveni): tier açar, ev sayısına oranla kurulur.
# per=999 → kasabada TEK. Her tip render'da izlenebilir davranış taşır (town_view).
const NEED_BUILDINGS := [
	{ "type": "kuyu", "tier": 1, "per": 10, "ev": "ev_kuyu" },
	{ "type": "firin", "tier": 1, "per": 15, "ev": "ev_firin" },
	{ "type": "pazar", "tier": 2, "per": 25, "ev": "ev_pazar" },
	{ "type": "cayevi", "tier": 2, "per": 20, "ev": "ev_cayevi" },
	{ "type": "okul", "tier": 3, "per": 30, "ev": "ev_okul" },
	{ "type": "degirmen", "tier": 3, "per": 999, "ev": "ev_degirmen" },
	{ "type": "han", "tier": 4, "per": 999, "ev": "ev_han" },
	{ "type": "festival_alani", "tier": 4, "per": 999, "ev": "ev_festival_alani" },
]
var milestones := {}                   # uzun-vade anları (gun30/sakin100/veda50/butunlendi — tek seferlik)
var town_complete := false             # harita doldu: growth artık güzelleştirmeye akar (end-game, Faz D)
# teşekkür metinleri Letters.DILEK'te, görünen dilek cümlesi Loc "wtxt_*" (tek kaynak; i18n H1).
# "k" sim durumuna girer (decor.kind, DILEK anahtarı) — TR anahtar olarak SABİT kalır.
const WISH_TYPES := [
	{ "k": "çeşme" },
	{ "k": "ağaç" },
	{ "k": "fener" },
	{ "k": "bank" },
	{ "k": "kuş yuvası" },
	{ "k": "posta kutusu" },
	{ "k": "rüzgâr gülü" },
]

const SEASON_NAMES := ["ilkbahar", "yaz", "sonbahar", "kış"]
const FLOWER_COST := 2400.0       # bir çiçeğin emeği (~3 oyun-günü growth; plato ödül temposu)
const GOAL_CAP := 7200.0          # inşaat maliyeti tavanı: üstel fren burada durur → geç oyunda
								  # ~7.8 gün pasif emek/bina SÜREKLİ tempo (playtest: "büyüme hissi yok" çözümü)
const PRESSURE_BUILD := 0.72      # inşaat kapısı; göç < 0.85 — örtüşme penceresi eski 0.75/0.75 sınır kilidini çözer
const POP_SOFT_CAP := 320         # perf tavanı (offline sarma + render kişi-döngüleri); doğumu lojistik frenler, ceza değil
var rain_was := false             # yağmur geçiş olayı için (save'e girmez; tek sahte geçiş zararsız)

# --- rastgele gün olayları (G1.8): günde en çok bir, HEPSİ HEDİYE (savaş/ceza yok — cozy) ---
var last_event_day := -1          # save'de; aynı gün ikinci olay yok
var recent_events: Array = []     # son 3 olay kimliği (tekrar önleme; save'de)
var pending_family := 0           # göçebe mektubu: ertesi gün garantili göç (save'de)
# görsel nabızlar (rain_was gibi save'e girmez; render gözlemler)
var rainbow_t := 0.0
var balloon_t := 0.0
var kite_t := 0.0
var starfall_t := 0.0
const DAY_EVENTS := [
	{ "id": 0, "w": 14, "k": "tuccar" },
	{ "id": 1, "w": 10, "k": "dugun" },
	{ "id": 2, "w": 8,  "k": "hasat" },
	{ "id": 3, "w": 10, "k": "gokkusagi" },
	{ "id": 4, "w": 8,  "k": "balon" },
	{ "id": 5, "w": 10, "k": "gocebe" },
	{ "id": 6, "w": 10, "k": "kus_surusu" },
	{ "id": 7, "w": 8,  "k": "ucurtma" },
	{ "id": 8, "w": 8,  "k": "yildiz" },
	{ "id": 9, "w": 4,  "k": "ziyaretci" },
]
var festival_t := 0.0             # festival nabzı 1→0 (render gözlemler; chime_t deseni)
var fest_done := false            # bu mevsim festivali oldu mu (mevsim dönünce sıfırlanır)
const FEST_EVENTS := ["ev_fest0", "ev_fest1", "ev_fest2", "ev_fest3"]   # Loc anahtarları (i18n H1)

func population() -> int:
	return people.size()

func town_seed() -> int:
	return _salt   # kartpostal/paylaşım: aynı tohum = aynı kasaba

func day() -> int:
	return tick / TICKS_PER_DAY + 1

func year() -> int:
	return (day() - 1) / DAYS_PER_YEAR + 1

func tier_name() -> String:
	return Loc.t("tier%d" % tier)

func clock_string() -> String:
	var hh := int(floor(time_of_day))
	var mm := int(floor(fmod(time_of_day, 1.0) * 60.0))
	return "%02d:%02d" % [hh, mm]

func status_text() -> String:
	if building_now != null:
		return Loc.t("st_insaat")
	if not movers.is_empty():
		return Loc.t("st_tasinma")
	var ev := evening()
	if ev > 0.7:
		return Loc.t("st_isil")
	if ev > 0.3:
		return Loc.t("st_aksam")
	if ev > 0.0:
		return Loc.t("st_aksamustu")
	return Loc.t("st_gun")   # öğlen "akşam" yazıyordu (HTML port kalıntısı)

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
	letter_seq = 0
	pending_special = []
	wish = null
	bond = 0
	milestones = {}
	density_level = 0
	tier = 0
	tower_gilded = false
	last_event_day = -1
	recent_events = []
	pending_family = 0
	rainbow_t = 0.0
	balloon_t = 0.0
	kite_t = 0.0
	starfall_t = 0.0
	town_complete = false
	streak = 0
	sessions = 0
	unlocked = { "atolye": false, "kutuphane": false, "rasathane": false, "sera": false, "hamam": false }
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

	# yollar KADEMELİ: başlangıçta yalnız kasaba alanı (+2 taşma); çayıra hazır yol serilmez —
	# kasaba büyüdükçe _expand_frontier yolu da uzatır (kullanıcı: "başta tüm haritada yol garip")
	_build_road_network(frontier + 2)

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
		b.stage = 1 if b.built == 1 else 0   # çekirdek evler tanıdık görünümle başlar
		b.built_at = 0

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
	# omurga: verilen sınıra kadar hafif meandering, 2 hücre kalın (formüller gx-mutlak →
	# sonraki çağrılar aynı hücreleri üretir; _add_road dedupe ile kademeli uzatma güvenli)
	for gx in range(max_x):
		var y := spine_y + int(round(sin(gx * 0.18) * 2.0))
		_add_road(gx, y)
		_add_road(gx, y + 1)
	# dikey dal sokakları (yalnız kasaba alanında)
	var bx := 8
	while bx < max_x:
		var length := 3 + _h(bx * 7) % 5
		var dir := 1 if (_h(bx) % 2) else -1
		var x := bx
		var y := spine_y
		for s in range(length):
			y += dir
			if y < 2 or y >= GH - 2:
				break
			x += (_h(bx * 13 + s) % 3) - 1
			_add_road(x, y)
		bx += 8 + (_h(bx) % 4)   # dallar seyrekleşti (6+%3 idi — yol yoğunluğu şikâyeti)
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
		by += 9   # ara sokaklar seyrekleşti (7 idi)

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
		"stage": 0, "built_at": -1,   # ev evresi (G1.6): kulübe→ev→taş ev; terfi damlaması step_world'de
	})

func _add_person(gx: int, gy: int, home, stage: int) -> Dictionary:
	var seed := _h((people.size() + 1) * 99 + tick * 7)
	var p := {
		"x": float(gx), "y": float(gy), "tx": gx, "ty": gy,
		"col": _h(seed * 31) % 6, "seed": seed, "moving": false,
		"home": home, "name": Names.at(name_idx), "stage": stage, "age_t": 0,
		"span_a": 2000 + _h(seed) % 900,          # çocuk→yetişkin (~1 gün)
		"span_b": 30000 + _h(seed * 3) % 28800,   # yetişkin→bilge (12.5-24.5 gün; kısa ömür devri nüfusu platoda tutuyordu)
		"span_c": 9600 + _h(seed * 7) % 7200,     # bilge→veda (4-7 gün)
		"wants_home": false, "steps": 0, "scarf": false,
	}
	people.append(p)
	name_idx += 1
	return p

# ============================================================ HANE YARDIMCILARI
func _adopt_orphan_build() -> void:
	for b in buildings:
		if b.built == 0 and b.build_prog > 0.0:
			building_now = b
			return

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
	if season_tick >= SEASON_TICKS:
		season_tick = 0
		season = (season + 1) % 4
		fest_done = false
	var ev := evening()

	# pencere programı: akşam yanar, 23-05 UYKU (ışık bütçesi — formül TEK KAYNAK: _sleep_amount)
	var sleep := _sleep_amount(time_of_day)
	light_curve = ev * (1.0 - sleep * SLEEP_DIM)
	for b in buildings:
		if b.awake:
			var t := _lit_target(ev, sleep)
			b.lit_frac += (t - b.lit_frac) * 0.03

	# yükselen bina; sahipsiz yarım inşaat varsa sahiplen (çoklu ödül dönüşümü / eski save iyileşmesi)
	if building_now == null:
		_adopt_orphan_build()
	if building_now != null:
		# 0.005: bina ~200 tick'te (2.5 gerçek dk) yükselir — inşaat İZLENEBİLİR bir sahne (Rusty dersi)
		building_now.build_prog = minf(1.0, building_now.build_prog + 0.005)
		if building_now.build_prog >= 1.0:
			building_now.built = 1
			building_now.built_at = tick   # evre terfisi yaşı buradan sayılır (G1.6)
			_queue_move_in(building_now)
			building_now = null
			# tamamlanır tamamlanmaz sahiplen: growth aynı tick'te yeni doğal inşaat başlatıp
			# söz verilmiş (milestone/ödül) binaları 0.01'de açlıkta bırakıyordu
			_adopt_orphan_build()

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
	# KURAL: inşaat konut sıkışıklığında (Banished dersi). goal ×1.18 üstel ama GOAL_CAP'te durur:
	# eski sınırsız üstel ~40 evde inşaatı fiilen bitiriyordu (playtest: "70'i geçmedi, büyümüyor").
	# Artık ilk ~38 bina hızlı açılış, sonrası sabit ~7.8 gün/bina tempo — kasaba YILLARCA büyür;
	# nüfus tavanı POP_SOFT_CAP lojistik freniyle (doğum/göç yavaşlar, asla ceza yok).
	if growth >= goal:
		if town_complete:
			# END-GAME (Faz D): kasaba bütünlendi — emek güzelleştirmeye akar (cozy: bitiş duvarı yok)
			growth -= goal
			goal = minf(GOAL_CAP, goal * 1.10)
			_beautify()
		elif building_now == null and (housing_pressure() >= PRESSURE_BUILD or (homeless and empty_houses().is_empty())):
			growth -= goal
			goal = minf(GOAL_CAP, goal * 1.18)
			_start_construction()
		elif growth >= goal + FLOWER_COST:
			# inşaat kapısı kapalıyken biriken fazla emek çiçeğe akar (HER platoda — yalnız uç platoda değil)
			growth -= FLOWER_COST
			_beautify()


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
			_push_event(Loc.t("ev_dilek") % who.name)

	# MEVSİM FESTİVALİ (Faz D): mevsim ortasında küçük şenlik — sakinler meydana, olay + seyrek mektup.
	# Mevsim artık 7 gün → festival seyrek bir an; mektup şansı %50 (spam değil, hatıra).
	if season_tick >= SEASON_TICKS / 2 and not fest_done:   # >=: yüklenen save eşiği geçmişse festival kaçmasın
		fest_done = true
		festival_t = 1.0
		_push_event(Loc.t(FEST_EVENTS[season]))
		if _hf(tick * 43) < 0.5:
			_push_letter({ "from": Loc.t("from_kasaba"), "who": -1, "kind": "festival", "replied": false,
				"text": Letters.fest(season) })
		for p in people:
			if not p.moving and _hf(p.seed + tick) < 0.4:
				p.x = clampf(landmark.x + float(_h(p.seed) % 7) - 3.0, 0.0, float(GW - 1))
				p.y = clampf(landmark.y + float(_h(p.seed * 3) % 7) - 3.0, 0.0, float(GH - 1))
	# maxf: dinlenme durumu TAM 0.0 (negatif e-16 kalıntısı JSON hassasiyetinde roundtrip bozuyor)
	festival_t = maxf(0.0, festival_t - 0.005)   # ~200 tick şenlik nabzı

	# yağmur geçişleri (görsel/ses katmanının olay bildirimi; sim durumuna etkimez)
	var raining := rain_amount() > 0.1
	if raining and not rain_was:
		_push_event(Loc.t("ev_yagmur"))
	elif rain_was and not raining:
		_push_event(Loc.t("ev_yagmur_dindi"))
	rain_was = raining

	# EV EVRELERİ (G1.6 — Foundation deseni): 240 tick'te bir TEK terfi (görünür damlama,
	# asla gerileme). Kulübe 3 günde + yakın servisle EVE; ev 10 günde + Kasaba tier'ıyla TAŞ EVE.
	if tick % 240 == 0:
		for b in buildings:
			if b.type != "house" or b.built != 1:
				continue
			var age: int = tick - int(b.get("built_at", -1))
			var st: int = int(b.get("stage", 1))
			if st == 0 and age >= 3 * TICKS_PER_DAY and _near_service(b, 6):
				b.stage = 1
				_push_event(Loc.t("ev_kulube_ev"))
				break
			if st == 1 and age >= 10 * TICKS_PER_DAY and tier >= 3 and _near_service(b, 4):
				b.stage = 2
				_push_event(Loc.t("ev_tas_ev"))
				break

	# KASABA ÜNVANI (G1.4): eşik aşımı → tabela + kutlama + mektup. 40 tick'te bir kontrol:
	# eski save 0'dan başlayıp kademeli yakalar (her atlama ayrı kutlanır — hoş yeniden karşılama)
	if tick % 40 == 0 and tier < TIERS.size() - 1 and population() >= TIERS[tier + 1].pop:
		tier += 1
		festival_t = 1.0   # meydan şenliği nabzı (mevcut festival deseni yeniden kullanılır)
		_milestone(TIERS[tier].key, Loc.t("ev_tier") % Loc.t("tier%d" % tier).to_upper())

	# GÜNLÜK OLAY (G1.8): ~%35 gün olaylı; saat 10-19 arası deterministik pencere (100 tick).
	# gökkuşağı yağmurlu güne, hasat sonbahara, uçurtma ilkbahar/yaza koşullu (_event_ok).
	var dnum := day() - 1
	if dnum != last_event_day and _hf(dnum * 211 + 7) < 0.35:
		var ev_hour := 10.0 + float(_h(dnum * 13 + 3) % 10)
		if time_of_day >= ev_hour and time_of_day < ev_hour + 1.0:
			last_event_day = dnum
			_fire_day_event(dnum)
	rainbow_t = maxf(0.0, rainbow_t - 0.002)
	balloon_t = maxf(0.0, balloon_t - 0.0015)
	kite_t = maxf(0.0, kite_t - 0.002)
	starfall_t = maxf(0.0, starfall_t - 0.003)

	# uzun-vade anları (Faz D): tek seferlik kutlamalar
	if tick >= 30 * TICKS_PER_DAY and not milestones.get("gun30", false):
		_milestone("gun30", Loc.t("ev_gun30"))
	if name_idx >= 100 and not milestones.get("sakin100", false):
		_milestone("sakin100", Loc.t("ev_sakin100"))
	if stat_farewells >= 50 and not milestones.get("veda50", false):
		_milestone("veda50", Loc.t("ev_veda50"))

	# saat başı: kule nabzı (görsel çan/kuş A2; melodi A5)
	var hr := int(floor(time_of_day))
	if hr != last_hour:
		last_hour = hr
		chime_t = 1.0
	chime_t = maxf(0.0, chime_t - 0.02)   # aynı JSON-kalıntı korunması

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
		"letter_seq": letter_seq,
		"pending_special": pending_special.duplicate(),
		"milestones": milestones.duplicate(),
		"town_complete": town_complete,
		"density_level": density_level,
		"tier": tier,
		"tower_gilded": tower_gilded,
		"last_event_day": last_event_day, "recent_events": recent_events, "pending_family": pending_family,
		"last_exit": Time.get_unix_time_from_system(),
	}

## KURAL: her erişim .get + default (şema kontrolü yalnız 4 kimlik anahtarını garantiler;
## eksik-anahtarlı/yarı-migrasyon kayıt çökmek yerine güvenli default'a düşmeli — kural 9).
func from_save(d: Dictionary) -> void:
	_salt = int(d.seed)
	tick = int(d.tick)
	time_of_day = float(d.get("time_of_day", 17.2))
	season = int(d.get("season", 0))
	season_tick = int(d.get("season_tick", 0))
	frontier = int(d.get("frontier", int(GW * 0.30)))
	growth = float(d.get("growth", 0.0))
	goal = float(d.get("goal", 12.0))
	# Odak seansı yüklemede restore edilmiyor → kaydedilen ×1.5 hayalet kalmasın (bug: growth_mult sızıntısı).
	growth_mult = 1.0
	light_curve = float(d.get("light_curve", 0.0))
	last_hour = int(d.get("last_hour", -1))
	chime_t = float(d.get("chime_t", 0.0))
	festival_t = float(d.get("festival_t", 0.0))
	fest_done = bool(d.get("fest_done", false))
	name_idx = int(d.get("name_idx", 0))
	bond = int(d.get("bond", 0))
	streak = int(d.get("streak", 0))
	sessions = int(d.get("sessions", 0))
	# B+ alanları eski save'lerde yok → .get default (sessiz veri kaybı değil, bilinçli geriye-uyum)
	best_streak = int(d.get("best_streak", streak))
	stat_focus_min = int(d.get("stat_focus_min", 0))
	today_focus_min = int(d.get("today_focus_min", 0))
	focus_day = int(d.get("focus_day", -1))
	focus_until = float(d.get("focus_until", 0.0))
	focus_phase = str(d.get("focus_phase", ""))
	focus_mode = int(d.get("focus_mode", 0))
	# anahtarlar sabit listeden yüklenir (eski hardcoded yükleme yeni anahtarları DÜŞÜRÜYORDU)
	unlocked = { "atolye": false, "kutuphane": false, "rasathane": false, "sera": false, "hamam": false }
	var du: Dictionary = d.get("unlocked", {})
	for k in unlocked.keys():
		unlocked[k] = bool(du.get(k, false))
	melody = []
	for n in d.get("melody", Melody.DEFAULT):
		melody.append(int(n))
	melody_saved = bool(d.get("melody_saved", false))
	concert_done = bool(d.get("concert_done", false))
	stat_births = int(d.get("stat_births", 0))
	stat_farewells = int(d.get("stat_farewells", 0))
	stat_arrivals = int(d.get("stat_arrivals", 0))
	stat_wishes = int(d.get("stat_wishes", 0))
	milestones = (d.get("milestones", {}) as Dictionary).duplicate()
	town_complete = bool(d.get("town_complete", false))
	density_level = int(d.get("density_level", 0))
	tier = clampi(int(d.get("tier", 0)), 0, TIERS.size() - 1)
	tower_gilded = bool(d.get("tower_gilded", false))
	last_event_day = int(d.get("last_event_day", -1))
	recent_events = []
	for re in d.get("recent_events", []):
		recent_events.append(int(re))
	pending_family = int(d.get("pending_family", 0))
	var lm: Array = d.get("landmark", [11, 13])
	landmark = Vector2i(int(lm[0]), int(lm[1]))
	road_list = _to_vec_list(d.get("road_list", []))
	road_set = {}
	for c in road_list:
		road_set[c] = true
	river = _to_vec_list(d.get("river", []))
	river_set = {}
	for c in river:
		river_set[c] = true
	plaza_cells = _to_vec_list(d.get("plaza_cells", []))
	# JSON tüm sayıları float yapar (kritik tuzak 2) → int-kritik alanlar burada da zorlanır
	# (roundtrip eşitliği + dizi indeksi güvenliği; endgame testi yakaladı)
	lamps = []
	for sd in d.get("lamps", []):
		var L: Dictionary = (sd as Dictionary).duplicate(true)
		L.gx = int(L.gx); L.gy = int(L.gy)
		lamps.append(L)
	trees = []
	for sd in d.get("trees", []):
		var T: Dictionary = (sd as Dictionary).duplicate(true)
		T.gx = int(T.gx); T.gy = int(T.gy); T.s = int(T.get("s", 1))
		trees.append(T)
	fountains = []
	for sd in d.get("fountains", []):
		var F: Dictionary = (sd as Dictionary).duplicate(true)
		F.gx = int(F.gx); F.gy = int(F.gy)
		fountains.append(F)
	mem_trees = []
	for sd in d.get("mem_trees", []):
		var M: Dictionary = (sd as Dictionary).duplicate(true)
		M.gx = int(M.gx); M.gy = int(M.gy)
		mem_trees.append(M)
	decor = []
	for sd in d.get("decor", []):
		var DC: Dictionary = (sd as Dictionary).duplicate(true)
		DC.gx = int(DC.gx); DC.gy = int(DC.gy)
		decor.append(DC)
	letters = []
	letter_seq = int(d.get("letter_seq", 0))
	for sd in d.get("letters", []):
		var L2: Dictionary = (sd as Dictionary).duplicate(true)
		L2.who = int(L2.get("who", -1))
		if L2.has("lid"):
			L2.lid = int(L2.lid)
		else:
			L2["lid"] = letter_seq   # eski save migrasyonu: lid'siz mektuba kimlik ata
			letter_seq += 1
		letters.append(L2)
	pending_special = []
	for t in d.get("pending_special", []):
		pending_special.append(String(t))
	# binalar (members geçici olarak index) — eksik anahtar çökertmez (.get + default)
	buildings = []
	for sd in d.buildings:
		var b: Dictionary = (sd as Dictionary).duplicate(true)
		for k in _BLD_INT:
			b[k] = int(b.get(k, 0))
		# G1.6 geriye uyum: eski save'de evre yok → mevcut görünüm (ev) + 3 gün önce inşa sayılır
		b["stage"] = int(b.get("stage", 1))
		b["built_at"] = int(b.get("built_at", tick - 3 * TICKS_PER_DAY))
		buildings.append(b)
	# sakinler (home geçici olarak index)
	people = []
	for sd in d.people:
		var p: Dictionary = (sd as Dictionary).duplicate(true)
		for k in _PERSON_INT:
			p[k] = int(p.get(k, 0 if k != "home" else -1))
		people.append(p)
	# ref relink
	for b in buildings:
		var mem := []
		for pi in b.get("members", []):
			var ii := int(pi)
			if ii >= 0 and ii < people.size():
				mem.append(people[ii])
		b.members = mem
	for p in people:
		var hi: int = p.home
		p.home = buildings[hi] if hi >= 0 and hi < buildings.size() else null
	var bn := int(d.get("building_now", -1))
	building_now = buildings[bn] if bn >= 0 and bn < buildings.size() else null
	movers = []
	for p in people:
		if p.get("moving", false):
			movers.append(p)
	var wd = d.get("wish", null)
	if wd == null:
		wish = null
	else:
		var wi := int(wd.get("who", -1))
		wish = { "who": people[wi], "type": int(wd.get("type", 0)) } if wi >= 0 and wi < people.size() else null

## Doğrulama/capture: belirli bir saati sabitle + ışığı kararlı hale getir (deterministik).
func force_time(tod: float) -> void:
	time_of_day = tod
	var ev := evening()
	var sleep := _sleep_amount(time_of_day)
	light_curve = ev * (1.0 - sleep * SLEEP_DIM)
	for b in buildings:
		if b.awake:
			b.lit_frac = _lit_target(ev, sleep)

func evening() -> float:
	var t := time_of_day
	if t >= 8.0 and t < 17.0: return 0.0                 # gündüz
	if t >= 17.0 and t < 21.0: return (t - 17.0) / 4.0   # alacakaranlık
	if t >= 21.0 or t < 5.0: return 1.0                  # gece
	return 1.0 - (t - 5.0) / 3.0                          # şafak

# ---- IŞIK BÜTÇESİ TEK KAYNAĞI (ANAYASA madde 3) ----
# Formül 3 yerde birebir kopyaydı (step_world/force_time/is_asleep) — drift riski; QA yakaladı.
const SLEEP_START := 23.0      # kasaba uykusu başlangıcı
const SLEEP_END := 5.0         # uyanış
const SLEEP_RAMP_H := 2.0      # uykuya dalış rampası (saat)
const SLEEP_DIM := 0.55        # light_curve = evening × (1 − sleep×SLEEP_DIM)
const LIT_BASE := 0.04         # gündüz yanık pencere oranı
const LIT_EV := 0.72           # akşam katkısı (gece %76'ya çıkar)
const SLEEP_LIT_CUT := 0.85    # uykuda pencerelerin sönme oranı

## 23-05 uyku miktarı (0..1, rampalı). SLEEP_END öncesi kolu: t+1 → 24'ü aşan saatin devamı.
func _sleep_amount(t24: float) -> float:
	if t24 >= SLEEP_START or t24 < SLEEP_END:
		return minf(1.0, ((t24 - SLEEP_START) if t24 >= SLEEP_START else (t24 + 1.0)) / SLEEP_RAMP_H)
	return 0.0

func _lit_target(ev: float, sleep: float) -> float:
	return (LIT_BASE + ev * LIT_EV) * (1.0 - sleep * SLEEP_LIT_CUT)

## Hava durumu (Faz D denetim #19): görsel+ses katmanı — SİM'E ETKİMEZ (denge/determinizm korunur).
## Saf türetim: ~%28 gün yağmurlu (günlük hash), gün içinde 3-6 saatlik pencere, 30dk rampa.
## Kışın yağmur yok (kar zaten yağıyor).
func rain_amount() -> float:
	if season == 3:
		return 0.0
	var d := day() - 1   # 0-tabanlı gün: hash tuzları eski davranışla özdeş (determinizm)
	if _hf(d * 67 + 5) > 0.28:
		return 0.0
	var h0 := 6.0 + float(_h(d * 13) % 12)
	var dur := 3.0 + float(_h(d * 29) % 4)
	var dt_in := time_of_day - h0
	if dt_in < 0.0 or dt_in > dur:
		return 0.0
	return clampf(minf(dt_in / 0.5, (dur - dt_in) / 0.5), 0.0, 1.0)

## Kasaba uyku penceresi (23-05): kule de susar (ışık bütçesi ruhu; TEK KAYNAK _sleep_amount).
func is_asleep() -> bool:
	return _sleep_amount(time_of_day) > 0.0

func _start_construction() -> void:
	# 3 deneme: aday yoksa önce frontier genişletilir, o da doluysa kasaba İÇE SIKLAŞIR (G1.3) —
	# çağıran growth/goal'i çoktan harcadı; boş dal bir döngünün emeğini boşa akıtır
	for attempt in range(3):
		var cand := []
		for b in buildings:
			if b.built == 0 and b.build_prog <= 0.0:
				cand.append(b)
		cand.sort_custom(func(a, b): return _dist(a) < _dist(b))
		if not cand.is_empty():
			var pick: Dictionary = cand[0]
			var need := _need_deficit()
			if not need.is_empty():
				if need.type == "degirmen" and not river.is_empty():
					# değirmen dere kenarına — çark suda dönsün
					cand.sort_custom(func(a, b): return _river_dist(a) < _river_dist(b))
					pick = cand[0]
				pick.type = need.type
				_push_event(Loc.t(need.ev))
			building_now = pick
			building_now.build_prog = 0.01
			return
		if attempt == 0 and frontier < GW - 8:
			_expand_frontier()
			continue
		if density_level < 3:
			_densify(density_level + 1)
			continue
		if not town_complete:
			# harita doldu + yoğunlaşma bitti + inşasız yok → KASABA BÜTÜNLENDİ (bir kez)
			town_complete = true
			_milestone("butunlendi", Loc.t("ev_butunlendi"))
		return

## İç yoğunlaşma (G1.3): frontier tükendiğinde mevcut doku ARASINA yeni sokak+parseller.
## Yalnız EKLER (gx-mutlak, seviye-tuzlu hash + _add_road dedupe → mevcut yollar/binalar
## bozulmaz, determinizm korunur). Her seviye ~30-50 yeni parsel.
func _densify(level: int) -> void:
	density_level = level
	var spine_y := int(floor(GH * 0.5))
	var bx := 5 + level * 2
	while bx < frontier:
		var length := 3 + _h(bx * 7 + level * 1013) % 5
		var dir := 1 if (_h(bx + level * 131) % 2) else -1
		var x := bx
		var y := spine_y
		for s in range(length):
			y += dir
			if y < 2 or y >= GH - 2:
				break
			x += (_h(bx * 13 + s + level * 977) % 3) - 1
			_add_road(x, y)
		bx += 8 + (_h(bx + level) % 4)
	var occ := {}
	for b in buildings:
		occ[Vector2i(b.gx, b.gy)] = true
	for r in road_list:
		if r.x >= frontier:
			continue
		for d in [Vector2i(0, -1), Vector2i(0, 1)]:
			var c: Vector2i = r + d
			if c.x < 5 or c.y < 1 or c.x >= frontier or c.y >= GH - 1:
				continue
			if road_set.has(c) or river_set.has(c) or occ.has(c):
				continue
			if _hf(c.x * 97 + c.y * 61 + level * 419) < 0.72:
				continue
			occ[c] = true
			_add_building(c.x, c.y, _hf(c.x * 3 + c.y * 7 + level) < 0.18)
	_drain_pending_special()   # yeni inşasız binalar açıldı — bekleyen özel binalar kurulsun
	_push_event(Loc.t("ev_densify"))

func _dist(b: Dictionary) -> int:
	return abs(b.gx - landmark.x) + abs(b.gy - landmark.y)

func _river_dist(b: Dictionary) -> int:
	var best := 9999
	for r in river:
		best = mini(best, abs(b.gx - r.x) + abs(b.gy - r.y))
	return best

## Eksik ihtiyaç binası (G1.5): tier'la açık her tip için hedef sayının altındaysa o tipi döndürür.
## İnşaattakiler de sayılır (çifte sipariş önlenir); ev sayısı yalnız BİTMİŞ evlerden.
## Yakın servis (G1.6): r hücre içinde ihtiyaç/özel bina ya da lamba — ev terfisinin koşulu
func _near_service(b: Dictionary, r: int) -> bool:
	for n in buildings:
		if n.built == 1 and n.type != "house" and n.type != "shop":
			if abs(int(n.gx) - int(b.gx)) + abs(int(n.gy) - int(b.gy)) <= r:
				return true
	for l in lamps:
		if abs(int(l.gx) - int(b.gx)) + abs(int(l.gy) - int(b.gy)) <= r:
			return true
	return false

func _need_deficit() -> Dictionary:
	var houses := 0
	var counts := {}
	for b in buildings:
		if b.built == 1 and b.type == "house":
			houses += 1
		counts[b.type] = int(counts.get(b.type, 0)) + 1
	for n in NEED_BUILDINGS:
		if tier < n.tier:
			continue
		var want: int = 1 if n.per >= 999 else maxi(1, houses / int(n.per))
		if int(counts.get(n.type, 0)) < want:
			return n
	return {}

func _expand_frontier() -> void:
	var old := frontier
	frontier = mini(GW - 6, frontier + 5)
	_build_road_network(frontier + 2)   # yol kasabayla birlikte uzar (kademeli büyüme)
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
	_drain_pending_special()   # yeni inşasız binalar açıldı — bekleyen özel binalar kurulsun

func _queue_move_in(b: Dictionary) -> void:
	# yeni ev: %60 aile taşınır, %40 boş kalır (kuşak/göç bekler)
	if b.type != "house":
		b.awake = true
		return
	if _hf(b.seed * 17) < 0.4:
		return   # sahibini bekliyor
	for k in range(2):
		var p := _add_person(landmark.x, landmark.y, b, 1)
		p.age_t = _h(p.seed * 11) % 15000   # geniş yaş dağılımı: kuşak dalgası (toplu veda çöküşü) yayılır
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
	l["lid"] = letter_seq   # kalıcı kimlik: yanıt/atkı push_front kaymasından etkilenmez
	letter_seq += 1
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
	_push_letter({ "from": Loc.t("from_kasaba"), "who": -1, "kind": "an", "replied": false, "text": Letters.an(key) })
	_push_event(ev_text)

## End-game güzelleştirme (Faz D): her goal bir evi çiçeklendirir; hepsi çiçekliyse nazik şenlik.
## Cozy ilke: "bitti" duvarı yok — kasaba tamamlandıktan sonra emek görünür küçük ödüllere akar.
func _beautify() -> void:
	for b in buildings:
		if b.built == 1 and not b.get("bloom", false):
			b.bloom = true
			_push_event(Loc.t("ev_cicek"))
			return
	_push_event(Loc.t("ev_senlik"))

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
			_push_event(Loc.t("ev_buyudu") % p.name)
		elif p.stage == 1 and p.age_t > p.span_b:
			p.stage = 2
			p.age_t = 0
			_push_event(Loc.t("ev_bilge") % p.name)
		elif p.stage == 2 and p.age_t > p.span_c:
			_pass_away(p)

	# KUŞAK: büyüyen gençler yuva kurar — MÜMKÜNSE ÇİFT OLARAK (💍). Bekâr tek başına boş evi
	# kapatınca doğum şartını (2 yetişkin) hiç sağlamıyordu — nüfusu platoda tutan demografik çıkmaz.
	if tick % 40 == 0:
		var seekers := []
		for p in people:
			if p.wants_home and not p.moving and p.stage == 1:
				seekers.append(p)
				if seekers.size() == 2:
					break
		if not seekers.is_empty():
			var nb = null
			if seekers.size() == 1:
				# tek genç: yalnız yaşayan bir gencin yanına katılır (yeni çift kurulur)
				for b in buildings:
					if b.built == 1 and b.type == "house" and b.members.size() == 1 \
							and int(b.cap) >= 2 and b.members[0].stage == 1 and b.members[0] != seekers[0]:
						nb = b
						break
			if nb == null:
				var eh := empty_houses()
				if not eh.is_empty():
					nb = eh[0]
			if nb != null:
				for i in seekers.size():
					var s: Dictionary = seekers[i]
					if s.home != null:
						s.home.members.erase(s)
					s.home = nb
					nb.members.append(s)
					s.tx = nb.gx
					s.ty = nb.gy
					s.moving = true
					s.steps = i * 2
					movers.append(s)
					s.wants_home = false
				if nb.members.size() >= 2:
					_push_event(Loc.t("ev_cift") % [nb.members[nb.members.size() - 2].name, nb.members[nb.members.size() - 1].name])
				else:
					_push_event(Loc.t("ev_tek_yuva") % seekers[0].name)
				_maybe_move_letter(seekers[0], seekers[0].seed * 41 + tick)

	# GÖÇEBE MEKTUBU (G1.8): söz verilen aile ilk boş evde gelir — basınç kapısı
	# beklemez (mektup bir SÖZ; cozy: verilen söz tutulur), yalnız boş ev bekler
	if pending_family > 0 and tick % 200 == 0:
		var ph := empty_houses()
		if not ph.is_empty():
			var pnb: Dictionary = ph[0]
			for k in range(pending_family):
				var pp := _add_person(0, int(floor(GH * 0.5)), pnb, 1)
				pp.age_t = _h(pp.seed * 11) % 15000
				pp.tx = pnb.gx
				pp.ty = pnb.gy
				pp.moving = true
				pp.steps = k * 2
				pnb.members.append(pp)
				movers.append(pp)
			pending_family = 0
			stat_arrivals += 1
			_push_event(Loc.t("ev_soz_aile"))

	# GÖÇ: boş ev + gevşek nüfus → yeni aile (kasaba asla ölmez; boşsa hızlanır).
	# < 0.85: inşaat kapısı (0.72) ile örtüşen pencere — eski 0.75/0.75 tam-tamamlayıcı
	# eşikler sistemi sınırda kilitliyordu (ne inşaat ne göç). POP_SOFT_CAP'te nazikçe durur.
	var mig_every := 400 if housing_pressure() < 0.45 else 500
	if tick % mig_every == 0 and housing_pressure() < 0.85 and population() < POP_SOFT_CAP - 20:
		var eh := empty_houses()
		if not eh.is_empty() and _hf(tick * 13) < 0.7:
			var nb: Dictionary = eh[0]
			for k in range(2 + _h(tick * 3) % 2):
				var p := _add_person(0, int(floor(GH * 0.5)), nb, 1)
				p.age_t = _h(p.seed * 11) % 15000   # geniş yaş dağılımı: kuşak dalgası (toplu veda çöküşü) yayılır
				p.tx = nb.gx
				p.ty = nb.gy
				p.moving = true
				p.steps = k * 2
				nb.members.append(p)
				movers.append(p)
			stat_arrivals += 1
			_push_event(Loc.t("ev_yeni_aile"))
			if not nb.members.is_empty():
				_maybe_move_letter(nb.members[0], nb.seed * 29 + tick)

	# DOĞUM (Banished): 2+ yetişkinli, yeri olan evde yavaş şans; tek doğum/kontrol.
	# Lojistik fren: POP_SOFT_CAP'e yaklaştıkça şans düşer (taban 0.15× — kasaba asla kısırlaşmaz)
	if tick % 40 == 0:
		var birth_chance := 0.14 * maxf(0.15, 1.0 - population() / float(POP_SOFT_CAP))
		for b in buildings:
			if b.built != 1 or b.type != "house":
				continue
			var adults := 0
			for m in b.members:
				if m.stage == 1:
					adults += 1
			if adults >= 2 and b.members.size() < int(b.cap) and _hf(b.seed + tick) < birth_chance:
				var c := _add_person(b.gx, b.gy, b, 0)
				b.members.append(c)
				stat_births += 1
				_push_event(Loc.t("ev_dogum") % c.name)
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
			_push_event(Loc.t("ev_isik_sondu"))
	_plant_memory_tree(p)
	_push_event(Loc.t("ev_veda") % p.name)
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
	_push_event(Loc.t("ev_melodi"))
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
		muz.name = Loc.t("from_muzisyen")
		if home != null:
			home.members.append(muz)
		_push_letter({ "from": Loc.t("from_muzisyen"), "who": muz.seed, "kind": "konser", "replied": false,
			"text": Letters.konser_txt() })
		_push_event(Loc.t("ev_konser"))
		return { "concert": true, "quality": q }
	elif not q.ok:
		_push_event(Loc.t("ev_melodi_ipucu"))
	return { "concert": false, "quality": q }

## İnşasız bir binayı özel tipe çevirip inşaatı başlatır (atölye/kütüphane/zincir ortak yolu).
## El değmemiş (build_prog<=0) bina seçilir ve building_now yalnız boşsa alınır — aynı ödülde
## birden çok dönüşüm birbirinin binasını ÇALMASIN (çalınan inşaat 0.01'de sonsuza dek kalıyordu).
## Uygun bina YOKSA vaat kaybolmaz: pending_special kuyruğuna girer, frontier genişleyince kurulur
## (önceden unlocked=true + mektup gidiyor ama bina hiç yükselMİYORDU — sessiz kırık vaat).
func _convert_unbuilt(t: String) -> void:
	for b in buildings:
		if b.built == 0 and b.build_prog <= 0.0:
			b.type = t
			b.build_prog = 0.01
			if building_now == null:
				building_now = b
			return
	pending_special.append(t)

## Bekleyen özel binaları kur (frontier genişlemesi yeni inşasız bina açtığında çağrılır).
func _drain_pending_special() -> void:
	while not pending_special.is_empty():
		var t: String = pending_special[0]
		var placed := false
		for b in buildings:
			if b.built == 0 and b.build_prog <= 0.0:
				b.type = t
				b.build_prog = 0.01
				if building_now == null:
					building_now = b
				placed = true
				break
		if not placed:
			return
		pending_special.pop_front()

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
	growth += goal
	sessions += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	var res := { "atolye": false, "kutuphane": false }
	# GARANTİLİ GÖRÜNÜR SONUÇ (G1.7): eski kod yalnız growth eklerdi; basınç kapısına
	# takılıp çoğu zaman HİÇBİR görünür şey olmuyordu ("pomodoro yaptım, kasaba büyümedi").
	# Zincir: inşaat başlat (kapı atlanır) → olmuyorsa ev terfisi → o da olmuyorsa çiçek.
	var vis := ""
	if building_now == null:
		_start_construction()
		if building_now != null:
			growth -= goal   # eklenen emek bu inşaata harcandı (bedava çifte inşaat olmasın)
			vis = "insaat"
			_push_event(Loc.t("ev_seans_insaat"))
	if vis == "":
		for b in buildings:
			if b.type == "house" and b.built == 1 and int(b.get("stage", 1)) < 2 \
					and (tick - int(b.get("built_at", -1))) >= 3 * TICKS_PER_DAY:
				b.stage = int(b.get("stage", 1)) + 1   # seans ödülü servisi beklemez (yaş yeter)
				vis = "terfi"
				_push_event(Loc.t("ev_seans_terfi"))
				break
	if vis == "":
		_beautify()
		vis = "cicek"
	res["visible"] = vis
	# seri = kutlama yoğunluğu (ceza YOK — gün dönünce nazik sıfır, kazanılan kalır):
	# 2+ anında bir çiçek; 3+ sakinler meydana toplanır (festival toplanma deseni)
	if streak >= 2:
		_beautify()
	if streak >= 3:
		for p in people:
			if not p.moving and _hf(p.seed + tick) < 0.35:
				p.x = clampf(landmark.x + float(_h(p.seed) % 7) - 3.0, 0.0, float(GW - 1))
				p.y = clampf(landmark.y + float(_h(p.seed * 3) % 7) - 3.0, 0.0, float(GH - 1))
	if streak >= 3 and not unlocked.atolye:
		unlocked.atolye = true
		res.atolye = true
		_convert_unbuilt("shop")
		_push_letter({ "from": Loc.t("from_kasaba"), "who": -1, "kind": "seri", "replied": false,
			"text": Letters.seri_txt("atolye") })
		_push_event(Loc.t("ev_atolye"))
	if streak >= 5 and not unlocked.kutuphane:
		unlocked.kutuphane = true
		res.kutuphane = true
		_convert_unbuilt("library")
		_push_letter({ "from": Loc.t("from_kasaba"), "who": -1, "kind": "seri", "replied": false,
			"text": Letters.seri_txt("kutuphane") })
		_push_event(Loc.t("ev_kutuphane"))
	# zincirin devamı (denetim #12: 5'ten sonra ödül yoktu): toplam seans eşikleri
	for mb in MILESTONE_BUILDINGS:
		if sessions >= mb.at and not unlocked[mb.key]:
			unlocked[mb.key] = true
			res["special"] = true
			_convert_unbuilt(mb.key)
			_push_letter({ "from": Loc.t("from_kasaba"), "who": -1, "kind": "seri", "replied": false, "text": Letters.milestone_txt(mb.key) })
			_push_event(Loc.t(mb.ev))
	# kümülatif seans anıtları (G1.7): 50→500 — tek seferlik, milestones anahtarıyla
	for sr in SESSION_REWARDS:
		if sessions >= sr.at and not milestones.get("ses%d" % int(sr.at), false):
			milestones["ses%d" % int(sr.at)] = true
			_apply_session_reward(sr)
			res["special"] = true
	_push_letter({ "from": Loc.t("from_kasaba"), "who": -1, "kind": "odak", "replied": false,
		"text": Letters.pick(Letters.ODAK, _h(sessions * 97 + tick)) })
	_push_event(Loc.t("ev_seans_bitti"))
	return res

# ============================================================ GÜN OLAYLARI (G1.8)
## Olay uygulanabilir mi (koşullu olaylar; koşulsuzlar hep true)
func _event_ok(id: int) -> bool:
	match id:
		1:   # düğün: boş ev şart
			return not empty_houses().is_empty()
		2:   # hasat şenliği: sonbahar
			return season == 2
		3:   # gökkuşağı: o gün yağmurlu (rain_amount'un gün hash'i) ve kış değil
			return season != 3 and _hf((day() - 1) * 67 + 5) <= 0.28
		5:   # göçebe aile: nüfus tavana yakın değil ve bekleyen yok
			return population() < POP_SOFT_CAP - 30 and pending_family == 0
		7:   # uçurtma: ilkbahar/yaz
			return season <= 1
		9:   # ışık toplayıcısı: melodin kaydedilmiş olmalı (ortam-koşullu nadir ziyaretçi)
			return melody_saved
	return true

func _fire_day_event(d: int) -> void:
	var total := 0
	for e in DAY_EVENTS:
		total += int(e.w)
	var pick := -1
	for attempt in range(3):   # son-3 tekrarını kaydır; 3 denemede olmadıysa o gün sessiz (zararsız)
		var roll := _h(d * 101 + 11 + attempt * 977) % total
		var cand := -1
		for e in DAY_EVENTS:
			roll -= int(e.w)
			if roll < 0:
				cand = int(e.id)
				break
		if not recent_events.has(cand) and _event_ok(cand):
			pick = cand
			break
	if pick == -1:
		return
	recent_events.append(pick)
	while recent_events.size() > 3:
		recent_events.pop_front()
	match pick:
		0:   # gezgin tüccar: handa konaklar, meydana bir hediye bırakır (dilek objesi havuzundan)
			var gift: Dictionary = WISH_TYPES[_h(d * 31) % WISH_TYPES.size()]
			decor.append({ "gx": clampi(landmark.x + 2 + _h(d) % 3, 1, GW - 2), "gy": clampi(landmark.y + 2, 1, GH - 2), "kind": gift.k })
			_push_event(Loc.t("ev_tuccar") % Loc.t("kind_" + str(gift.k)))
			if _hf(d * 43 + 1) < 0.3:
				_push_letter({ "from": Loc.t("from_tuccar"), "who": -1, "kind": "olay", "replied": false, "text": Letters.olay("tuccar") })
		1:   # düğün: çift boş eve taşınır (büyümeye gerçek katkı) + şenlik
			var eh := empty_houses()
			var nb: Dictionary = eh[0]
			for k in range(2):
				var p := _add_person(landmark.x, landmark.y, nb, 1)
				p.age_t = _h(p.seed * 11) % 15000
				p.tx = nb.gx
				p.ty = nb.gy
				p.moving = true
				p.steps = k * 2
				nb.members.append(p)
				movers.append(p)
			festival_t = maxf(festival_t, 0.6)
			_push_event(Loc.t("ev_dugun") % [nb.members[nb.members.size() - 2].name, nb.members[nb.members.size() - 1].name])
			if _hf(d * 43 + 2) < 0.5:
				_push_letter({ "from": Loc.t("from_cift"), "who": -1, "kind": "olay", "replied": false, "text": Letters.olay("dugun") })
		2:   # hasat şenliği: meydan sofrası + çiçekler
			festival_t = 1.0
			_beautify()
			_beautify()
			_push_event(Loc.t("ev_hasat"))
		3:
			rainbow_t = 1.0
			_push_event(Loc.t("ev_gokkusagi"))
		4:
			balloon_t = 1.0
			_push_event(Loc.t("ev_balon"))
		5:
			pending_family = 2 + _h(d * 17) % 2
			_push_letter({ "from": Loc.t("from_aile"), "who": -1, "kind": "olay", "replied": false, "text": Letters.olay("gocebe") })
			_push_event(Loc.t("ev_gocebe"))
		6:
			_push_event(Loc.t("ev_kus"))
		7:
			kite_t = 1.0
			_push_event(Loc.t("ev_ucurtma"))
		8:   # yıldız yağmuru: bedava dilek belirir
			starfall_t = 1.0
			_push_event(Loc.t("ev_yildiz"))
			if wish == null and not people.is_empty():
				var who = people[_h(d * 7) % people.size()]
				if who.stage == 1:
					wish = { "who": who, "type": _h(d * 3) % WISH_TYPES.size() }
		9:
			_push_event(Loc.t("ev_ziyaretci"))
			_push_letter({ "from": Loc.t("from_toplayici"), "who": -1, "kind": "olay", "replied": false, "text": Letters.olay("ziyaretci") })

## Seans anıtını kur (G1.7): süsler meydan/çayır çevresine deterministik yerleşir.
func _apply_session_reward(sr: Dictionary) -> void:
	festival_t = 1.0
	if sr.kind == "kule_yaldizi":
		tower_gilded = true
	elif sr.kind == "fener_dizisi":
		# 3 fener meydan çevresine — ışık bütçesi: lamba havuzuna girer, bloom min(1,14/n) zaten böler
		for k in range(3):
			lamps.append({ "gx": landmark.x - 2 + k * 2, "gy": landmark.y + 2, "ph": _hf(k * 71) * TAU })
	else:
		var off: int = int(sr.at) % 5
		decor.append({ "gx": clampi(landmark.x - 3 + off, 1, GW - 2), "gy": clampi(landmark.y + 1 + (off % 3), 1, GH - 2), "kind": sr.kind })
	_push_letter({ "from": Loc.t("from_kasaba"), "who": -1, "kind": "seri", "replied": false, "text": Letters.session_txt(sr.kind) })
	_push_event(Loc.t(sr.ev))

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
		"text": Letters.dilek(t.k, _h(tick * 11 + px)) })
	stat_wishes += 1
	_push_event(Loc.t("ev_dilek_gercek") % who.name)
	wish = null
	return Vector2i(px, py)

func wish_text() -> String:
	if wish == null:
		return ""
	return Loc.t("wish_fmt") % [wish.who.name, Loc.t("wtxt_" + str(WISH_TYPES[wish.type].k))]

## Mektuba içtenlikle yanıt: bond+1, sakin atkı kazanır (bağın görünür nişanı).
## lid = kalıcı kimlik (index DEĞİL — sim push_front yapınca index kayıyor, yanlış mektup
## yanıtlanıyordu; run_ui.gd bu senaryoyu test eder).
func reply_letter(lid: int) -> void:
	var l = null
	for cand in letters:
		if int(cand.get("lid", -1)) == lid:
			l = cand
			break
	if l == null or l.replied:
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
	_push_event(Loc.t("ev_yanit") % l.from)

func _plant_memory_tree(p: Dictionary) -> void:
	for t2 in range(40):
		var gx: int = frontier + 2 + _h(p.seed + t2) % maxi(1, GW - frontier - 4)
		var gy: int = 2 + _h(p.seed * 3 + t2) % maxi(1, GH - 4)
		if not road_set.has(Vector2i(gx, gy)):
			mem_trees.append({"gx": gx, "gy": gy, "name": p.name})
			if mem_trees.size() > 40:
				mem_trees.pop_front()
			return
