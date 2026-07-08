extends Node2D
## NEFES render (ANAYASA: render World'ü yalnız OKUR, asla yazmaz).
## HTML v15 render() → Godot _draw. Kozmetik (kuş/bulut/kar/kişi-easing) burada per-frame;
## sim (world.gd) grid'i sürer. A0: yapısal parite + temel akşam ışığı.
## Partikül/lamba-kaskadı/ateşböceği/pencere-bloom-glow = A2; native glow = B2.

const VW := 960.0
const VH := 360.0
var CW := VW / float(World.GW)
var CH := VH / float(World.GH)

var world: World = null
var audio = null   # ses motoru (opsiyonel; olay sesleri için)

# renkler MERKEZİ paletten (scripts/palette.gd — CLAUDE.md §1); yerel alias yalnız kısa erişim
const SEASONS := Palette.SEASONS
const ROOF_COLS := Palette.ROOF_COLS
const PCOL := Palette.PCOL

# --- kozmetik durum (render-only; determinizmi etkilemez) ---
var _t := 0.0
var _wind := 0.5
var birds: Array = []
var clouds: Array = []
var snow: Array = []
var rain: Array = []
var _ppos := {}   # kişi seed -> Vector2 (piksel easing hedefi)
var hovered = null            # imlecin işaret ettiği sakin (Dictionary) ya da null — main.hovered_person okur
var hovered_px := Vector2.ZERO

# --- partikül sistemi (A2; native GPUParticles2D = B2) ---
var parts: Array = []            # {pos, vel, life, decay, type, size, seed}
var _pop_rings: Array = []       # {pos, t, kind}  (inşaat halkası / veda yıldızı)
var _fx_seed := 0                # partikül jitter için render-side sayaç (sim'e dokunmaz)
var _prev_building = null         # inşaat bitiş tespiti (ref)
var _lamp_on: Array = []          # lamba başına on-durumu (kaskad kıvılcımı için)
var _known_seeds := {}            # doğum tespiti
var _prev_last_memtree = null     # veda tespiti (son anı ağacı ref)
var _prev_chime := 0.0            # saat başı kuş ürkmesi
var _prev_fest := 0.0             # festival nabzı tespiti
var _season_t := 0.0

var _bg: Node2D = null            # statik katman (perf: yalnız imza değişince redraw)
var _sorted_b: Array = []         # gy-sıralı bina önbelleği (her karede sort ETME)
var _sorted_count := -1

func _ready() -> void:
	_bg = load("res://scripts/town_bg.gd").new()
	_bg.view = self
	_bg.z_index = -1
	add_child(_bg)
	# seedli kozmetik başlangıç (randf YOK — hf ile)
	for i in range(4):
		var bsp := 0.35 + Rng.hf(i) * 0.4
		birds.append({"x": Rng.hf(i * 17) * VW, "y": 16.0 + Rng.hf(i * 7) * 50.0, "sp": bsp, "base": bsp, "ph": Rng.hf(i * 3) * TAU})
	for i in range(5):
		clouds.append({"x": Rng.hf(i * 29) * VW, "y": 6.0 + Rng.hf(i * 11) * 36.0, "w": 60.0 + float(Rng.h(i) % 80), "sp": 0.04 + Rng.hf(i) * 0.05})
	for i in range(70):
		snow.append({"x": Rng.hf(i * 5) * VW, "y": Rng.hf(i * 13) * VH, "sp": 0.3 + Rng.hf(i * 3) * 0.6, "dr": Rng.hf(i * 7) * 2.0})
	for i in range(80):
		rain.append({"x": Rng.hf(i * 11) * VW, "y": Rng.hf(i * 19) * VH, "sp": 4.0 + Rng.hf(i * 3) * 3.0})

