extends SceneTree
## NEFES uygulama ikonu üretici (H2 — programatik, palet-içi, telifsiz).
## Kompozisyon: alacakaranlık gökyüzü bantları + tepe silüeti + saat kulesi + sıcak pencere ışığı.
## Çıktı: assets/icon_1024.png + icon.png (256, project.godot config/icon) + icon_512/128.
## Kullanım: tools/godot.sh --headless --script tools/make_icon.gd

const SZ := 1024

func _init() -> void:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var sky_top := Color8(56, 40, 84)     # ink ailesi gece moru
	var sky_mid := Color8(210, 120, 90)   # alacakaranlık turuncusu (mevcut gök paleti)
	var sky_bot := Color8(150, 95, 110)
	for y in range(SZ):
		var t := float(y) / float(SZ)
		var c: Color
		if t < 0.6:
			c = sky_top.lerp(sky_mid, t / 0.6)
		else:
			c = sky_mid.lerp(sky_bot, (t - 0.6) / 0.4)
		for x in range(SZ):
			img.set_pixel(x, y, c)
	# yıldızlar (üst bölge, deterministik)
	for s in range(46):
		var sx := Rng.h(s * 17) % SZ
		var sy := Rng.h(s * 31) % int(SZ * 0.34)
		_dot(img, sx, sy, 3 if s % 5 == 0 else 2, Color(1.0, 0.94, 0.82, 0.85))
	# uzak tepe silüeti
	_hill(img, SZ * 0.30, SZ * 0.86, SZ * 0.55, Color8(74, 56, 92))
	_hill(img, SZ * 0.78, SZ * 0.90, SZ * 0.48, Color8(64, 47, 82))
	# zemin bandı
	_rect(img, 0, int(SZ * 0.82), SZ, SZ - int(SZ * 0.82), Color8(52, 38, 66))
	# saat kulesi (merkez): gövde + kadran + çatı + sıcak ışık halesi
	var cx := SZ / 2
	var tw := int(SZ * 0.16)
	var th := int(SZ * 0.46)
	var ty := int(SZ * 0.84) - th
	_glow(img, cx, ty + int(th * 0.22), int(SZ * 0.30), Color8(255, 230, 168))
	_rect(img, cx - tw / 2, ty, tw, th, Color8(216, 188, 160))
	_rect(img, cx + tw / 2 - int(tw * 0.30), ty, int(tw * 0.30), th, Color8(150, 120, 120))   # sağ gölge yüzü
	# kadran
	var cr := int(tw * 0.34)
	var cy := ty + int(th * 0.24)
	_disc(img, cx, cy, cr + 6, Color8(90, 63, 82))
	_disc(img, cx, cy, cr, Color8(255, 244, 214))
	_line(img, cx, cy, cx, cy - int(cr * 0.62), 5, Color8(90, 63, 82))
	_line(img, cx, cy, cx + int(cr * 0.44), cy + int(cr * 0.18), 5, Color8(90, 63, 82))
	# çatı üçgeni + tepe ışığı
	_tri(img, cx, ty - int(SZ * 0.085), cx - tw / 2 - int(SZ * 0.02), ty, cx + tw / 2 + int(SZ * 0.02), ty, Color8(194, 90, 74))
	_disc(img, cx, ty - int(SZ * 0.085), int(SZ * 0.012), Color8(255, 230, 168))
	# kule dibinde iki minik ev (sıcak pencereli)
	_house(img, cx - int(SZ * 0.24), int(SZ * 0.84), int(SZ * 0.10), Color8(201, 155, 70))
	_house(img, cx + int(SZ * 0.15), int(SZ * 0.84), int(SZ * 0.12), Color8(106, 134, 168))
	# köşe yumuşatma: iOS/macOS tarzı hafif yuvarlatılmış maske
	_round_mask(img, int(SZ * 0.16))
	_save_all(img)
	quit(0)

func _dot(img: Image, x: int, y: int, r: int, c: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r and x + dx >= 0 and x + dx < SZ and y + dy >= 0 and y + dy < SZ:
				img.set_pixel(x + dx, y + dy, c.blend(img.get_pixel(x + dx, y + dy)) if c.a < 1.0 else c)

func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)

func _disc(img: Image, x: int, y: int, r: int, c: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				var px := x + dx
				var py := y + dy
				if px >= 0 and px < SZ and py >= 0 and py < SZ:
					img.set_pixel(px, py, c)

func _hill(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(maxi(0, int(cy - r)), SZ):
		for x in range(maxi(0, int(cx - r)), mini(SZ, int(cx + r))):
			var dx := (x - cx) / r
			var dy := (y - cy) / r
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c)

func _line(img: Image, x0: int, y0: int, x1: int, y1: int, w: int, c: Color) -> void:
	var steps := maxi(absi(x1 - x0), absi(y1 - y0))
	for i in range(steps + 1):
		var t := float(i) / float(maxi(1, steps))
		_disc(img, int(lerpf(x0, x1, t)), int(lerpf(y0, y1, t)), w / 2, c)

func _tri(img: Image, ax: int, ay: int, bx: int, by: int, cx2: int, cy2: int, c: Color) -> void:
	for y in range(mini(ay, by), maxi(by, cy2) + 1):
		if y < ay or y > by:
			continue
		var t := float(y - ay) / float(maxi(1, by - ay))
		var xl := int(lerpf(ax, bx, t))
		var xr := int(lerpf(ax, cx2, t))
		for x in range(xl, xr + 1):
			if x >= 0 and x < SZ and y >= 0 and y < SZ:
				img.set_pixel(x, y, c)

func _glow(img: Image, x: int, y: int, r: int, c: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d := sqrt(float(dx * dx + dy * dy)) / float(r)
			if d <= 1.0:
				var px := x + dx
				var py := y + dy
				if px >= 0 and px < SZ and py >= 0 and py < SZ:
					var base := img.get_pixel(px, py)
					img.set_pixel(px, py, base.lerp(c, (1.0 - d) * 0.35))

func _house(img: Image, x: int, base_y: int, w: int, roof: Color) -> void:
	var h := int(w * 1.2)
	_rect(img, x, base_y - h, w, h, Color8(216, 188, 160))
	_tri(img, x + w / 2, base_y - h - int(w * 0.5), x - int(w * 0.1), base_y - h, x + w + int(w * 0.1), base_y - h, roof)
	_rect(img, x + int(w * 0.3), base_y - int(h * 0.62), int(w * 0.4), int(h * 0.3), Color8(255, 207, 122))

func _round_mask(img: Image, r: int) -> void:
	for y in range(SZ):
		for x in range(SZ):
			var dx := maxi(0, maxi(r - x, x - (SZ - 1 - r)))
			var dy := maxi(0, maxi(r - y, y - (SZ - 1 - r)))
			if dx > 0 and dy > 0 and dx * dx + dy * dy > r * r:
				var c := img.get_pixel(x, y)
				c.a = 0.0
				img.set_pixel(x, y, c)

func _save_all(img: Image) -> void:
	var base := ProjectSettings.globalize_path("res://")
	img.save_png(base + "assets/icon_1024.png")
	for sz in [512, 256, 128]:
		var s := img.duplicate()
		s.resize(sz, sz, Image.INTERPOLATE_LANCZOS)
		s.save_png(base + ("icon.png" if sz == 256 else "assets/icon_%d.png" % sz))
	print("ikon üretildi: assets/icon_1024/512/128.png + icon.png (256)")
