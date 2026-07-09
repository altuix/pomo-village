extends SceneTree
# NEFES ekran görüntüsü yakalama (pencereli — viewport render'ı için GPU gerekir).
# Main.tscn'i deterministik tohum + günün-saati ile kurar, birkaç frame render eder,
# PNG kaydeder, çıkar. Headless ÇALIŞMAZ (GPU yok); tools/verify.sh kill-fallback ile sarar.
#
# Kullanım:
#   tools/godot.sh --script tools/capture.gd -- out=<png> [time=<0..24>] [seed=<int>] [frames=<n>]
#
# Main opsiyonel `capture_setup(seed_val: int, tod: float)` metodunu sağlarsa çağrılır
# (A0'da eklenir); yoksa oyun kendi başlangıç durumuyla yakalanır.

var _out := "capture.png"
var _tod := -1.0
var _seed := -1
var _frames := 4
var _steps := 0
var _vert := false
var _count := 0
var _main: Node = null

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", false, 1)
		if kv.size() != 2: continue
		match kv[0]:
			"out": _out = kv[1]
			"time": _tod = kv[1].to_float()
			"seed": _seed = int(kv[1])
			"frames": _frames = int(kv[1])
			"steps": _steps = int(kv[1])
			"vert": _vert = kv[1] == "1"

	var scene := load("res://Main.tscn")
	if scene == null:
		push_error("capture: Main.tscn yüklenemedi"); quit(2); return
	_main = scene.instantiate()
	_main.set("_is_capture", true)   # _ready kayıt yüklemesin/yazmasın
	get_root().add_child(_main)
	if _main.has_method("capture_setup"):
		_main.call("capture_setup", _seed, _tod, _steps)   # steps: timelapse (gün N kasabası)
	if _vert and _main.has_method("toggle_vertical"):
		_main.call("toggle_vertical")   # dikey mod karesi (G4 doğrulama)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_count += 1
	if _count < _frames:
		return
	var img := get_root().get_texture().get_image()
	var e := img.save_png(_out)
	print("capture: frames=%d out=%s save_err=%d size=%s" % [_count, _out, e, str(img.get_size())])
	quit(0 if e == OK else 1)