func _process(delta: float) -> void:
	if world == null:
		return
	_t += delta
	_wind = 0.5 + 0.5 * sin(_t * 0.6)
	var step := delta * 14.0   # HTML ~14fps his
	for bd in birds:
		bd.sp = move_toward(bd.sp, bd.base, delta * 0.9)   # ürkme sonrası yavaşça normale
		bd.x += bd.sp * (1.0 + _wind) * step
		if bd.x > VW + 20.0: bd.x = -20.0
		bd.ph += 0.3 * step
	for cl in clouds:
		cl.x += cl.sp * step
		if cl.x > VW + cl.w: cl.x = -cl.w
	if world.rain_amount() > 0.0:
		for rd in rain:
			rd.y += rd.sp * step
			rd.x -= rd.sp * 0.25 * step
			if rd.y > VH:
				rd.y = -6.0
				rd.x = Rng.hf(int(rd.x * 7.0) + int(_t)) * VW
	if SEASONS[world.season].snow:
		for sf in snow:
			sf.y += sf.sp * step
			sf.x += sin(_t * 1.2 + sf.dr) * 0.5
			if sf.y > VH: sf.y = -4.0; sf.x = Rng.hf(int(sf.dr * 1000.0) + int(_t)) * VW
	# kişi piksel-easing (0.14 his, delta-uyumlu)
	var f := clampf(delta * 9.0, 0.0, 1.0)
	for p in world.people:
		var target := Vector2(p.x * CW + CW * 0.5, p.y * CH + CH * 0.5)
		if not _ppos.has(p.seed):
			_ppos[p.seed] = target
		else:
			_ppos[p.seed] = _ppos[p.seed].lerp(target, f)
	# sakin hover (B+): imleç ~10px içindeki en yakın sakin (isimli sakinler görünür kimlik kazansın)
	hovered = null
	var mp := get_global_mouse_position()
	var best := 100.0
	for p in world.people:
		var pos: Vector2 = _ppos.get(p.seed, Vector2(p.x * CW + CW * 0.5, p.y * CH + CH * 0.5))
		var d2 := mp.distance_squared_to(pos)
		if d2 < best:
			best = d2
			hovered = p
			hovered_px = pos
	_emit_events(delta)
	_update_parts(delta)
	queue_redraw()

func _mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0.0, 1.0))

## Gün eğrisi renk yolu: düz koyulaştırma yerine hafif morumsu hue kayması + doygunluk artışı
## (sınırlı-palet ramp dersi: düz value ramp'ı soluk kalır). Palet kilidi korunur — kaynak
## renkler SEASONS/sabitlerden; bu yalnız ara-lerp yolu.
func _dusk(c: Color, k: float) -> Color:
	k = clampf(k, 0.0, 1.6)
	return Color.from_hsv(fmod(c.h + 0.045 * k + 1.0, 1.0), clampf(c.s * (1.0 + 0.18 * k), 0.0, 1.0), clampf(c.v * (1.0 - 0.42 * k), 0.0, 1.0))

