extends Node2D
## NEFES koordinatör (ANAYASA: sim render'dan ayrı). Sabit-adım sim döngüsü + alt sistem bağlama.
## Sim = world.gd (saf), render = TownView. 1 gün = 30dk = 1800s / 2400 tick ⇒ tick = 0.75s.
## Kare-başına sim YOK (determinizm); tick akümülatörü ile ilerler.

const TICK_DT := 0.75
# GERÇEK dakika seansları (CLAUDE.md): Pomodoro 25/5, Derin 50/10. Mola nazik: atlanabilir, cezasız.
const MODES := [
	{ "name": "Pomodoro 25/5", "work_min": 25.0, "break_min": 5.0 },
	{ "name": "Derin 50/10", "work_min": 50.0, "break_min": 10.0 },
]

var world: World = null
var _accum := 0.0
var _frozen := false   # capture/duraklatma sırasında sim'i dondur
var _focus_phase := ""   # "" | "work" | "break" (tek Timer, faz bu değişkende)
var _focus_mode := 0
var _focus_timer: Timer = null
var _save_accum := 0.0
var _pending_offline := {}
var _is_capture := false   # capture modunda kayıt yükleme/yazma yok
var _prev_chime := 0.0     # saat başı kule melodisi için yükselen-kenar takibi (town_view'daki desen)

@onready var town_view: Node2D = $TownView
@onready var ui: CanvasLayer = $UI
@onready var audio: Node = $AudioPool
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)   # kapanışta kaydet
	if not _is_capture:
		_setup_window()
	if world == null and not _is_capture:
		world = World.new()
		if SaveGame.has_save():
			var res := SaveGame.load_into(world)
			_pending_offline = res.get("offline", {})
		else:
			world.gen(_daily_seed())
	_focus_timer = Timer.new()
	_focus_timer.one_shot = true
	add_child(_focus_timer)
	_focus_timer.timeout.connect(_on_focus_timeout)
	_restore_focus_session()
	if not _is_capture and is_instance_valid(audio):
		var gains := Settings.load_audio()
		for k in gains.keys():
			audio.set_gain(k, gains[k])
	_wire()
	if not _pending_offline.is_empty() and is_instance_valid(ui) and ui.has_method("show_offline"):
		ui.show_offline(_pending_offline)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_save()
		get_tree().quit()

# ---- pencere modları (B3): ekran-altı borderless şerit + dikey kadraj ----
var _vertical := false

func _setup_window() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_place_strip()

func _place_strip() -> void:
	var scr := DisplayServer.window_get_current_screen()
	var sz := DisplayServer.screen_get_size(scr)
	var origin := DisplayServer.screen_get_position(scr)
	var w := DisplayServer.window_get_size()
	if _vertical:
		# dikey kadraj: sağ kenara yasla
		DisplayServer.window_set_position(origin + Vector2i(sz.x - w.x - 16, (sz.y - w.y) / 2))
	else:
		# yatay ekran-altı şerit: ortala, alta yasla (görev çubuğu payı)
		DisplayServer.window_set_position(origin + Vector2i((sz.x - w.x) / 2, sz.y - w.y - 48))

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_ESCAPE:
				_save()
				get_tree().quit()
			KEY_V:   # dikey/yatay kadraj arası geçiş (konumlandırma)
				_vertical = not _vertical
				_place_strip()

func _save() -> void:
	if world != null and not _frozen and not _is_capture:
		# aktif seans kapanışta yanmasın: bitiş zamanı save'e (açılışta _restore_focus_session yorumlar)
		world.focus_phase = _focus_phase
		world.focus_mode = _focus_mode
		world.focus_until = (Time.get_unix_time_from_system() + _focus_timer.time_left) if _focus_phase != "" else 0.0
		SaveGame.save(world)
		if is_instance_valid(audio):
			Settings.save_audio(audio.gains)

## Açılışta kaydedilmiş seansı değerlendir: süresi varsa kaldığı yerden sürer,
## kullanıcı yokken bittiyse ödül yine verilir (cozy: emek asla yanmaz).
func _restore_focus_session() -> void:
	if world == null or world.focus_phase == "":
		return
	var remain: float = world.focus_until - Time.get_unix_time_from_system()
	var phase: String = world.focus_phase
	_focus_mode = clampi(world.focus_mode, 0, MODES.size() - 1)
	world.focus_phase = ""
	world.focus_until = 0.0
	if phase == "work":
		if remain > 1.0:
			_focus_phase = "work"
			world.growth_mult = 1.5
			_focus_timer.start(remain)
		else:
			world.finish_focus_reward(_daily_seed(), int(MODES[_focus_mode].work_min))
	elif phase == "break" and remain > 1.0:
		_focus_phase = "break"
		_focus_timer.start(remain)

func _wire() -> void:
	if is_instance_valid(town_view):
		town_view.world = world
		town_view.audio = audio
	if is_instance_valid(ui):
		ui.world = world
		ui.main = self
		ui.audio = audio
		if ui.has_method("sync_from_world"):
			ui.sync_from_world()   # kayıtlı melodi ızgaraya + ses slider'ları ayarlardan
	if world != null:
		_prev_chime = world.chime_t   # boot'ta hayalet çan çalmasın

func _daily_seed() -> int:
	var d := Time.get_date_dict_from_system()
	return d.year * 10000 + d.month * 100 + d.day   # YYYYMMDD

