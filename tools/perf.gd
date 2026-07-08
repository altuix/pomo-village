extends SceneTree
# NEFES perf ölçümü (pencereli — gerçek render yükü; STEAM_ROADMAP perf bütçesi).
# Yaşamış kasabada (steps) N kare ölçer: ort. process süresi (CPU, vsync'ten bağımsız
# Performance.TIME_PROCESS) + kare başına draw call. "Ölçmeden hafif deme."
#
# Kullanım: tools/godot.sh --script tools/perf.gd -- [steps=24000] [frames=120] [budget_ms=16.0]
# Çıkış 0 = bütçede, 1 = aşım.

var _steps := 24000
var _frames := 120
var _budget_ms := 16.0
const WARMUP := 30

var _n := 0
var _sum_ms := 0.0
var _sum_draws := 0.0
var _main: Node = null
var _off: PackedStringArray = []

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", false, 1)
		if kv.size() != 2: continue
		match kv[0]:
			"steps": _steps = int(kv[1])
			"frames": _frames = int(kv[1])
			"budget_ms": _budget_ms = kv[1].to_float()
			"off": _off = kv[1].split(",")   # bileşen kapatarak profil: view,ui,audio,bg,sim
	var scene := load("res://Main.tscn")
	_main = scene.instantiate()
	_main.set("_is_capture", true)
	get_root().add_child(_main)
	# vsync bekleme süresi TIME_PROCESS'e karışıyor (60Hz ≈ 16.6ms taban) → kapat: ham iş ölçülür
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main.call("capture_setup", 20260707, 19.0, _steps)
	_main.set("_frozen", false)   # sim + render tam yük (gerçek koşul)
	if _main.get("ui") != null:
		_main.get("ui").visible = true
	# bileşen kapatma (profil): hangi katman kaç ms yakıyor
	var tv = _main.get("town_view")
	if "view" in _off and tv != null:
		tv.visible = false
		tv.set_process(false)
	if "bg" in _off and tv != null and tv.get("_bg") != null:
		tv.get("_bg").visible = false
		tv.get("_bg").set_process(false)
	if "ui" in _off and _main.get("ui") != null:
		_main.get("ui").visible = false
		_main.get("ui").set_process(false)
	if "audio" in _off and _main.get("audio") != null:
		_main.get("audio").set_process(false)
	if "sim" in _off:
		_main.set("_frozen", true)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_n += 1
	if _n <= WARMUP:
		return
	_sum_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_sum_draws += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	if _n >= WARMUP + _frames:
		var avg_ms := _sum_ms / float(_frames)
		var avg_draws := _sum_draws / float(_frames)
		var pop: int = _main.get("world").population()
		print("== perf (steps=%d, pop=%d, %d kare, vsync KAPALI) ==" % [_steps, pop, _frames])
		print("  ort. kare = %.2f ms (bütçe %.1f ms)  ≈ %.0f fps ham" % [avg_ms, _budget_ms, 1000.0 / maxf(0.01, avg_ms)])
		print("  ort. draw call = %.0f /kare" % avg_draws)
		var ok := avg_ms <= _budget_ms
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