func _draw() -> void:
	if world == null:
		return
	var S: Dictionary = SEASONS[world.season]
	var ev := world.evening()
	var fr := world.frontier
	# GÖKYÜZÜ/ZEMİN/NEHİR-TABANI/YOL/ÇAYIR-DETAY/PLAZA/ANI-AĞAÇLARI → _bg (town_bg.gd, statik katman)

	# yıldızlar + bulutlar
	if ev > 0.35:
		var sc := Color(1.0, 0.94, 0.82, (ev - 0.35) * 0.7)
		for s in range(28):
			var sx := float((s * 151) % int(VW))
			var sy := float((s * 57) % int(VH * 0.16))
			if (s * 7 + int(_t * 3.0)) % 13 < 2: continue
			draw_rect(Rect2(sx, sy, 1.5, 1.5), sc)
	for cl in clouds:
		var cc := Color(0.82, 0.63, 0.67, 0.16 * (1.0 - ev * 0.6))
		draw_circle(Vector2(cl.x, cl.y), cl.w / 4.0, cc)
		draw_circle(Vector2(cl.x + cl.w * 0.3, cl.y - 3.0), cl.w / 5.0, cc)

	# ---- NEHİR IŞILTISI (taban _bg'de; canlı su çizgisi burada) ----
	for rc in world.river:
		var rp := sin(rc.x * 0.5 + _t * 2.4) * sin(rc.y * 0.7 - _t * 1.8)
		draw_rect(Rect2(rc.x * CW, rc.y * CH + rp * 2.0, CW + 1.0, 1.5), Color(0.86, 0.92, 1.0, 0.05 + 0.04 * rp + ev * 0.05))

	# ---- ÇEŞMELER ----
	for f in world.fountains:
		var X: float = f.gx * CW + CW / 2.0
		var Y: float = f.gy * CH + CH / 2.0
		draw_circle(Vector2(X, Y), CW * 0.42, Color8(106,90,96))
		draw_circle(Vector2(X, Y), CW * 0.27, Color8(122,154,184))
		draw_circle(Vector2(X, Y - 1.0), 1.4, Color(0.86, 0.94, 1.0, 0.4 + 0.3 * sin(_t * 4.0)))

	# ---- DİLEK OBJELERİ (bank/kuş yuvası/posta kutusu/rüzgâr gülü — az sayıda, dinamik) ----
	for dc in world.decor:
		var X: float = dc.gx * CW + CW / 2.0
		var Y: float = dc.gy * CH + CH / 2.0
		match dc.kind:
			"bank":   # palet: yol kahvesi (ilkbahar road tonu — ahşap)
				draw_rect(Rect2(X - 3.5, Y - 1.0, 7.0, 2.0), Color8(120, 104, 92))
				draw_rect(Rect2(X - 3.5, Y - 3.2, 7.0, 1.2), Color8(120, 104, 92))
			"kuş yuvası":   # palet: lamba direği grisi + c99b46 çatı koyusu
				draw_rect(Rect2(X - 0.6, Y - 4.0, 1.2, 5.0), Color8(90, 76, 84))
				draw_rect(Rect2(X - 2.0, Y - 6.5, 4.0, 3.0), Color8(168, 130, 58))
				if sin(_t * 0.7 + dc.gx) > 0.6:   # ara sıra konuk kuş
					draw_circle(Vector2(X, Y - 7.5), 1.1, Color(0.24, 0.18, 0.22))
			"posta kutusu":
				draw_rect(Rect2(X - 0.5, Y - 2.5, 1.0, 3.0), Color8(90, 76, 84))
				draw_rect(Rect2(X - 1.8, Y - 5.0, 3.6, 2.6), Color8(194, 90, 74))
			"rüzgâr gülü":
				draw_rect(Rect2(X - 0.5, Y - 6.0, 1.0, 6.0), Color8(90, 76, 84))
				var wa := _t * (1.5 + _wind * 2.0)
				draw_line(Vector2(X, Y - 6.0), Vector2(X, Y - 6.0) + Vector2(cos(wa), sin(wa)) * 3.0, Color8(232, 220, 200), 1.0)
				draw_line(Vector2(X, Y - 6.0), Vector2(X, Y - 6.0) - Vector2(cos(wa), sin(wa)) * 3.0, Color8(201, 155, 70), 1.0)

	# ---- KASABA AĞAÇLARI (sway animasyonlu → dinamik katmanda) ----
	var tree_col := _dusk(S.tree, ev * 0.45)
	for tr in world.trees:
		var X: float = tr.gx * CW + CW / 2.0
		var Y: float = tr.gy * CH + CH / 2.0
		var sw := sin(_t * 0.6 + tr.sway * 6.0) * 1.2
		draw_circle(Vector2(X, Y + 3.0), CW * 0.4, Color(0.12, 0.16, 0.12, 0.4))
		draw_rect(Rect2(X - 1.0, Y - 1.0, 2.0, CH * 0.4), Color8(90,122,82))
		draw_circle(Vector2(X + sw, Y - 2.0), CW * 0.32, tree_col)

	# ---- BİNALAR (geri→ön; sıralama önbelleği — binalar yer değiştirmez, her karede sort ETME) ----
	if world.buildings.size() != _sorted_count:
		_sorted_count = world.buildings.size()
		_sorted_b = world.buildings.duplicate()
		_sorted_b.sort_custom(func(a, b): return a.gy < b.gy)
	for b in _sorted_b:
		if b.build_prog <= 0.0: continue
		_draw_building(b, ev)

	# ---- SAAT KULESİ ----
	_draw_landmark(ev)

	# ---- KİŞİLER ----
	for p in world.people:
		var pos: Vector2 = _ppos.get(p.seed, Vector2(p.x * CW + CW * 0.5, p.y * CH + CH * 0.5))
		var walking := pos.distance_to(Vector2(p.x * CW + CW * 0.5, p.y * CH + CH * 0.5)) > 0.8
		var bob := (sin(_t * 20.0 + p.seed) * 1.1) if walking else 0.0
		var r := 2.1 if p.stage == 0 else (2.8 if p.stage == 2 else 3.1)
		draw_circle(Vector2(pos.x, pos.y + bob + 3.0), r + 0.4, Color(0.17, 0.12, 0.18, 0.35))
		var col: Color = PCOL[p.col]
		if p.stage == 2: col.a = 0.85
		draw_circle(Vector2(pos.x, pos.y + bob), r, col)
		if p.scarf:
			draw_arc(Vector2(pos.x, pos.y + bob), r + 1.6, 0.0, TAU, 16, Color(1.0, 0.81, 0.48, 0.9), 1.2)
		if p == hovered:   # hover vurgusu: ince halka (ışık kaynağı değil — bütçe delinmez)
			draw_arc(Vector2(pos.x, pos.y + bob), r + 3.0, 0.0, TAU, 20, Color(1.0, 0.94, 0.82, 0.55), 1.0)

	# ---- LAMBALAR (temel; kaskad/parıltı A2) ----
	for L in world.lamps:
		var X: float = L.gx * CW + CW / 2.0
		var Y: float = L.gy * CH + CH / 2.0
		draw_rect(Rect2(X - 0.7, Y - CH * 0.35, 1.4, CH * 0.7), _mix(Color8(90,76,84), Color8(40,34,46), ev * 0.6))
		var on := ev > 0.15
		var thresh: float = 0.15 + (L.ph / TAU) * 0.5
		if on and world.light_curve >= thresh:
			draw_circle(Vector2(X, Y - CH * 0.35), CW * 1.4, Color(1.0, 0.81, 0.48, 0.10 * world.light_curve))
			draw_circle(Vector2(X, Y - CH * 0.35), 1.6, Color(1.0, 0.9, 0.66))
		else:
			draw_circle(Vector2(X, Y - CH * 0.35), 1.6, Color8(120,110,120))

	# ---- PENCERE BLOOM (bütçeli, temel daire; native glow B2) ----
	var bloom_budget := minf(1.0, 14.0 / float(maxi(1, world.lit_count())))
	for b in world.buildings:
		if not b.awake or b.build_prog < 1.0 or ev < 0.15: continue
		if b.lit_frac < 0.1: continue
		var X: float = (b.gx + 0.5) * CW
		var Y: float = (b.gy + 0.2) * CH
		draw_circle(Vector2(X, Y), CW * 1.4, Color(1.0, 0.75, 0.43, 0.18 * ev * bloom_budget))

	# ---- KUŞLAR ----
	for bd in birds:
		var wing := sin(bd.ph) * 3.0
		draw_polyline([Vector2(bd.x - 4.0, bd.y + wing), Vector2(bd.x, bd.y), Vector2(bd.x + 4.0, bd.y + wing)], Color(0.24, 0.18, 0.22, 0.55), 1.5)

	# ---- BACA DUMANI ----
	for b in world.buildings:
		if not b.awake or not b.chimney or b.build_prog < 1.0: continue
		var X: float = (b.gx + 0.7) * CW
		var Y: float = b.gy * CH - CH * 0.3
		for pi in range(3):
			var tt := fmod(_t * 5.0 + b.seed + pi * 40.0, 120.0) / 120.0
			draw_circle(Vector2(X + sin(tt * 6.0 + b.seed) * 4.0, Y - tt * 26.0), 1.4 + tt * 5.0, Color(0.78, 0.71, 0.75, 0.1 * (1.0 - tt)))

	# ---- YAĞMUR (Faz D hava durumu; ses kanalının görsel karşılığı) ----
	var ra := world.rain_amount()
	if ra > 0.0:
		var rcol := Color(0.72, 0.78, 0.9, 0.30 * ra)
		for rd in rain:
			draw_line(Vector2(rd.x, rd.y), Vector2(rd.x - 1.6, rd.y + 6.5), rcol, 1.0)

	# ---- KAR ----
	if S.snow:
		for sf in snow:
			draw_rect(Rect2(sf.x, sf.y, 1.6, 1.6), Color(1.0, 1.0, 1.0, 0.75))

	# ---- PARTİKÜLLER + ATEŞBÖCEĞİ ----
	_draw_parts(ev)

	# ---- VİNYET ----
	draw_rect(Rect2(0, 0, VW, VH), Color(0.17, 0.12, 0.18, 0.14 * ev))

