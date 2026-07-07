extends SceneTree
# NEFES piksel denetimi (headless — GPU gerekmez, sadece Image.load_from_file).
# Anayasa görsel kuralı: parlaklık gündüz~115 / akşam~90 / gece~70,
# sıcaklık R−B>0, value aralığı>60. Renkler kilitli paletten.
#
# Kullanım:
#   tools/godot.sh --headless --script tools/pixelcheck.gd -- <png> [faz=day|eve|night]
#
# Çıkış kodu 0 = PASS, 1 = FAIL. Metrikler her zaman yazdırılır ("güzel oldu" demeden önce sayı).

const BANDS := {
	"day":   { "b_lo": 100.0, "b_hi": 135.0 },
	"eve":   { "b_lo":  75.0, "b_hi": 105.0 },
	"night": { "b_lo":  58.0, "b_hi":  88.0 },
}
const WARMTH_MIN := 0.0   # R−B > 0 (sıcak)
const VALUE_RANGE_MIN := 60.0

func _init() -> void:
	var args := _script_args()
	if args.is_empty():
		push_error("pixelcheck: png yolu gerekli"); quit(2); return
	var path: String = args[0]
	var phase: String = args[1] if args.size() > 1 else ""

	var img := Image.load_from_file(path)
	if img == null:
		push_error("pixelcheck: PNG yüklenemedi: " + path); quit(2); return

	var w := img.get_width()
	var h := img.get_height()
	var sum_l := 0.0
	var sum_r := 0.0
	var sum_b := 0.0
	var lmin := 255.0
	var lmax := 0.0
	var n := 0
	# 4px ızgarada örnekle (hız + yeterli kapsama)
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var c := img.get_pixel(x, y)
			var r := c.r * 255.0
			var g := c.g * 255.0
			var bl := c.b * 255.0
			var l := (r + g + bl) / 3.0
			sum_l += l
			sum_r += r
			sum_b += bl
			lmin = minf(lmin, l)
			lmax = maxf(lmax, l)
			n += 1

	var brightness := sum_l / float(n)
	var warmth := (sum_r - sum_b) / float(n)
	var vrange := lmax - lmin

	print("== pixelcheck: %s ==" % path)
	print("  parlaklik (brightness) = %.1f" % brightness)
	print("  sicaklik  (R-B)        = %.1f" % warmth)
	print("  value araligi          = %.1f" % vrange)

	var pass_ok := true
	if BANDS.has(phase):
		var band: Dictionary = BANDS[phase]
		var ok_b: bool = brightness >= band["b_lo"] and brightness <= band["b_hi"]
		print("  [%s] beklenen parlaklik %.0f..%.0f -> %s" % [phase, band["b_lo"], band["b_hi"], ("OK" if ok_b else "FAIL")])
		pass_ok = pass_ok and ok_b
	else:
		print("  (faz verilmedi — parlaklik bandi denetlenmedi)")

	var ok_w: bool = warmth > WARMTH_MIN
	var ok_v: bool = vrange > VALUE_RANGE_MIN
	print("  sicaklik>0        -> %s" % ("OK" if ok_w else "FAIL"))
	print("  value araligi>%.0f -> %s" % [VALUE_RANGE_MIN, ("OK" if ok_v else "FAIL")])
	pass_ok = pass_ok and ok_w and ok_v

	print("RESULT: %s" % ("PASS" if pass_ok else "FAIL"))
	quit(0 if pass_ok else 1)

func _script_args() -> PackedStringArray:
	# `--` sonrası argümanlar
	var out := PackedStringArray()
	var raw := OS.get_cmdline_user_args()
	for a in raw:
		out.append(a)
	return out