func _process(delta: float) -> void:
	if _frozen or world == null:
		return
	if is_instance_valid(audio):
		audio.evening = world.evening()   # cırcır kanalı geceyle nefes alır
	_accum += delta
	while _accum >= TICK_DT:
		world.step_world()
		_accum -= TICK_DT
	# saat başı: kule ÖĞRETİLMİŞ melodini çalar (uykuda 23-05 susar — ışık bütçesi ruhu)
	if world.chime_t > 0.9 and _prev_chime <= 0.9 and world.melody_saved and not world.is_asleep():
		if is_instance_valid(audio):
			audio.play_melody(world.melody)
	_prev_chime = world.chime_t
	_save_accum += delta
	if _save_accum >= 60.0:   # periyodik otomatik kayıt
		_save_accum = 0.0
		_save()

## Doğrulama pipeline sözleşmesi (tools/capture.gd çağırır): deterministik tohum + sabit saat.
func capture_setup(seed_val: int, tod: float, steps: int = 0) -> void:
	world = World.new()
	world.gen(0 if seed_val < 0 else seed_val)
	for i in range(maxi(0, steps)):
		world.step_world()
	if tod >= 0.0:
		world.force_time(tod)
	_frozen = true
	_wire()
	if is_instance_valid(ui):
		ui.visible = false   # capture: piksel metrikleri kasabayı ölçsün, UI gizli

# ---- UI eylem kancaları ----
## Seans başlat; moladayken çağrılırsa mola atlanır (cozy: mola öneri, zorunluluk değil).
func start_focus(mode: int) -> void:
	if _focus_phase == "work" or world == null:
		return
	_focus_phase = "work"
	_focus_mode = clampi(mode, 0, MODES.size() - 1)
	world.growth_mult = 1.5           # kullanıcı çalıştıkça kasaba ×1.5 büyür
	_focus_timer.start(MODES[_focus_mode].work_min * 60.0)

## Erken bırakma CEZASIZ (cozy): ödül yok ama seri/istatistik dokunulmaz kalır.
func cancel_focus() -> void:
	if _focus_phase == "":
		return
	_focus_phase = ""
	_focus_timer.stop()
	if world != null:
		world.growth_mult = 1.0

## UI okur: {phase, remaining(sn), mode}. Tek kaynak — buton metni/sayaç buradan türetilir.
func focus_state() -> Dictionary:
	return { "phase": _focus_phase, "remaining": _focus_timer.time_left, "mode": _focus_mode }

## UI okur: imleç altındaki sakin (render tespit eder — piksel easing konumları orada).
func hovered_person() -> Dictionary:
	if is_instance_valid(town_view) and town_view.hovered != null:
		return { "person": town_view.hovered, "px": town_view.hovered_px }
	return {}

func _on_focus_timeout() -> void:
	if _focus_phase == "work":
		if world != null:
			world.growth_mult = 1.0
			var res := world.finish_focus_reward(_daily_seed(), int(MODES[_focus_mode].work_min))
			if is_instance_valid(town_view) and town_view.has_method("celebrate"):
				town_view.celebrate(world.landmark.x, world.landmark.y - 3)
			if is_instance_valid(audio):
				audio.event("focusDone")
				if res.atolye or res.kutuphane:
					audio.event("unlock")
			_camera_pulse()
		_focus_phase = "break"
		_focus_timer.start(MODES[_focus_mode].break_min * 60.0)
	elif _focus_phase == "break":
		_focus_phase = ""
		if is_instance_valid(audio):
			audio.event("breakEnd")
	if is_instance_valid(ui) and ui.has_method("refresh_mail"):
		ui.refresh_mail()

func grant_wish() -> void:
	if world == null:
		return
	var pos = world.grant_wish()
	if pos != null and is_instance_valid(town_view) and town_view.has_method("celebrate"):
		town_view.celebrate(pos.x, pos.y)
	if is_instance_valid(audio):
		audio.event("letter")
	if is_instance_valid(ui) and ui.has_method("refresh_mail"):
		ui.refresh_mail()

func reply_letter(idx: int) -> void:
	if world != null:
		world.reply_letter(idx)
	if is_instance_valid(ui) and ui.has_method("refresh_mail"):
		ui.refresh_mail()

func teach_tower(mel: Array) -> Dictionary:
	if world == null:
		return { "concert": false }
	var res := world.teach_tower(mel)
	if is_instance_valid(audio):
		audio.play_melody(mel)
	if res.concert:
		if is_instance_valid(town_view) and town_view.has_method("celebrate"):
			town_view.celebrate(world.landmark.x, world.landmark.y - 2)   # ~18 mote (2×9)
			town_view.celebrate(world.landmark.x, world.landmark.y - 2)
		if is_instance_valid(audio):
			audio.event("unlock")
		_camera_pulse()
	if is_instance_valid(ui) and ui.has_method("refresh_mail"):
		ui.refresh_mail()
	return res

# ---- kamera mikro-zoom (B2): konser/ödülde 1-2px cozy zoom-in (screenshake DEĞİL) ----
func _camera_pulse() -> void:
	if not is_instance_valid(camera):
		return
	var tw := create_tween()
	tw.tween_property(camera, "zoom", Vector2(1.012, 1.012), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(camera, "zoom", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ---- ses kancaları ----
func play_tone(note: int) -> void:
	if is_instance_valid(audio):
		audio.play_tone(note)

func play_melody(mel: Array) -> void:
	if is_instance_valid(audio):
		audio.play_melody(mel)
