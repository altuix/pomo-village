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
	if not _is_capture and not SaveGame.acquire_lock():
		# ikinci kopya aynı save.json'a yazar (denetim #23) — nazikçe geri çekil.
		# OS.alert BLOKLAYICI modal (otomasyon/testte asılı kalır) → log + sessiz kapanış.
		push_warning("[nefes] zaten açık bir kopya var (nefes.lock taze) — bu kopya kapanıyor")
		get_tree().quit()
		return
	if not _is_capture:
		_setup_window()
		Engine.max_fps = 30   # always-on şerit: 30fps cozy'ye yeter, CPU/pil yarıya (perf bütçesi)
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
	# ana menü (Faz C): hızlı-başlat açıksa atlanır (companion kimliği — doğrudan şeride)
	if not _is_capture and is_instance_valid(ui) and not Settings.get_flag("quick_start"):
		ui.show_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_save()
		SaveGame.release_lock()
		get_tree().quit()

# ---- pencere modları (B3+C19): yatay ekran-altı şerit / GERÇEK dikey kadraj ----
const STRIP_SIZE := Vector2i(960, 360)
const VERT_SIZE := Vector2i(380, 700)   # ikinci monitör kenarı / dar yan şerit
var _vertical := false
var _scale := 1                          # pencere ölçeği 1×/2×/3× (kullanıcı: "960×360 minicik")
var _cam_base_zoom := Vector2.ONE       # dikeyde kamera kasaba çekirdeğine yaklaşır; pulse buna göre

func _setup_window() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	# ölçek: kayıtlı tercih; VARSAYILAN = EKRANA SIĞDIR (0) — sabit 1× MacBook mantıksal
	# çözünürlüğünde minicik kalıyordu ("hâlâ çok küçük" geri bildirimi)
	_scale = clampi(Settings.get_int("scale", 0), 0, 3)
	_apply_layout()

## Menüden ölçek seçimi. 0 = EKRANA SIĞDIR (ekran genişliğinin ~%94'ü, kesirli içerik ölçeği);
## 1-3 = tam sayı katlar (pixel-art bulanıksız).
func set_window_scale(n: int) -> void:
	_scale = clampi(n, 0, 3)
	Settings.set_int("scale", _scale)
	if not _is_capture:
		_apply_layout()

func toggle_vertical() -> void:
	_vertical = not _vertical
	_apply_layout()

## Dikey (C19): pencere 380×700; kamera kasaba çekirdeğini (0..480 dünya-px) genişliğe sığdırır,
## dünya üstte ~285px bant olur, altı UI alanı (koyu). Yatay: birebir eski şerit.
func _apply_layout() -> void:
	# içerik ölçeği YALNIZ gerçek oyunda, çalışma zamanında (project-genel stretch capture
	# viewport dokusunu boşaltıp görsel pipeline'ı kırdı — ölçüm yakaladı)
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var scr_sz := DisplayServer.screen_get_size()
	if _vertical:
		win.content_scale_size = VERT_SIZE
		if _scale == 0:   # sığdır: ekran yüksekliğinin %90'ı
			var h := int(scr_sz.y * 0.90)
			DisplayServer.window_set_size(Vector2i(int(h * float(VERT_SIZE.x) / float(VERT_SIZE.y)), h))
		else:
			DisplayServer.window_set_size(VERT_SIZE * _scale)
		var z := float(VERT_SIZE.x) / 480.0
		_cam_base_zoom = Vector2(z, z)
		if is_instance_valid(camera):
			camera.zoom = _cam_base_zoom
			camera.position = Vector2(240.0, float(VERT_SIZE.y) / z / 2.0)   # dünya y=0 pencere üstünde
	else:
		win.content_scale_size = STRIP_SIZE
		if _scale == 0:   # sığdır: ekran genişliğinin %94'ü (oran korunur)
			var w := int(scr_sz.x * 0.94)
			DisplayServer.window_set_size(Vector2i(w, int(w * float(STRIP_SIZE.y) / float(STRIP_SIZE.x))))
		else:
			DisplayServer.window_set_size(STRIP_SIZE * _scale)
		_cam_base_zoom = Vector2.ONE
		if is_instance_valid(camera):
			camera.zoom = Vector2.ONE
			camera.position = Vector2(480, 180)
	if is_instance_valid(ui) and ui.has_method("set_vertical"):
		ui.set_vertical(_vertical)
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
	# InputMap aksiyonları (denetim #24: hardcoded keycode kalktı — ileride remap edilebilir)
	if e.is_action_pressed("nefes_menu"):
		if is_instance_valid(ui):
			# Esc ÖNCELİĞİ (playtest): önce açık paneli kapat; panel yoksa menü aç/kapa
			if ui.has_method("close_open_panels") and ui.close_open_panels():
				pass
			elif ui.menu_visible():
				ui.hide_menu()
			else:
				ui.show_menu()
	elif e.is_action_pressed("nefes_vertical"):
		toggle_vertical()