func _draw_building(b: Dictionary, ev: float) -> void:
	var bp: float = 1.0 if b.build_prog >= 1.0 else maxf(0.0, _ease_out_back(b.build_prog) * b.build_prog)
	var X: float = b.gx * CW
	var Yb: float = b.gy * CH + CH
	var full_h := CH * 1.7
	var H := full_h * bp
	var Y: float = Yb - H
	var W := CW - 2.0
	draw_rect(Rect2(X + 2.0, Yb - 3.0, W, 3.0), Color(0.17, 0.12, 0.18, 0.4))
	var awake: bool = b.awake
	var wall: Color = _mix(Color8(201,168,146), Color8(150,120,120), ev * 0.4) if awake else _mix(Color8(120,100,110), Color8(70,58,72), ev * 0.5)
	draw_rect(Rect2(X + 1.0, Y, W, H), wall)
	if b.type == "sera":   # camsı cephe + filizler (kışın bile yeşil)
		draw_rect(Rect2(X + 1.0, Y, W, H), Color(0.78, 0.9, 0.88, 0.35))
		for k in range(3):
			draw_circle(Vector2(X + 3.0 + k * (W - 6.0) / 2.0, Y + H - 2.5), 1.3, Color8(122, 155, 106))
	if bp < 0.99:
		draw_rect(Rect2(X + 1.0, Y, W, H), Color(0.59, 0.47, 0.35, 0.5), false, 1.0)
		return
	# çatı (3 tip + özel binalar: rasathane kubbe / hamam ikiz kubbe)
	var pair: Array = ROOF_COLS[b.roof]
	var r_hi: Color = _mix(pair[0], pair[0].darkened(0.4), ev * 0.4)
	var r_lo: Color = _mix(pair[1], pair[1].darkened(0.4), ev * 0.4)
	var y_top: float = Y - CH * 0.55
	if b.type == "rasathane":
		var dome: Color = _mix(Color8(106,134,168), Color8(88,111,146), ev * 0.4)   # 6a86a8 çatı paleti
		draw_circle(Vector2(X + W / 2.0 + 0.5, Y + 1.0), W * 0.5, dome)
		draw_line(Vector2(X + W / 2.0, Y - CH * 0.1), Vector2(X + W * 0.95, Y - CH * 0.6), Color8(232,220,200), 1.2)
	elif b.type == "hamam":
		draw_circle(Vector2(X + W * 0.34, Y + 0.5), W * 0.30, r_hi)
		draw_circle(Vector2(X + W * 0.74, Y + 1.0), W * 0.24, r_lo)
		for k in range(2):   # süzülen buhar
			var st := fmod(_t * 0.4 + k * 0.5, 1.0)
			draw_circle(Vector2(X + W * 0.34 + k * W * 0.4, Y - 3.0 - st * 8.0), 1.2 + st * 1.5, Color(0.92, 0.92, 0.95, 0.25 * (1.0 - st)))
	elif b.roof_type == 1:
		draw_colored_polygon([Vector2(X, Y), Vector2(X + W / 2.0 + 1.0, y_top), Vector2(X + W + 1.0, Y)], r_lo)
		draw_colored_polygon([Vector2(X, Y), Vector2(X + W / 2.0 + 1.0, y_top), Vector2(X + W / 2.0 + 1.0, Y)], r_hi)
	elif b.roof_type == 2:
		draw_colored_polygon([Vector2(X, Y), Vector2(X + W * 0.25, y_top), Vector2(X + W * 0.75, y_top), Vector2(X + W, Y)], r_lo)
		draw_rect(Rect2(X + W * 0.25, y_top, W * 0.5, 2.0), r_hi)
	else:
		draw_rect(Rect2(X, Y - CH * 0.28, W + 1.0, CH * 0.32), r_hi)
		draw_rect(Rect2(X, Y - CH * 0.28, W + 1.0, 2.5), r_lo)
	# pencereler (bazıları yanar, evening ölçekli)
	for r2 in range(2):
		var wy: float = Y + CH * 0.25 + r2 * (H - CH * 0.7) / 2.0
		var wx: float = X + 3.0
		var ww: float = W - 6.0
		var wh: float = maxf(3.0, (H - CH * 0.7) / 2.0 - 3.0)
		var is_lit: bool = awake and (world._hf(b.seed + r2 * 17) < b.lit_frac)
		if is_lit:
			var fl := 0.85 + 0.15 * sin(_t * 3.0 + b.seed + r2)
			draw_rect(Rect2(wx, wy, ww, wh), Color(1.0, 0.81, 0.48, fl))
		else:
			draw_rect(Rect2(wx, wy, ww, wh), Color(0.23, 0.18, 0.23, 0.85))
	if b.type == "shop" and awake:
		draw_rect(Rect2(X + 1.0, Y + CH * 0.1, W, 3.0), ROOF_COLS[b.roof][0])
	if b.type == "library":   # cephede renkli kitap sırtları (çatı paletinden)
		for bi in range(4):
			draw_rect(Rect2(X + 2.5 + bi * 2.6, Y + H - CH * 0.42, 1.8, CH * 0.32), ROOF_COLS[(b.seed + bi) % 5][0])
	# end-game güzelleştirmesi (Faz D): çiçekli pencere kutuları (mevsim çiçek paleti)
	if b.get("bloom", false):
		var fcol: Color = SEASONS[world.season].flowers[b.seed % 3]
		draw_rect(Rect2(X + 3.0, Y + CH * 0.25 + maxf(3.0, (H - CH * 0.7) / 2.0 - 3.0), W - 6.0, 1.8), fcol)

