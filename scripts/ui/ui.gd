extends CanvasLayer
## NEFES UI (ANAYASA kural 5: paneller varsayılan KAPALI; çekirdek izle→büyür→mektup boğulmaz).
## HTML DOM HUD/bar/paneller → Godot Control. World'ü OKUR; eylemler main'e/dünyaya iletilir.
## A7 iskele: HUD + olay akışı + buton şeridi + boş paneller (A3 odak / A4 mektup / A5 melodi / A6 ses doldurur).

var world: World = null
var main: Node = null
var audio = null   # ses motoru (mikser slider'ları için)

# tokenlar MERKEZİ paletten (scripts/palette.gd — CLAUDE.md §1)
const INK := Palette.INK
const HONEY := Palette.HONEY
const CREAM := Palette.CREAM
const SAGE := Palette.SAGE
const MUTED := Palette.MUTED

var _clock: Label
var _sub: Label
var _stat: Label
var _events: Label
var _streak_btn: Button
var _mail_btn: Button
var _wish_btn: Button
var _focus_btn: Button
var _mode_opt: OptionButton
var stats_box: PanelContainer
var _stats_body: Label
var _person_card: PanelContainer
var _person_body: Label
var album_box: PanelContainer
var _album_list: VBoxContainer
var menu_box: PanelContainer
var _t := 0.0            # juice zamanı (zarf sallanması)
var _last_event := ""    # olay satırı kayma tetiği
var _compact := false    # dikey mod: dar bar (mod seçici gizli, kısa etiketler)
var _menu_btn: Button

const STAGE_NAMES := ["🌱 çocuk", "yetişkin", "🕰 bilge"]

# paneller (A3-A6 doldurur) — sağ/sol alt çekmeceler
var sound_box: PanelContainer
var melody_box: PanelContainer
var mail_box: PanelContainer
var mail_list: VBoxContainer

# melodi (A5)
var _melody: Array = [0, 2, 4, 2, -1, 3, 1, 0]
var _mel_cells: Array = []
var _mel_note: Label

func _ready() -> void:
	_build()

## main._wire çağırır: kayıtlı melodiyi ızgaraya + ses slider'larını ayarlardan yansıt.
func sync_from_world() -> void:
	if world != null and world.melody.size() == Melody.STEPS:
		_melody = world.melody.duplicate()
		if not _mel_cells.is_empty():
			_refresh_melody()
	if audio != null:
		for ch in _sound_sliders.keys():
			if audio.gains.has(ch):
				_sound_sliders[ch].set_value_no_signal(audio.gains[ch])

func _label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 4)
	return l

func _button(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", CREAM)
	b.focus_mode = Control.FOCUS_NONE
	# hover ısınması (juice #8): imleç gelince bal tonuna yumuşak geçiş
	b.mouse_entered.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "modulate", Color(1.12, 1.05, 0.9), 0.12))
	b.mouse_exited.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "modulate", Color.WHITE, 0.2))
	return b

