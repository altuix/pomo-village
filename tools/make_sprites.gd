extends SceneTree
## NEFES pixel-art sprite üretici (Açık Karar #5: prosedürel taban → gerçek sprite hissi).
## DEĞER-HARİTALI üretim: sprite'lar beyaz-tabanlı (value shading + ink kontur); renk çalışma
## zamanında PALETTEN modulate ile verilir → palet tek kaynak, mevsim/akşam tonlaması bedava.
## Deterministik (Rng.h), telifsiz, elle tasarlanmış piksel desenleri.
## Kullanım: tools/godot.sh --headless --script tools/make_sprites.gd

const OUT := "res://assets/sprites/"
const INK := Color(0.168, 0.118, 0.180)   # 2b1e2e — kontur (palet)

## 2× süper-örnekleme (G3): sprite'lar 2× çözünürlükte üretilir, oyunda aynı fiziksel boyuta
## küçültülür → linear filtre kenarları yumuşatır (playtest: "pixel art keskin/köşeli, modern
## yumuşak yap"). Desenler w,h parametrik olduğundan ölçek bozulmaz; dither daha ince okunur.
const SS := 2

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_gen_wall(13 * SS, 22 * SS), "wall")
	_save(_gen_roof_peak(15 * SS, 9 * SS), "roof_peak")
	_save(_gen_roof_hip(15 * SS, 8 * SS), "roof_hip")
	_save(_gen_roof_flat(15 * SS, 6 * SS), "roof_flat")
	_save(_gen_tree(15 * SS, 13 * SS), "tree")
	print("sprite'lar üretildi (2× süper-örnekleme) → ", OUT)
	quit(0)

func _save(img: Image, name: String) -> void:
	var e := img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("  %s.png %s %s" % [name, str(img.get_size()), "OK" if e == OK else "HATA"])

func _v(v: float) -> Color:
	return Color(v, v, v, 1.0)

## Duvar: ink kontur + sol gölge + üst kiriş + kapı kemeri (pencereler DİNAMİK — üstüne çizilir)
func _gen_wall(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var c := _v(0.94)
			if x == 0 or x == w - 1 or y == 0 or y == h - 1:
				c = INK                       # kontur
			elif x == 1:
				c = _v(0.72)                  # sol gölge (hacim)
			elif x == w - 2:
				c = _v(0.99)                  # sağ kenar ışığı
			elif y == 1:
				c = _v(0.80)                  # saçak altı kirişi
			elif (x + y * 3) % 11 == 0:
				c = _v(0.88)                  # hafif sıva dokusu
			img.set_pixel(x, y, c)
	# kapı: alt-orta kemer (ink çerçeve + koyu iç) — oransal (2× süper-örneklemede bozulmasın)
	var dw := maxi(5, int(w * 0.38))
	var dh := maxi(7, int(h * 0.34))
	var dx0 := w / 2 - dw / 2
	var dy0 := h - 1 - dh
	for y in range(dy0, h - 1):
		for x in range(dx0, dx0 + dw):
			var edge := (x == dx0 or x == dx0 + dw - 1 or y == dy0)
			img.set_pixel(x, y, INK if edge else _v(0.42))
	img.set_pixel(dx0 + dw - 2, h - 1 - dh / 2, _v(0.95))   # kapı tokmağı parıltısı
	return img

## Sivri çatı: üçgen, iki yüz (aydınlık/gölge) + kiremit dither + ink kontur
func _gen_roof_peak(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w / 2
	for y in range(h):
		var half := int(float(w) * 0.5 * float(y + 1) / float(h))
		for x in range(cx - half, cx + half + 1):
			if x < 0 or x >= w:
				continue
			var c := _v(0.95 if x < cx else 0.70)              # sol yüz aydınlık, sağ gölge
			if (x + y) % 3 == 0:
				c = _v(0.85 if x < cx else 0.62)               # kiremit sırası
			var at_edge := (x == cx - half or x == cx + half or y == h - 1)
			img.set_pixel(x, y, INK if at_edge else c)
	return img

## Kırma çatı: yamuk
func _gen_roof_hip(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(h):
		var inset := int(float(w) * 0.25 * (1.0 - float(y) / float(h - 1)))
		for x in range(inset, w - inset):
			var c := _v(0.92 if y < 2 else (0.78 if (x + y) % 3 != 0 else 0.68))
			var at_edge := (x == inset or x == w - inset - 1 or y == 0 or y == h - 1)
			img.set_pixel(x, y, INK if at_edge else c)
	return img

## Düz çatı: bant + korniş
func _gen_roof_flat(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var c := _v(0.95 if y <= 1 else (0.75 if (x + y) % 4 != 0 else 0.66))
			if x == 0 or x == w - 1 or y == 0 or y == h - 1:
				c = INK
			img.set_pixel(x, y, c)
	return img

## Ağaç tepesi: yumrulu taç (dış hat yumuşak ink, iç kümeler) — gövde çizimde kalır
func _gen_tree(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(w) * 0.5
	var cy := float(h) * 0.52
	for y in range(h):
		for x in range(w):
			var dx := (float(x) - cx) / (float(w) * 0.46)
			var dy := (float(y) - cy) / (float(h) * 0.48)
			var d := dx * dx + dy * dy
			var wob := 0.12 * float(Rng.h(x * 7 + y * 13) % 100) / 100.0   # yumrulu kenar
			if d < 1.0 - wob:
				var v := 0.92
				if d > 0.62:
					v = 0.68                                  # dış gölge halkası
				elif Rng.h(x * 31 + y * 17) % 5 == 0:
					v = 1.0                                   # ışık alan yaprak kümeleri
				elif Rng.h(x * 11 + y * 29) % 7 == 0:
					v = 0.78
				img.set_pixel(x, y, _v(v))
			elif d < 1.08 - wob:
				img.set_pixel(x, y, Color(INK.r, INK.g, INK.b, 0.55))   # yumuşak kontur
	return img