func _draw_landmark(ev: float) -> void:
	var b := world.landmark
	var LX := b.x * CW
	var LY := b.y * CH
	var tw := CW * 1.6
	var th := CH * 4.4
	var lc := world.light_curve
	# beacon halo
	draw_circle(Vector2(LX + tw / 2.0, LY - th * 0.5), tw * 2.2, Color(1.0, 0.82, 0.55, 0.04 + 0.16 * lc))
	# gövde
	draw_rect(Rect2(LX - 3.0, LY + CH - 3.0, tw + 6.0, 3.0), Color(0.17, 0.12, 0.18, 0.4))
	draw_rect(Rect2(LX, LY - th + CH, tw, th), _mix(Color8(216,188,160), Color8(150,120,120), ev * 0.4))
	draw_rect(Rect2(LX + tw * 0.62, LY - th + CH, tw * 0.38, th), Color(0.17, 0.12, 0.18, 0.2))
	draw_rect(Rect2(LX, LY - th + CH, tw * 0.18, th), Color(1.0, 0.94, 0.82, 0.22))
	# kadran
	var cf_y := LY - th + CH * 1.5
	var cr := tw * 0.42
	var pulse := 1.0 + (sin(world.chime_t * PI) * 0.5 if world.chime_t > 0.0 else 0.0)
	draw_circle(Vector2(LX + tw / 2.0, cf_y), cr * 1.6 * pulse, Color(1.0, 0.88, 0.59, 0.15 + 0.4 * lc))
	draw_circle(Vector2(LX + tw / 2.0, cf_y), cr, Color8(255,244,214))
	var ang := (world.time_of_day / 12.0) * TAU
	draw_line(Vector2(LX + tw / 2.0, cf_y), Vector2(LX + tw / 2.0 + cos(ang - PI / 2.0) * cr * 0.6, cf_y + sin(ang - PI / 2.0) * cr * 0.6), Color8(90,63,82), 1.5)
	draw_line(Vector2(LX + tw / 2.0, cf_y), Vector2(LX + tw / 2.0 + cos(ang * 12.0 - PI / 2.0) * cr * 0.4, cf_y + sin(ang * 12.0 - PI / 2.0) * cr * 0.4), Color8(90,63,82), 1.5)
	# çatı üçgeni
	draw_colored_polygon([Vector2(LX - 3.0, LY - th + CH), Vector2(LX + tw / 2.0, LY - th - CH * 0.8), Vector2(LX + tw + 3.0, LY - th + CH)], Color8(168,90,72))
	draw_circle(Vector2(LX + tw / 2.0, LY - th - CH * 0.8), 2.5, Color8(255,230,168))