func _panel(title: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PANEL_BG
	sb.border_color = Palette.PANEL_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.visible = false
	var vb := VBoxContainer.new()
	vb.name = "VB"
	p.add_child(vb)
	var t := _label(title, 12, HONEY)
	vb.add_child(t)
	return p

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- HUD üst ----
	_clock = _label("18:30", 20, HONEY)
	_clock.position = Vector2(14, 6)
	root.add_child(_clock)
	_sub = _label("kasaba uyanıyor", 11, MUTED)
	_sub.position = Vector2(14, 32)
	root.add_child(_sub)
	_stat = _label("ev 0 · sakin 0", 11, MUTED)
	_stat.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_stat.position = Vector2(-160, 8)
	_stat.size = Vector2(150, 20)
	_stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_stat)

	# ---- olay akışı (alt, buton şeridinin üstü) ----
	_events = _label("Kasaba yaşıyor…", 11, SAGE)
	_events.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_events.position = Vector2(14, -46)
	_events.size = Vector2(VW() - 28, 18)
	root.add_child(_events)

	# ---- buton şeridi (alt) ----
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.position = Vector2(10, -30)
	root.add_child(bar)

	_mode_opt = OptionButton.new()
	_mode_opt.add_item("Pomodoro 25/5")
	_mode_opt.add_item("Derin 50/10")
	_mode_opt.add_theme_font_size_override("font_size", 11)
	_mode_opt.focus_mode = Control.FOCUS_NONE
	bar.add_child(_mode_opt)

	_focus_btn = _button("🎯 Başlat")
	_focus_btn.pressed.connect(_on_focus)
	bar.add_child(_focus_btn)

	_streak_btn = _button("seri 0")
	_streak_btn.add_theme_color_override("font_color", SAGE)
	_streak_btn.pressed.connect(func(): _toggle(stats_box); _refresh_stats())
	bar.add_child(_streak_btn)

	# tek sakin menü (#18): paneller ☰ altında toplanır; çekirdek etkileşimler barda kalır (kural 5)
	var menu_btn := _button("☰ Kasaba")
	_menu_btn = menu_btn
	menu_btn.pressed.connect(func(): _toggle(menu_box))
	bar.add_child(menu_btn)

	_wish_btn = _button("")
	_wish_btn.add_theme_color_override("font_color", Palette.MINT)
	_wish_btn.visible = false
	_wish_btn.pressed.connect(_on_wish)
	bar.add_child(_wish_btn)

	_mail_btn = _button("✉ Mektuplar 0")
	_mail_btn.pressed.connect(_toggle_mail)
	bar.add_child(_mail_btn)

	# ---- paneller (boş; A3-A6 doldurur) ----
	sound_box = _panel("SES ATMOSFERİ  (tamamı sentez, telifsiz)")
	sound_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	sound_box.position = Vector2(20, -190)
	root.add_child(sound_box)
	_fill_sound()

	melody_box = _panel("KULE MELODİN")
	melody_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	melody_box.position = Vector2(20, 60)
	root.add_child(melody_box)
	_fill_melody()

	stats_box = _panel("EMEĞİN")
	stats_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stats_box.position = Vector2(150, -150)
	root.add_child(stats_box)
	_stats_body = _label("", 11, CREAM)
	stats_box.get_node("VB").add_child(_stats_body)

	# tek sakin menü kutusu: Ses / Melodi / Albüm / Kartpostal (her biri menüyü kapatıp hedefi açar)
	menu_box = _panel("KASABA")
	menu_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	menu_box.position = Vector2(150, -186)
	var mvb: VBoxContainer = menu_box.get_node("VB")
	var entries := [
		["🔊 Ses atmosferi", func(): _open_from_menu(sound_box)],
		["🎼 Kule melodisi", func(): _open_from_menu(melody_box)],
		["📖 Albüm", func(): _open_from_menu(album_box); _refresh_album()],
		["📷 Kartpostal", func():
			menu_box.visible = false
			if main != null and main.has_method("take_postcard"):
				main.take_postcard()],
	]
	for e in entries:
		var mb := _button(e[0])
		mb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		mb.pressed.connect(e[1])
		mvb.add_child(mb)
	root.add_child(menu_box)

	# albüm (Faz C #17): sakin koleksiyonu + anı ağaçları + kasabanın hikâyesi (retention çekirdeği)
	album_box = _panel("ALBÜM")
	album_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	album_box.position = Vector2(-360, 8)
	album_box.custom_minimum_size = Vector2(340, 0)
	var asc := ScrollContainer.new()
	asc.custom_minimum_size = Vector2(316, 250)
	_album_list = VBoxContainer.new()
	_album_list.add_theme_constant_override("separation", 4)
	_album_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asc.add_child(_album_list)
	album_box.get_node("VB").add_child(asc)
	root.add_child(album_box)

	# sakin hover kartı: imleci sakinin üstüne getirince isim+evre (mektup göndereni kasabada bulunur)
	_person_card = PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Palette.PANEL_BG
	psb.border_color = HONEY
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(6)
	psb.set_content_margin_all(8)
	_person_card.add_theme_stylebox_override("panel", psb)
	_person_card.visible = false
	_person_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_person_body = _label("", 11, CREAM)
	_person_card.add_child(_person_body)
	root.add_child(_person_card)

	mail_box = _panel("MEKTUPLAR")
	mail_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mail_box.position = Vector2(-360, -320)
	mail_box.custom_minimum_size = Vector2(340, 0)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(316, 200)
	mail_list = VBoxContainer.new()
	mail_list.add_theme_constant_override("separation", 8)
	mail_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(mail_list)
	mail_box.get_node("VB").add_child(sc)
	root.add_child(mail_box)

