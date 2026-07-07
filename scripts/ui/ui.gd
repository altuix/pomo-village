extends CanvasLayer
## NEFES UI (ANAYASA kural 5: paneller varsayılan KAPALI; çekirdek izle→büyür→mektup boğulmaz).
## HTML DOM HUD/bar/paneller → Godot Control. World'ü OKUR; eylemler main'e/dünyaya iletilir.
## A7 iskele: HUD + olay akışı + buton şeridi + boş paneller (A3 odak / A4 mektup / A5 melodi / A6 ses doldurur).

var world: World = null
var main: Node = null
var audio = null   # ses motoru (mikser slider'ları için)

const INK := Color("2b1e2e")
const HONEY := Color("ffe6a8")
const CREAM := Color("e8dcc8")
const SAGE := Color("7a9b6a")
const MUTED := Color("c9a892")

var _clock: Label
var _sub: Label
var _stat: Label
var _events: Label
var _streak: Label
var _mail_btn: Button
var _wish_btn: Button
var _focus_btn: Button
var _mode_opt: OptionButton

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
	return b

func _panel(title: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1d1424")
	sb.border_color = Color("5a3f52")
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

	_streak = _label("seri 0", 11, SAGE)
	bar.add_child(_streak)

	var snd := _button("🔊")
	snd.pressed.connect(func(): _toggle(sound_box))
	bar.add_child(snd)

	var mel := _button("🎼 Kule melodisi")
	mel.pressed.connect(func(): _toggle(melody_box))
	bar.add_child(mel)

	_wish_btn = _button("")
	_wish_btn.add_theme_color_override("font_color", Color("c9e0b0"))
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

func _on_focus() -> void:
	if main != null and main.has_method("start_focus"):
		main.start_focus(_mode_opt.selected)

func set_focus_active(active: bool) -> void:
	if active:
		_focus_btn.text = "🎯 Odaktasın… kasaba ×1.5 büyüyor"
		_focus_btn.disabled = true
	else:
		_focus_btn.text = "🎯 Başlat"
		_focus_btn.disabled = false

func _on_wish() -> void:
	if main != null and main.has_method("grant_wish"):
		main.grant_wish()

func show_offline(s: Dictionary) -> void:
	if s.get("ticks", 0) <= 0:
		return
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1d1424")
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
	ok.add_theme_color_override("font_color", Color("c9e0b0"))
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
	for i in range(world.letters.size()):
		mail_list.add_child(_letter_card(world.letters[i], i))

# ---- ses mikseri (A6) ----
func _fill_sound() -> void:
	var vb := sound_box.get_node("VB")
	var rows := [
		["🌧 yağmur", "rain", 0.0], ["💧 dere", "stream", 0.0],
		["🎹 lo-fi pad", "pad", 0.0], ["🦗 gece", "cricket", 0.0], ["🔊 ana", "master", 0.7],
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
		sl.value = row[2]
		sl.custom_minimum_size = Vector2(120, 0)
		var ch: String = row[1]
		sl.value_changed.connect(func(v): if audio != null: audio.set_gain(ch, v))
		hb.add_child(sl)
		vb.add_child(hb)

# ---- melodi ızgarası (A5) ----
func _mel_style(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = HONEY if active else Color("2a1f30")
	sb.border_color = Color("3d2b40")
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
	play.add_theme_color_override("font_color", Color("c9e0b0"))
	play.pressed.connect(_on_mel_play)
	hb.add_child(play)
	var teach := _button("🗼 kuleye öğret")
	teach.add_theme_color_override("font_color", HONEY)
	teach.pressed.connect(_on_mel_teach)
	hb.add_child(teach)
	vb.add_child(hb)
	_mel_note = _label("Kule her saat başı senin melodini çalar. Sütuna dokun: nota koy/kaldır.", 10, Color("7a6a72"))
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

func _letter_card(l: Dictionary, idx: int) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("241a2a")
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
		rb.add_theme_color_override("font_color", Color("c9e0b0"))
		rb.pressed.connect(func(): if main != null and main.has_method("reply_letter"): main.reply_letter(idx))
		vb.add_child(rb)
	return card

func _process(_d: float) -> void:
	if world == null:
		return
	_clock.text = world.clock_string()
	_sub.text = "%s · %s" % [World.SEASON_NAMES[world.season], world.status_text()]
	_stat.text = "ev %d · sakin %d" % [world.lit_count(), world.population()]
	_streak.text = "seri %d" % world.streak
	if not world.event_log.is_empty():
		_events.text = "   ·   ".join(world.event_log)
	_mail_btn.text = "✉ Mektuplar %d" % world.unreplied_letters()
	var wt := world.wish_text()
	if wt != "":
		_wish_btn.text = wt
		_wish_btn.visible = true
	else:
		_wish_btn.visible = false