# ---- pencere sürükleme (playtest: borderless şerit TAŞINAMIYORDU — masaüstü temel beklentisi).
# _unhandled_input: UI butonları olayı tükettikten SONRA gelir → yalnız boş alandan sürüklenir.
var _dragging := false
var _drag_off := Vector2i.ZERO

func _unhandled_input(e: InputEvent) -> void:
	if _is_capture:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_dragging = true
			_drag_off = DisplayServer.mouse_get_position() - DisplayServer.window_get_position()
		else:
			_dragging = false
	elif e is InputEventMouseMotion and _dragging:
		DisplayServer.window_set_position(DisplayServer.mouse_get_position() - _drag_off)

func _save() -> void:
	if world != null and not _frozen and not _is_capture:
		SaveGame.touch_lock()   # canlılık damgası (60sn'de bir — çökme sonrası kilit bayatlar)
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
			if is_instance_valid(audio):
				audio.focus_active = true
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
		audio.weather_rain = world.rain_amount()   # yağmurda rain kanalı hafif kendiliğinden
	_accum += delta
	while _accum >= TICK_DT:
		world.step_world()
		_accum -= TICK_DT
		# saat başı kule sesi: kenar tespiti TICK DÖNGÜSÜ İÇİNDE — lag/boot'ta tek karede
		# çok tick işlenirse chime 1.0'a çıkıp 0.9 altına inebiliyor, kare-sonu kontrolü kaçırırdı.
		# Melodi öğretilmişse ONU çalar; değilse tek çan (J7: görsel nabız artık hiç sessiz değil).
		if world.chime_t > 0.9 and _prev_chime <= 0.9 and not world.is_asleep():
			if is_instance_valid(audio):
				if world.melody_saved:
					audio.play_melody(world.melody)   # uykuda 23-05 susar (ışık bütçesi ruhu)
				else:
					audio.event("towerChime")
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
	if is_instance_valid(audio):
		audio.focus_active = true     # pad'e üst-oktav odak katmanı eklenir

## Erken bırakma CEZASIZ (cozy): ödül yok ama seri/istatistik dokunulmaz kalır.
func cancel_focus() -> void:
	if _focus_phase == "":
		return
	_focus_phase = ""
	_focus_timer.stop()
	if world != null:
		world.growth_mult = 1.0
	if is_instance_valid(audio):
		audio.focus_active = false

## UI okur: {phase, remaining(sn), mode}. Tek kaynak — buton metni/sayaç buradan türetilir.
func focus_state() -> Dictionary:
	return { "phase": _focus_phase, "remaining": _focus_timer.time_left, "mode": _focus_mode }

## UI okur: imleç altındaki sakin (render tespit eder — piksel easing konumları orada).
func hovered_person() -> Dictionary:
	if is_instance_valid(town_view) and town_view.hovered != null:
		return { "person": town_view.hovered, "px": town_view.hovered_px }
	return {}

# ---- kartpostal modu (Faz C #20): o anki kadraj + tohum → PNG (paylaşım/pazarlama aracı) ----
var last_postcard_path := ""

