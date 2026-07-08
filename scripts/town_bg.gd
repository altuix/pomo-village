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
	var sig := [world.season, world.frontier, int(world.evening() * EV_QUANT),
		world.road_list.size(), world.mem_trees.size(), world.fountains.size()]
	if sig != _sig:
		_sig = sig
		queue_redraw()

func _draw() -> void:
	if world == null:
		return
	var S: Dictionary = view.SEASONS[world.season]
	var ev: float = float(_sig[2]) / float(EV_QUANT)   # imzadaki kuantize değerle çiz (tutarlılık)
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
	var bands := 36
	for i in range(bands):
		var t0 := float(i) / float(bands)
		var col: Color
		if t0 < 0.55:
			col = sky_top.lerp(sky_mid, t0 / 0.55)
		else:
			col = sky_mid.lerp(sky_bot, (t0 - 0.55) / 0.45)
		draw_rect(Rect2(0, t0 * VH, VW, VH / float(bands) + 1.0), col)

	# ---- ZEMİN (opak kolon şeritleri — grid çizgisi yok; sanat cilası kararı) ----
	var town_base: Color = view._mix(Color8(132,108,104), Color8(46,34,52), ev * 0.85)
	draw_rect(Rect2(0, 0, fr * CW, VH), town_base)
	var meadow_base: Color = view._dusk(S.grass, ev * 0.5)
	const BORDER_COLS := 4
	for gx in range(fr, World.GW):
		var fmix := float(gx - fr) / float(World.GW - fr)
		var col := view._mix(sky_bot, meadow_base, 0.4 + fmix * 0.5) as Color
		if gx - fr < BORDER_COLS:
			col = view._mix(town_base, col, (float(gx - fr) + 0.5) / float(BORDER_COLS))
		draw_rect(Rect2(gx * CW, 0, CW + 1.0, VH), col)

	# ---- NEHİR TABANI (ışıltı çizgisi animasyonlu → TownView'da) ----
	var river_col: Color = view._mix(Color8(90,120,160), Color8(40,58,92), ev)
	for rc in world.river:
		draw_rect(Rect2(rc.x * CW, rc.y * CH, CW + 1.0, CH + 1.0), river_col)

	# ---- YOLLAR ----
	var rc_col: Color = view._dusk(S.road, ev * 1.3)
	for r in world.road_list:
		draw_rect(Rect2(r.x * CW - 1.0, r.y * CH - 1.0, CW + 2.0, CH + 2.0), rc_col)

	# ---- ÇAYIR DETAY (çiçek/ağaç — hash örüntüsü sabit) ----
	var tree_col: Color = view._dusk(S.tree, ev * 0.45)
	for gy in range(1, World.GH - 1):
		for gx in range(fr, World.GW):
			if world.road_set.has(Vector2i(gx, gy)): continue
			var n := Rng.h(gx * 7 + gy * 13) % 100
			var X: float = gx * CW
			var Y: float = gy * CH
			if n < 9:
				draw_circle(Vector2(X + CW / 2.0, Y + CH / 2.0), CW * 0.22, tree_col)
			elif n < 15:
				draw_rect(Rect2(X + CW / 2.0 - 1.0, Y + CH / 2.0 - 1.0, 2.0, 2.0), S.flowers[Rng.h(gx + gy) % 3])

	# ---- PLAZA ----
	for pc in world.plaza_cells:
		draw_rect(Rect2(pc.x * CW, pc.y * CH, CW + 1.0, CH + 1.0), view._mix(Color8(150,130,120), Color8(80,66,72), ev * 0.5))

	# ---- ANI AĞAÇLARI (statik; doğuş juice'u TownView partikülünde) ----
	for mt in world.mem_trees:
		var X: float = mt.gx * CW + CW / 2.0
		var Y: float = mt.gy * CH + CH / 2.0
		draw_circle(Vector2(X, Y + 2.0), CW * 0.24, Color8(201,184,224))
		draw_rect(Rect2(X - 0.8, Y - 2.0, 1.6, CH * 0.4), Color8(138,122,154))