func _ease_out_back(t: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(t - 1.0, 3.0) + c * pow(t - 1.0, 2.0)

# dış tetikli kutlama (dilek/odak) — mote patlaması
func celebrate(gx: int, gy: int) -> void:
	_spawn(Vector2((gx + 0.5) * CW, (gy + 0.5) * CH), "mote", 9, { "sp": 1.0, "up": true, "decay": 0.02 })

# ============================================================ PARTİKÜLLER (A2)
func _spawn(pos: Vector2, type: String, n: int, opt: Dictionary = {}) -> void:
	if parts.size() > 240:
		parts = parts.slice(parts.size() - 240)
	var sp0: float = opt.get("sp", 0.5)
	var up: bool = opt.get("up", false)
	var decay: float = opt.get("decay", 0.02)
	var size: float = opt.get("size", 2.0)
	var vy0: float = opt.get("vy", 0.0)
	for i in range(n):
		_fx_seed += 1
		var a := Rng.hf(_fx_seed * 13 + 7) * TAU
		var sp := sp0 * (0.5 + Rng.hf(_fx_seed * 31))
		var vy := (-absf(sin(a)) if up else sin(a)) * sp + vy0
		parts.append({"pos": pos, "vel": Vector2(cos(a) * sp, vy), "life": 1.0, "decay": decay, "type": type, "size": size, "seed": _fx_seed})

func _emit_events(delta: float) -> void:
	# İNŞAAT: yükselirken toz, bitişte 10-mote patlaması
	var cur = world.building_now
	if _prev_building != null and cur == null:
		_spawn(Vector2((_prev_building.gx + 0.5) * CW, _prev_building.gy * CH), "mote", 10, {"sp": 1.1, "up": true, "decay": 0.02})
	if cur != null:
		_fx_seed += 1
		if Rng.hf(_fx_seed) < delta * 4.0:
			_spawn(Vector2((cur.gx + 0.5) * CW, (cur.gy + 1) * CH), "dust", 1, {"sp": 0.6, "decay": 0.03})
	_prev_building = cur

	# LAMBA KASKADI: eşiği yeni geçen lamba kıvılcım saçar
	if _lamp_on.size() != world.lamps.size():
		_lamp_on.resize(world.lamps.size())
		_lamp_on.fill(false)
	var ev := world.evening()
	for i in range(world.lamps.size()):
		var L = world.lamps[i]
		var thresh: float = 0.15 + (L.ph / TAU) * 0.5
		var on: bool = ev > 0.15 and world.light_curve >= thresh
		if on and not _lamp_on[i]:
			_spawn(Vector2(L.gx * CW + CW / 2.0, L.gy * CH + CH / 2.0 - CH * 0.35), "spark", 5, {"sp": 0.9, "decay": 0.05})
			if audio != null:
				audio.event("lamp")
		_lamp_on[i] = on

	# DOĞUM: yeni stage-0 sakin → 7 taç yaprağı
	for p in world.people:
		if not _known_seeds.has(p.seed):
			_known_seeds[p.seed] = true
			if p.stage == 0 and world.tick > 0:
				var home = p.home
				var hx: int = home.gx if home != null else int(p.x)
				var hy: int = home.gy if home != null else int(p.y)
				_spawn(Vector2((hx + 0.5) * CW, hy * CH), "petal", 7, {"sp": 0.4, "decay": 0.012})
				if audio != null:
					audio.event("birth")

	# VEDA: yeni anı ağacı → yukarı süzülen yıldız
	var mtn := world.mem_trees.size()
	if mtn > 0:
		var last = world.mem_trees[mtn - 1]
		if last != _prev_last_memtree:
			_pop_rings.append({"pos": Vector2(last.gx * CW + CW / 2.0, last.gy * CH), "t": 1.0, "kind": "star"})
			if _prev_last_memtree != null and audio != null:
				audio.event("farewell")   # ilk kadraj başlangıç durumunu seslendirmesin
			_prev_last_memtree = last

	# SAAT BAŞI: kuşlar ürker (chime_t 1'e sıçradığında)
	if world.chime_t > 0.9 and _prev_chime <= 0.9:
		for bd in birds:
			bd.sp += 1.2
	_prev_chime = world.chime_t

	# FESTİVAL (Faz D): nabız 1'e sıçrayınca meydanda kutlama + şenlik boyunca mevsim serpintisi
	if world.festival_t > 0.9 and _prev_fest <= 0.9:
		celebrate(world.landmark.x, world.landmark.y - 1)
		if audio != null:
			audio.event("festival")
	_prev_fest = world.festival_t
	if world.festival_t > 0.0:
		_fx_seed += 1
		if Rng.hf(_fx_seed) < delta * 3.0:
			# mevsim serpintisi: bahar taçyaprağı / yaz su ışıltısı / güz yaprağı / kış ışık motesi
			var fkind: String = ["petal", "stardust", "leaf", "mote"][world.season]
			var fx: float = (world.landmark.x + 0.5) * CW + (Rng.hf(_fx_seed * 7) - 0.5) * CW * 8.0
			_spawn(Vector2(fx, world.landmark.y * CH - CH * 2.0), fkind, 1, {"decay": 0.01, "sp": 0.3})

	# MEVSİM: sonbahar yaprak / ilkbahar taç yaprağı serpintisi (~1sn'de bir)
	_season_t += delta
	if _season_t >= 1.0 and not world.trees.is_empty():
		_season_t = 0.0
		_fx_seed += 1
		var tr = world.trees[Rng.h(_fx_seed) % world.trees.size()]
		var sname: String = SEASONS[world.season].name
		if sname == "sonbahar":
			_spawn(Vector2(tr.gx * CW + CW / 2.0, tr.gy * CH), "leaf", 1, {"decay": 0.008})
		elif sname == "ilkbahar":
			_spawn(Vector2(tr.gx * CW + CW / 2.0, tr.gy * CH), "petal", 1, {"decay": 0.008})

func _update_parts(delta: float) -> void:
	var stepf := delta * 14.0
	var survivors: Array = []
	for P in parts:
		P.life -= P.decay * stepf
		if P.life <= 0.0:
			continue
		P.pos += P.vel * stepf
		match P.type:
			"mote": P.vel.y -= 0.01 * stepf
			"dust": P.vel.y -= 0.005 * stepf
			"petal": P.vel = Vector2(sin(_t * 4.0 + P.seed) * 0.3, sin(_t * 6.0 + P.seed) * 0.15 - 0.25)
			"leaf": P.vel = Vector2(sin(_t * 3.0 + P.seed) * 0.5, 0.35 + sin(_t * 4.5 + P.seed) * 0.1)
			"spark": P.vel.y += 0.02 * stepf
		survivors.append(P)
	parts = survivors
	# pop halkaları / veda yıldızı
	var rings: Array = []
	for R in _pop_rings:
		R.t -= 0.03 * stepf
		if R.t <= 0.0:
			continue
		if R.kind == "star":
			R.pos.y -= 0.8 * stepf
			_fx_seed += 1
			if Rng.hf(_fx_seed) < delta * 8.0:
				_spawn(R.pos + Vector2(0, 3), "stardust", 1, {"sp": 0.15, "decay": 0.03})
		rings.append(R)
	_pop_rings = rings

func _draw_parts(ev: float) -> void:
	for P in parts:
		var l: float = P.life
		match P.type:
			"mote": draw_rect(Rect2(P.pos, Vector2(P.size, P.size)), Color(1.0, 0.88, 0.59, l * 0.8))
			"dust": draw_circle(P.pos, maxf(0.5, P.size * (1.6 - l)), Color(0.78, 0.71, 0.63, l * 0.35))
			"petal": draw_rect(Rect2(P.pos, Vector2(2, 2)), Color(0.94, 0.75, 0.82, l * 0.85))
			"leaf": draw_rect(Rect2(P.pos, Vector2(2.2, 1.6)), Color(0.78, 0.47, 0.22, l * 0.8))
			"stardust": draw_rect(Rect2(P.pos, Vector2(1.4, 1.4)), Color(0.9, 0.86, 1.0, l * 0.7))
			"spark": draw_rect(Rect2(P.pos, Vector2(1.5, 1.5)), Color(1.0, 0.94, 0.7, l))
	for R in _pop_rings:
		if R.kind == "star":
			draw_circle(R.pos, 2.2, Color(0.9, 0.86, 1.0, R.t))
			draw_rect(Rect2(R.pos - Vector2(4, 0.5), Vector2(8, 1)), Color(0.9, 0.86, 1.0, R.t * 0.5))
			draw_rect(Rect2(R.pos - Vector2(0.5, 4), Vector2(1, 8)), Color(0.9, 0.86, 1.0, R.t * 0.5))
	# ateşböcekleri (ışık bütçesi: sabit 8, evening>0.5)
	if ev > 0.5:
		var span := maxi(1, int(VW - (world.frontier + 4) * CW))
		for i in range(8):
			var fx := (world.frontier + 3) * CW + float(Rng.h(i * 77) % span) + sin(_t * 2.0 + i * 2.1) * 18.0
			var fy := VH * 0.2 + float(Rng.h(i * 31) % int(VH * 0.7)) + cos(_t * 1.7 + i) * 10.0
			var tw := 0.4 + 0.6 * absf(sin(_t * 3.0 + i * 1.7))
			draw_circle(Vector2(fx, fy), 1.3 + tw, Color(0.86, 1.0, 0.63, 0.5 * tw * (ev - 0.4)))
