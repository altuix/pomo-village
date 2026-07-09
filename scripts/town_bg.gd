extends Node2D
## NEFES statik arka plan katmanı (perf bütçesi — nişin 1 no'lu şikâyeti CPU).
## Gökyüzü/zemin/nehir tabanı/yol/çayır detayı/plaza/anı ağaçları her karede DEĞİŞMEZ:
## yalnız imza (mevsim, frontier, kuantize akşam, yol/anı-ağacı sayısı) değişince yeniden çizilir.
## Gündüz/gecede hiç redraw yok; alacakaranlıkta en çok EV_QUANT adım. Animasyonlu her şey
## (parıltı, su ışıltısı, sakin, bina, partikül) üstteki TownView'da kalır.

var view: Node2D = null   # TownView (palet + _mix/_dusk helper'ları oradan — tek kaynak)
var world = null

const EV_QUANT := 32   # akşam eğrisi kuantizasyonu: alacakaranlık boyunca ~32 redraw (kare başı değil)

var _sig := []

func _process(_d: float) -> void:
	if view == null or view.world == null:
		return
	world = view.world
	# sezon geçişi (G3): son %15 dilimde 12 kademeli blend → devir yumuşar, redraw sayısı sınırlı
	var su := float(world.season_tick) / float(World.SEASON_TICKS)
	var sblend := int(clampf((su - Palette.SEASON_BLEND_START) / (1.0 - Palette.SEASON_BLEND_START), 0.0, 1.0) * 12.0)
	var sig := [world.season, world.frontier, int(world.evening() * EV_QUANT),
		world.road_list.size(), world.mem_trees.size(), world.fountains.size(),
		int(world.rain_amount() * 8.0), sblend]   # yağmurda gök/zemin grileşir (8 kademe)
	if sig != _sig:
		_sig = sig
		queue_redraw()

# Kar örtüsü miktarı (G3): kış boyunca 1.0; sonbahar sonunda birikir, kış sonunda erir —
# season_mix'in geçiş penceresiyle aynı ritim, "bam" yerine yumuşak.
func _snow_cover(su: float) -> float:
	var blend := clampf((su - Palette.SEASON_BLEND_START) / (1.0 - Palette.SEASON_BLEND_START), 0.0, 1.0)
	if world.season == 3:
		return 1.0 if su < Palette.SEASON_BLEND_START else 1.0 - blend   # kış: dolu, sonunda erir
	if world.season == 2:
		return blend   # sonbahar sonu: kar birikmeye başlar
	return 0.0