func take_postcard(dir_override: String = "") -> void:
	if world == null or not is_instance_valid(ui):
		return
	var was_visible: bool = ui.visible
	ui.visible = false
	await get_tree().process_frame
	await get_tree().process_frame   # UI'sız temiz kare için render bekle
	var img := get_viewport().get_texture().get_image()
	ui.visible = was_visible
	# ink çerçeve — kartpostal hissi (palet: ink #2b1e2e)
	var ink := Color("2b1e2e")
	var wpx := img.get_width()
	var hpx := img.get_height()
	img.fill_rect(Rect2i(0, 0, wpx, 6), ink)
	img.fill_rect(Rect2i(0, hpx - 6, wpx, 6), ink)
	img.fill_rect(Rect2i(0, 0, 6, hpx), ink)
	img.fill_rect(Rect2i(wpx - 6, 0, 6, hpx), ink)
	var dir_path := dir_override
	if dir_path == "":
		dir_path = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if dir_path == "" or not DirAccess.dir_exists_absolute(dir_path):
		dir_path = OS.get_user_data_dir()
	var day: int = world.tick / World.TICKS_PER_DAY + 1
	# tohum dosya adında: arkadaşın aynı tohumla aynı kasabayı kurabilir (deterministik paylaşım)
	last_postcard_path = "%s/NEFES_tohum%d_gun%d_%s.png" % [dir_path, world.town_seed(), day, world.clock_string().replace(":", "")]
	var e := img.save_png(last_postcard_path)
	if e == OK:
		world._push_event("📷 kartpostal kaydedildi (Resimler klasörü)")
		if is_instance_valid(audio):
			audio.event("camera")
	else:
		world._push_event("📷 kartpostal kaydedilemedi")
		push_warning("[postcard] save_png err=%d yol=%s" % [e, last_postcard_path])

func _on_focus_timeout() -> void:
	if _focus_phase == "work":
		if world != null:
			world.growth_mult = 1.0
			var res := world.finish_focus_reward(_daily_seed(), int(MODES[_focus_mode].work_min))
			if not _is_capture:
				DisplayServer.window_request_attention()   # Pomodoro bitti — kullanıcı başka penceredeyse haber ver
			if is_instance_valid(town_view) and town_view.has_method("celebrate"):
				town_view.celebrate(world.landmark.x, world.landmark.y - 3)
			if is_instance_valid(audio):
				audio.event("focusDone")
				if res.atolye or res.kutuphane or res.get("special", false):
					audio.event("unlock")
			_camera_pulse()
		_focus_phase = "break"
		_focus_timer.start(MODES[_focus_mode].break_min * 60.0)
		if is_instance_valid(audio):
			audio.focus_active = false
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

func reply_letter(lid: int) -> void:
	if world != null:
		world.reply_letter(lid)
		if is_instance_valid(town_view) and town_view.has_method("float_text"):
			# J9: bağ artışı olayın yerinde görünür (kule üstünde nazik +1💛)
			town_view.float_text(float(world.landmark.x), float(world.landmark.y) - 3.0, "+1 💛", Color(1.0, 0.81, 0.48))
	if is_instance_valid(ui) and ui.has_method("refresh_mail"):
		ui.refresh_mail()

## Yeni Kasaba (ana menü): mevcut kayıt .bak'a, bugünün tohumuyla taze dünya.
## NOT: bu fonksiyon bir kez sessiz no-op edit kazasıyla HİÇ eklenmemişti ve buton ölüydü —
## tests/run_ui.gd sözleşme testi artık bunu kalıcı yakalar.
func new_town() -> void:
	cancel_focus()
	if not _is_capture:
		SaveGame.backup_current()   # cozy: yanlışlıkla kayıp yok (capture/testte gerçek kayda dokunma)
	world = World.new()
	world.gen(_daily_seed())
	_pending_offline = {}
	_wire()
	if is_instance_valid(ui) and ui.has_method("refresh_mail"):
		ui.refresh_mail()   # açık panel eski dünyanın mektuplarını göstermesin
	_save()

func quit_game() -> void:
	_save()
	SaveGame.release_lock()
	get_tree().quit()

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
	tw.tween_property(camera, "zoom", _cam_base_zoom * 1.012, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(camera, "zoom", _cam_base_zoom, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ---- ses kancaları ----
func play_tone(note: int) -> void:
	if is_instance_valid(audio):
		audio.play_tone(note)

func play_melody(mel: Array) -> void:
	if is_instance_valid(audio):
		audio.play_melody(mel)