func VW() -> float:
	return 960.0

func _toggle(p: Control) -> void:
	if p != null:
		p.visible = not p.visible

func _open_from_menu(p: Control) -> void:
	menu_box.visible = false
	_toggle(p)

## Buton üç durumda üç iş yapar: boşta başlat, çalışırken CEZASIZ bırak, molada molayı atla + yeni seans.
func _on_focus() -> void:
	if main == null or not main.has_method("focus_state"):
		return
	if main.focus_state().phase == "work":
		main.cancel_focus()
	else:
		main.start_focus(_mode_opt.selected)

func _refresh_stats() -> void:
	if world == null or _stats_body == null:
		return
	_stats_body.text = "bugün %d dk · toplam %d dk\nseri %d · en uzun seri %d · %d seans" % [
		world.today_focus_min, world.stat_focus_min, world.streak, world.best_streak, world.sessions]

func _on_wish() -> void:
	if main != null and main.has_method("grant_wish"):
		main.grant_wish()

func show_offline(s: Dictionary) -> void:
	if s.get("ticks", 0) <= 0:
		return
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PANEL_BG
	sb.border_color = HONEY
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-190, -90)
	card.custom_minimum_size = Vector2(380, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	var days := float(s.ticks) / 2400.0
	vb.add_child(_label("SEN YOKKEN", 14, HONEY))
	var body := "%.1f gün geçti.\n🌱 %d doğum    ✦ %d veda    🧳 %d yeni komşu\nNüfus %d → %d" % [days, s.births, s.farewells, s.arrivals, s.pop_before, s.pop_after]
	if s.get("capped", false):
		body += "\n(kasaba uzunca kendi halinde yaşadı)"
	var bl := _label(body, 12, CREAM)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.custom_minimum_size = Vector2(344, 0)
	vb.add_child(bl)
	var ok := _button("kasabaya dön")
	ok.add_theme_color_override("font_color", Palette.MINT)
	ok.pressed.connect(func(): card.queue_free())
	vb.add_child(ok)
	get_node(".").add_child(card)   # CanvasLayer'a ekle (root Control mouse_filter IGNORE)

func _toggle_mail() -> void:
	mail_box.visible = not mail_box.visible
	if mail_box.visible:
		refresh_mail()

func refresh_mail() -> void:
	if mail_list == null or world == null:
		return
	for c in mail_list.get_children():
		c.queue_free()
	for l in world.letters:
		mail_list.add_child(_letter_card(l))

# ---- ses mikseri (A6; B+ kalıcı ayarlar) ----
var _sound_sliders := {}   # kanal -> HSlider (sync_from_world ayarlardan doldurur)

func _fill_sound() -> void:
	var vb := sound_box.get_node("VB")
	var rows := [
		["🌧 yağmur", "rain"], ["💧 dere", "stream"],
		["🎹 lo-fi pad", "pad"], ["🦗 gece", "cricket"], ["🔊 ana", "master"],
	]
	for row in rows:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		var lbl := _label(row[0], 11, MUTED)
		lbl.custom_minimum_size = Vector2(90, 0)
		hb.add_child(lbl)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.01
		sl.value = Settings.AUDIO_DEFAULTS[row[1]]
		sl.custom_minimum_size = Vector2(120, 0)
		var ch: String = row[1]
		sl.value_changed.connect(func(v): if audio != null: audio.set_gain(ch, v))
		hb.add_child(sl)
		_sound_sliders[ch] = sl
		vb.add_child(hb)

# ---- melodi ızgarası (A5) ----
func _mel_style(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = HONEY if active else Palette.MEL_CELL
	sb.border_color = Palette.MEL_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	return sb

func _fill_melody() -> void:
	var vb := melody_box.get_node("VB")
	var grid := GridContainer.new()
	grid.columns = Melody.STEPS
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	_mel_cells.resize(Melody.STEPS)
	for c in range(Melody.STEPS):
		_mel_cells[c] = []
		_mel_cells[c].resize(Melody.ROWS)
	# satırlar yukarıdan aşağı: r = 5..0
	for r in range(Melody.ROWS - 1, -1, -1):
		for c in range(Melody.STEPS):
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(22, 16)
			cell.focus_mode = Control.FOCUS_NONE
			var cc := c
			var rr := r
			cell.pressed.connect(func(): _toggle_note(cc, rr))
			grid.add_child(cell)
			_mel_cells[c][r] = cell
	vb.add_child(grid)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var play := _button("▶ dinle")
	play.add_theme_color_override("font_color", Palette.MINT)
	play.pressed.connect(_on_mel_play)
	hb.add_child(play)
	var teach := _button("🗼 kuleye öğret")
	teach.add_theme_color_override("font_color", HONEY)
	teach.pressed.connect(_on_mel_teach)
	hb.add_child(teach)
	vb.add_child(hb)
	_mel_note = _label("Kule her saat başı senin melodini çalar. Sütuna dokun: nota koy/kaldır.", 10, Palette.FADED)
	_mel_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mel_note.custom_minimum_size = Vector2(200, 0)
	vb.add_child(_mel_note)
	_refresh_melody()

func _toggle_note(c: int, r: int) -> void:
	_melody[c] = -1 if _melody[c] == r else r
	_refresh_melody()
	if main != null and main.has_method("play_tone"):
		main.play_tone(r)   # A6 ses

func _refresh_melody() -> void:
	for c in range(Melody.STEPS):
		for r in range(Melody.ROWS):
			var active: bool = _melody[c] == r
			_mel_cells[c][r].add_theme_stylebox_override("normal", _mel_style(active))
			_mel_cells[c][r].add_theme_stylebox_override("hover", _mel_style(active))
			_mel_cells[c][r].add_theme_stylebox_override("pressed", _mel_style(active))

func _on_mel_play() -> void:
	if main != null and main.has_method("play_melody"):
		main.play_melody(_melody)

func _on_mel_teach() -> void:
	if main == null or not main.has_method("teach_tower"):
		return
	var res: Dictionary = main.teach_tower(_melody)
	if res.get("concert", false):
		_mel_note.text = "Kule melodini öğrendi — MEYDAN KONSERİ! Herkes senin şarkınla dans etti."
	elif res.get("quality", {}).get("ok", false):
		_mel_note.text = "Kule melodini öğrendi — her saat başı çalacak."
	else:
		_mel_note.text = "Kule öğrendi. İpucu: en az 5 nota, 3 farklı ses ve iniş-çıkış olursa kasaba coşar…"

# kart lid yakalar (INDEX DEĞİL — sim push_front yaptıkça index kayıyor, yanlış mektup yanıtlanıyordu)
func _letter_card(l: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD_BG
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(9)
	sb.border_color = HONEY
	sb.border_width_left = 2
	card.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	card.add_child(vb)
	var txt := Label.new()
	txt.text = l.text
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.custom_minimum_size = Vector2(288, 0)
	txt.add_theme_font_size_override("font_size", 12)
	txt.add_theme_color_override("font_color", Color("d8ccc0"))
	vb.add_child(txt)
	var from := Label.new()
	from.text = "— " + l.from
	from.add_theme_font_size_override("font_size", 10)
	from.add_theme_color_override("font_color", HONEY)
	from.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(from)
	if l.replied:
		var r := _label("✓ yanıtladın · bağ +1", 10, SAGE)
		vb.add_child(r)
	else:
		var rb := _button("İçtenlikle yanıtla")
		rb.add_theme_color_override("font_color", Palette.MINT)
		var lid := int(l.get("lid", -1))
		rb.pressed.connect(func(): if main != null and main.has_method("reply_letter"): main.reply_letter(lid))
		vb.add_child(rb)
	return card

# ---- ANA MENÜ (Faz C): canlı sim arka planda, yarı saydam perde; Esc de bunu açar ----
var menu_screen: PanelContainer = null
var _menu_msg: Label
var _confirm_new := false
var _quick_cb: CheckBox

const CREDITS := "NEFES — Rain City evreni.\nGodot Engine ile yapıldı (MIT lisansı, © Godot Engine katkıcıları).\nTüm görseller prosedürel, tüm sesler %100 sentez.\nSolo geliştirici + Claude."

func show_menu() -> void:
	if menu_screen == null:
		_build_menu()
	_confirm_new = false
	_menu_msg.text = "ekranının altında, sen çalışırken uyanan minyatür bir kasaba"
	_quick_cb.set_pressed_no_signal(Settings.get_flag("quick_start"))
	menu_screen.visible = true
	menu_screen.modulate.a = 0.0
	create_tween().tween_property(menu_screen, "modulate:a", 1.0, 0.3)   # yumuşak giriş (fade)

func hide_menu() -> void:
	if menu_screen != null:
		var tw := create_tween()
		tw.tween_property(menu_screen, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func(): menu_screen.visible = false)

func menu_visible() -> bool:
	return menu_screen != null and menu_screen.visible

func _build_menu() -> void:
	menu_screen = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.PANEL_BG, 0.82)   # panel-zemin perdesi — canlı kasaba altta seçilir
	menu_screen.add_theme_stylebox_override("panel", sb)
	menu_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_screen.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_screen.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)
	var title := _label("N E F E S", 34, HONEY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	_menu_msg = _label("", 11, MUTED)
	_menu_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_msg.custom_minimum_size = Vector2(420, 0)
	vb.add_child(_menu_msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	var bresume := _button("▶ Devam Et")
	bresume.add_theme_color_override("font_color", Palette.MINT)
	bresume.pressed.connect(func(): hide_menu())
	row.add_child(bresume)
	var bnew := _button("🌱 Yeni Kasaba")
	bnew.pressed.connect(_on_new_town)
	row.add_child(bnew)
	var bcred := _button("ℹ Krediler")
	bcred.pressed.connect(func(): _confirm_new = false; _menu_msg.text = CREDITS)
	row.add_child(bcred)
	var bquit := _button("✕ Kaydet ve Çık")
	bquit.pressed.connect(func(): if main != null: main.quit_game())
	row.add_child(bquit)
	_quick_cb = CheckBox.new()
	_quick_cb.text = "açılışta menüyü atla, doğrudan kasabaya gel"
	_quick_cb.add_theme_font_size_override("font_size", 10)
	_quick_cb.add_theme_color_override("font_color", MUTED)
	_quick_cb.focus_mode = Control.FOCUS_NONE
	_quick_cb.toggled.connect(func(v): Settings.set_flag("quick_start", v))
	var qrow := HBoxContainer.new()
	qrow.alignment = BoxContainer.ALIGNMENT_CENTER
	qrow.add_child(_quick_cb)
	vb.add_child(qrow)
	add_child(menu_screen)   # CanvasLayer'a — her şeyin üstünde

## Yeni Kasaba: iki aşamalı NAZİK onay (cozy: yanlışlıkla kayıp yok; mevcut kayıt .bak'a alınır).
func _on_new_town() -> void:
	if not _confirm_new:
		_confirm_new = true
		_menu_msg.text = "Emin misin? Mevcut kasaban güvenle yedeklenecek (save.json.bak) ve bugünün tohumuyla yepyeni bir kasaba uyanacak. Bir daha dokunursan başlıyoruz."
		return
	_confirm_new = false
	if main != null and main.has_method("new_town"):
		main.new_town()
	hide_menu()

func _process(delta: float) -> void:
	if world == null:
		return
	_t += delta
	_clock.text = world.clock_string()
	_sub.text = "%s · %s" % [World.SEASON_NAMES[world.season], world.status_text()]
	_stat.text = "ev %d · sakin %d" % [world.lit_count(), world.population()]
	_streak_btn.text = "seri %d" % world.streak
	_refresh_focus_button()
	_refresh_person_card()
	if stats_box != null and stats_box.visible:
		_refresh_stats()
	# olay satırı: yeni olay soldan kayarak süzülür (juice #8)
	if not world.event_log.is_empty():
		var latest: String = world.event_log.back()
		if latest != _last_event:
			_last_event = latest
			_events.position.x = 14.0 + 22.0
			_events.modulate.a = 0.0
			var tw := create_tween().set_parallel(true)
			tw.tween_property(_events, "position:x", 14.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(_events, "modulate:a", 1.0, 0.35)
		_events.text = "   ·   ".join(world.event_log)
	var unreplied := world.unreplied_letters()
	_mail_btn.text = ("✉ %d" if _compact else "✉ Mektuplar %d") % unreplied
	# zarf sallanması: yanıtsız mektup bekliyorken nazik hatırlatma (bildirim spam'i DEĞİL — sessiz salınım)
	_mail_btn.pivot_offset = _mail_btn.size / 2.0
	_mail_btn.rotation = (sin(_t * 2.4) * 0.045) if unreplied > 0 else 0.0
	var wt := world.wish_text()
	if wt != "":
		_wish_btn.text = wt if not _compact else "💭 dilek"
		_wish_btn.visible = true
	else:
		_wish_btn.visible = false

## Dikey mod (C19): dar pencerede bar sığsın — mod seçici gizlenir, etiketler kısalır.
func set_vertical(v: bool) -> void:
	_compact = v
	if _mode_opt != null:
		_mode_opt.visible = not v
	if _events != null:
		_events.size.x = (340.0 if v else VW() - 28.0)
	if _menu_btn != null:
		_menu_btn.text = "☰" if v else "☰ Kasaba"

## Albüm içeriği: yaşayan sakinler + anı ağaçları + hikâye sayaçları. Açılışta tazelenir (her karede değil).
func _refresh_album() -> void:
	if world == null or _album_list == null:
		return
	for c in _album_list.get_children():
		c.queue_free()
	_album_list.add_child(_label("SAKİNLER (%d)" % world.population(), 11, HONEY))
	for p in world.people:
		var line: String = "● %s · %s" % [p.name, STAGE_NAMES[clampi(int(p.stage), 0, 2)]]
		if p.scarf:
			line += " · 💛"
		_album_list.add_child(_label(line, 10, CREAM))
	_album_list.add_child(_label(" ", 4, CREAM))
	_album_list.add_child(_label("ANI AĞAÇLARI (%d)" % world.mem_trees.size(), 11, Palette.LILAC))
	for mt in world.mem_trees:
		_album_list.add_child(_label("✦ %s'nin ağacı" % mt.name, 10, Palette.LILAC))
	_album_list.add_child(_label(" ", 4, CREAM))
	_album_list.add_child(_label("KASABANIN HİKÂYESİ", 11, HONEY))
	var w := world
	var story := "🌱 %d doğum · ✦ %d veda · 🧳 %d gelen\n🌟 %d dilek gerçekleşti · 💛 bağ %d\n🎯 %d seans · %d dk emek · en uzun seri %d" % [
		w.stat_births, w.stat_farewells, w.stat_arrivals, w.stat_wishes, w.bond,
		w.sessions, w.stat_focus_min, w.best_streak]
	if w.concert_done:
		story += "\n🎻 Meydan Konseri verildi"
	if w.unlocked.atolye:
		story += "\n🔨 Atölye kuruldu"
	if w.unlocked.kutuphane:
		story += "\n📚 Kütüphane yükseldi"
	var sl := _label(story, 10, CREAM)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size = Vector2(300, 0)
	_album_list.add_child(sl)

## İmleç altındaki sakinin mini kartı (main.hovered_person → render tespiti). Kart imleci izler.
func _refresh_person_card() -> void:
	if main == null or not main.has_method("hovered_person"):
		return
	var hp: Dictionary = main.hovered_person()
	if hp.has("person"):
		var p = hp.person
		var line: String = STAGE_NAMES[clampi(int(p.stage), 0, 2)]
		if p.scarf:
			line += " · 💛 atkılı"
		if p.get("wants_home", false):
			line += " · 🌿 yuva arıyor"
		_person_body.text = "%s\n%s" % [p.name, line]
		var px: Vector2 = hp.px
		_person_card.position = Vector2(clampf(px.x + 10.0, 4.0, VW() - 170.0), clampf(px.y - 46.0, 4.0, 310.0))
		_person_card.visible = true
	else:
		_person_card.visible = false

## Geri sayım + faz metni tek kaynaktan (main.focus_state). Mod seçici seans sırasında kilitli.
func _refresh_focus_button() -> void:
	if main == null or not main.has_method("focus_state"):
		return
	var fs: Dictionary = main.focus_state()
	var rem: int = int(ceil(float(fs.remaining)))
	match fs.phase:
		"work":
			_focus_btn.text = "🎯 %02d:%02d · bırak" % [rem / 60, rem % 60]
			_mode_opt.disabled = true
		"break":
			_focus_btn.text = "☕ mola %02d:%02d · yeni seans" % [rem / 60, rem % 60]
			_mode_opt.disabled = false
		_:
			_focus_btn.text = "🎯 Başlat"
			_mode_opt.disabled = false