func _draw() -> void:
	if world == null:
		return
	var su: float = float(world.season_tick) / float(World.SEASON_TICKS)   # sezon geçiş oranı (G3 blend)
	var grass_c: Color = Palette.season_mix(world.season, su, "grass")
	var tree_c: Color = Palette.season_mix(world.season, su, "tree")
	var road_c: Color = Palette.season_mix(world.season, su, "road")
	var ev: float = float(_sig[2]) / float(EV_QUANT)   # imzadaki kuantize değerle çiz (tutarlılık)
	var rain: float = float(_sig[6]) / 8.0             # yağmur grisi (ıslak dünya tonu)
	var fr: int = world.frontier
	var CW: float = view.CW
	var CH: float = view.CH
	var VW: float = view.VW
	var VH: float = view.VH

	# ---- GÖKYÜZÜ (3-faz, bantlı gradient) ----
	var dusk := minf(1.0, ev * 2.0)
	var night := maxf(0.0, ev * 2.0 - 1.0)
	var sky_top: Color = view._mix(view._mix(Color8(150,170,200), Color8(210,120,90), dusk), Color8(38,28,60), night)
	var sky_mid: Color = view._mix(view._mix(Color8(190,180,180), Color8(190,110,100), dusk), Color8(52,38,66), night)
	var sky_bot: Color = view._mix(view._mix(Color8(200,170,150), Color8(150,95,110), dusk), Color8(44,32,58), night)
	# yağmur: gök kurşuniye çalar, zemin ıslak/koyu (sıcaklık R−B>0 korunur — gri MOR tabanlı)
	sky_top = view._mix(sky_top, Color8(104,98,116), rain * 0.5)
	sky_mid = view._mix(sky_mid, Color8(112,104,120), rain * 0.5)
	sky_bot = view._mix(sky_bot, Color8(118,108,122), rain * 0.5)
	# 72 bant (36 idi): dusk'ta görünür şeritlenme "ucuz" okunuyordu (juice kritiği J5)
	var bands := 72
	for i in range(bands):
		var t0 := float(i) / float(bands)
		var col: Color
		if t0 < 0.55:
			col = sky_top.lerp(sky_mid, t0 / 0.55)
		else:
			col = sky_mid.lerp(sky_bot, (t0 - 0.55) / 0.45)
		draw_rect(Rect2(0, t0 * VH, VW, VH / float(bands) + 1.0), col)

	# ---- ZEMİN (opak kolon şeritleri — grid çizgisi yok; sanat cilası kararı) ----
	# kışta ŞEHİR zemini de karlanır (playtest: "kar sadece ormana yağıyor, şehre değil").
	var snow_amt := _snow_cover(su)
	var snow_col: Color = view._dusk(Color8(196,202,212), ev * 0.55)   # kar örtüsü (gece hafif koyulur)
	var town_base: Color = view._mix(Color8(132,108,104), Color8(46,34,52), ev * 0.85)
	town_base = view._mix(town_base, town_base.darkened(0.22), rain)   # ıslak zemin
	town_base = view._mix(town_base, snow_col, snow_amt * 0.6)
	draw_rect(Rect2(0, 0, fr * CW, VH), town_base)
	var meadow_base: Color = view._dusk(grass_c, ev * 0.5)
	const BORDER_COLS := 4
	for gx in range(fr, World.GW):
		var fmix := float(gx - fr) / float(World.GW - fr)
		var col := view._mix(sky_bot, meadow_base, 0.4 + fmix * 0.5) as Color
		if gx - fr < BORDER_COLS:
			col = view._mix(town_base, col, (float(gx - fr) + 0.5) / float(BORDER_COLS))
		draw_rect(Rect2(gx * CW, 0, CW + 1.0, VH), col)

	# ---- DİKEY KADRAJ ALT DOLGUSU (J14): dünya bandının altı ölü siyah kalmasın —
	# koyulaşan çayır devamı (yalnız dikeyde görünür; yatayda kamera dışı, bedava)
	draw_rect(Rect2(0, VH, VW, 800.0), view._mix(meadow_base, sky_bot, 0.2).darkened(0.25))

	# ---- UZAK TEPELER (J2: ölü sağ çayıra derinlik — dev daire yaylarının üstü tepe okur) ----
	var hill_far: Color = view._dusk(grass_c, ev * 0.5 + 0.25)
	draw_circle(Vector2(VW - 40.0, VH + 190.0), 250.0, view._mix(hill_far, sky_bot, 0.35))
	draw_circle(Vector2(VW - 190.0, VH + 240.0), 280.0, view._mix(hill_far, sky_bot, 0.5))
	draw_circle(Vector2(VW + 60.0, VH + 150.0), 230.0, view._mix(hill_far, sky_bot, 0.2))

	# ---- NEHİR TABANI (ışıltı çizgisi animasyonlu → TownView'da) ----
	var river_col: Color = view._mix(Color8(90,120,160), Color8(40,58,92), ev)
	for rc in world.river:
		draw_rect(Rect2(rc.x * CW, rc.y * CH, CW + 1.0, CH + 1.0), river_col)

	# ---- YOLLAR (J1: keskin bloklu şerit "render bug'ı gibi" okunuyordu — juice kritiğinin
	# 1 no'lu görsel kusuru). Üst üste binen daireler + hash-jitter = organik patika; çayır
	# tarafında kontrast düşürülür (yol çevresine karışır) ----
	var rc_col: Color = view._dusk(road_c, ev * 1.3)
	if snow_amt > 0.0:
		rc_col = view._mix(rc_col, snow_col, snow_amt * 0.5)   # yollar da hafif karlanır
	var rc_meadow: Color = rc_col.lerp(meadow_base, 0.30)
	for r in world.road_list:
		var jx := (Rng.hf(r.x * 31 + r.y * 7) - 0.5) * 3.0
		var jy := (Rng.hf(r.x * 13 + r.y * 41) - 0.5) * 3.0
		var col := rc_meadow if r.x >= fr else rc_col
		draw_circle(Vector2(r.x * CW + CW * 0.5 + jx, r.y * CH + CH * 0.5 + jy), CW * 0.66, col)

	# ---- ÇAYIR DETAY (çiçek/ağaç — hash örüntüsü sabit) ----
	var tree_col: Color = view._dusk(tree_c, ev * 0.45)
	for gy in range(1, World.GH - 1):
		for gx in range(fr, World.GW):
			if world.road_set.has(Vector2i(gx, gy)): continue
			var n := Rng.h(gx * 7 + gy * 13) % 100
			var X: float = gx * CW
			var Y: float = gy * CH
			if n < 9:
				draw_circle(Vector2(X + CW / 2.0, Y + CH / 2.0), CW * 0.22, tree_col)
			elif n < 15:
				draw_rect(Rect2(X + CW / 2.0 - 1.0, Y + CH / 2.0 - 1.0, 2.0, 2.0), Palette.season_mix(world.season, su, "flowers", Rng.h(gx + gy) % 3))

	# ---- PLAZA ----
	for pc in world.plaza_cells:
		draw_rect(Rect2(pc.x * CW, pc.y * CH, CW + 1.0, CH + 1.0), view._mix(Color8(150,130,120), Color8(80,66,72), ev * 0.5))

	# ---- ANI AĞAÇLARI (statik; doğuş juice'u TownView partikülünde) ----
	for mt in world.mem_trees:
		var X: float = mt.gx * CW + CW / 2.0
		var Y: float = mt.gy * CH + CH / 2.0
		draw_circle(Vector2(X, Y + 2.0), CW * 0.24, Color8(201,184,224))
		draw_rect(Rect2(X - 0.8, Y - 2.0, 1.6, CH * 0.4), Color8(138,122,154))
