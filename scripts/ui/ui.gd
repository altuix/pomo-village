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
var _mute_btn: Button
var _premute := 0.7      # sustur öncesi master (geri açınca dönülecek seviye)
var _mail_seen := 0      # zarf salınımı yalnız YENİ mektupta (playtest: sürekli sallanma bunaltıcı)
var _sway_until := 0.0

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

var _bar: HBoxContainer = null

func _ready() -> void:
	Loc.boot()
	_build()

## Dil değişimi (S3): UI komple yeniden kurulur — kayıtlı melodi/slider'lar senkronlanır, menü yeniden açılır.
func rebuild_ui() -> void:
	for c in get_children():
		c.queue_free()
	menu_screen = null
	_mel_cells = []
	_sound_sliders = {}
	_build()
	sync_from_world()
	show_menu()

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

## S2: butonlar GERÇEK buton — normal/hover/pressed StyleBox (dolgusuz link-görünümü playtest
## şikâyetiydi); pressed'de 1px içeri (bastım hissi).
func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	return sb

func _button(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_stylebox_override("normal", _btn_style(Color(Palette.PANEL_BG, 0.85), Palette.PANEL_BORDER))
	b.add_theme_stylebox_override("hover", _btn_style(Color(Palette.PANEL_BORDER, 0.85), HONEY))
	var pr := _btn_style(Color(Palette.PANEL_BG, 1.0), HONEY)
	pr.content_margin_top = 6.0
	pr.content_margin_bottom = 4.0
	b.add_theme_stylebox_override("pressed", pr)
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
	# başlık satırı: sol başlık + sağ ✕ (playtest: "paneller kolay kapanmıyor" — kapatma
	# affordance'ı HİÇ yoktu; ✕ tek noktadan tüm panellere gelir)
	var hb := HBoxContainer.new()
	var t := _label(title, 12, HONEY)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(t)
	var xb := _button("✕")
	xb.tooltip_text = Loc.t("tt_close")
	xb.pressed.connect(func(): if p.visible: _toggle(p))
	hb.add_child(xb)
	vb.add_child(hb)
	return p

var _click_catcher: Control = null

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# dış-tık yakalayıcı (panellerden ÖNCE eklenir → arkalarında kalır): boşluğa tık = paneli kapat
	_click_catcher = Control.new()
	_click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_catcher.visible = false
	_click_catcher.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close_open_panels())
	root.add_child(_click_catcher)

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
	_events.position = Vector2(14, -52)   # bar ile çakışmasın (S1)
	_events.size = Vector2(VW() - 28, 18)
	root.add_child(_events)

	# ---- buton şeridi (alt) ----
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.position = Vector2(10, -30)
	root.add_child(bar)
	_bar = bar

	_mode_opt = OptionButton.new()
	_mode_opt.add_item(Loc.t("mode0"))
	_mode_opt.add_item(Loc.t("mode1"))
	_mode_opt.add_theme_font_size_override("font_size", 11)
	_mode_opt.focus_mode = Control.FOCUS_NONE
	bar.add_child(_mode_opt)

	_focus_btn = _button(Loc.t("start"))
	_focus_btn.tooltip_text = Loc.t("tt_focus")
	_focus_btn.pressed.connect(_on_focus)
	bar.add_child(_focus_btn)

	_streak_btn = _button(Loc.t("series") % 0)
	_streak_btn.tooltip_text = Loc.t("tt_series")
	_streak_btn.add_theme_color_override("font_color", SAGE)
	_streak_btn.pressed.connect(func(): _toggle(stats_box); _refresh_stats())
	bar.add_child(_streak_btn)

	# tek sakin menü (#18): paneller ☰ altında toplanır; çekirdek etkileşimler barda kalır (kural 5)
	var menu_btn := _button(Loc.t("town_menu"))
	menu_btn.tooltip_text = Loc.t("tt_town")
	_menu_btn = menu_btn
	menu_btn.pressed.connect(func(): _toggle(menu_box))
	bar.add_child(menu_btn)

	_wish_btn = _button("")
	_wish_btn.add_theme_color_override("font_color", Palette.MINT)
	_wish_btn.visible = false
	_wish_btn.pressed.connect(_on_wish)
	bar.add_child(_wish_btn)

	_mute_btn = _button("🔊")
	_mute_btn.tooltip_text = Loc.t("tt_mute")
	_mute_btn.pressed.connect(_on_mute)
	bar.add_child(_mute_btn)

	_mail_btn = _button(Loc.t("letters_btn") % 0)
	_mail_btn.tooltip_text = Loc.t("tt_mail")
	_mail_btn.pressed.connect(_toggle_mail)
	bar.add_child(_mail_btn)

	# ---- paneller (boş; A3-A6 doldurur) ----
	sound_box = _panel(Loc.t("p_sound"))
	sound_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	sound_box.position = Vector2(20, -190)
	root.add_child(sound_box)
	_fill_sound()

	melody_box = _panel(Loc.t("p_melody"))
	melody_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	melody_box.position = Vector2(20, 60)
	root.add_child(melody_box)
	_fill_melody()

	stats_box = _panel(Loc.t("p_stats"))
	stats_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stats_box.position = Vector2(150, -150)
	root.add_child(stats_box)
	_stats_body = _label("", 11, CREAM)
	stats_box.get_node("VB").add_child(_stats_body)

	# tek sakin menü kutusu: Ses / Melodi / Albüm / Kartpostal (her biri menüyü kapatıp hedefi açar)
	menu_box = _panel(Loc.t("p_town"))
	menu_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	menu_box.position = Vector2(150, -186)
	var mvb: VBoxContainer = menu_box.get_node("VB")
	var entries := [
		[Loc.t("snd_row"), func(): _open_from_menu(sound_box)],
		[Loc.t("mel_row"), func(): _open_from_menu(melody_box)],
		[Loc.t("alb_row"), func(): _open_from_menu(album_box); _refresh_album()],
		[Loc.t("cam_row"), func():
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
	album_box = _panel(Loc.t("p_album"))
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

	mail_box = _panel(Loc.t("p_mail"))
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

## Açık drawer listesi (tek-drawer politikası + Esc/dış-tık kapatma bu listeyi gezer)
func _drawers() -> Array:
	return [sound_box, melody_box, mail_box, album_box, stats_box, menu_box]

## Esc/dış-tık: açık paneli kapat; kapattıysa true (main Esc önceliği için — menü sonra gelir)
func close_open_panels() -> bool:
	var closed := false
	for p in _drawers():
		if p != null and p.visible:
			_toggle(p)
			closed = true
	return closed

# J4: paneller anlık aç/kapa yerine çekmece hissi — 12px kenar-kayması + fade (0.18s).
# base_pos meta'da tutulur (tween pozisyonu bozmasın); hızlı çift-tık eski tween'i öldürür.
# S1: açılırken DİĞER drawer'lar kapanır (üst üste 6 panel lapası playtest şikâyetiydi);
# dış-tık yakalayıcı panel açıkken belirir.
func _toggle(p: Control) -> void:
	if p == null:
		return
	if not p.visible:
		for other in _drawers():
			if other != null and other != p and other.visible:
				_toggle(other)
	if not p.has_meta("base_pos"):
		p.set_meta("base_pos", p.position)
	var base: Vector2 = p.get_meta("base_pos")
	if p.has_meta("tw") and is_instance_valid(p.get_meta("tw")):
		(p.get_meta("tw") as Tween).kill()
	var tw := create_tween().set_parallel(true)
	p.set_meta("tw", tw)
	if not p.visible:
		p.set_meta("open_target", true)
		p.visible = true
		p.position = base + Vector2(-12, 0)
		p.modulate.a = 0.0
		tw.tween_property(p, "position", base, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 1.0, 0.15)
	else:
		p.set_meta("open_target", false)
		tw.tween_property(p, "position", base + Vector2(-12, 0), 0.13)
		tw.tween_property(p, "modulate:a", 0.0, 0.13)
		tw.chain().tween_callback(func():
			p.visible = false
			p.position = base
			p.modulate.a = 1.0)
	# dış-tık yakalayıcı: herhangi bir drawer hedef-açıkken belirir (boşluğa tık = kapat)
	if _click_catcher != null:
		var any_open := false
		for d in _drawers():
			if d != null and d.get_meta("open_target", false):
				any_open = true
		_click_catcher.visible = any_open

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

## Hızlı sustur (playtest: ses 3 tık uzaktaydı — always-on şeritte tek tık şart)
func _on_mute() -> void:
	if audio == null:
		return
	if audio.gains.master > 0.001:
		_premute = audio.gains.master
		audio.set_gain("master", 0.0)
		_mute_btn.text = "🔇"
	else:
		audio.set_gain("master", _premute if _premute > 0.001 else 0.7)
		_mute_btn.text = "🔊"
	sync_from_world()   # ses panelindeki master slider'ı da güncellensin

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
	_toggle(mail_box)   # çekmece animasyonu (J4)
	if mail_box.visible:
		refresh_mail()
		if audio != null:
			audio.event("letter")   # kağıt hışırtısı — zarf açılıyor (J3)

func refresh_mail() -> void:
	if mail_list == null or world == null:
		return
	for c in mail_list.get_children():
		c.queue_free()
	# J3: kartlar kademeli belirir (kağıtlar tek tek masaya konur hissi)
	var i := 0
	for l in world.letters:
		var card := _letter_card(l)
		mail_list.add_child(card)
		card.modulate.a = 0.0
		create_tween().tween_property(card, "modulate:a", 1.0, 0.22).set_delay(minf(0.4, i * 0.04))
		i += 1

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

# J3: mektup = KAĞIT (duygusal çekirdek en soğuk ekrandı — juice kritiği). CREAM zemin,
# ink mürekkep, honey mühür noktası. Kart lid yakalar (INDEX DEĞİL — push_front kaydırıyordu).
func _letter_card(l: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(10)
	sb.border_color = HONEY
	sb.border_width_left = 3
	sb.border_width_bottom = 1
	card.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	card.add_child(vb)
	# mühür: gönderen satırının önünde küçük bal-mumu noktası (draw yerine tekst-dışı ayraç)
	var txt := Label.new()
	txt.text = l.text
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.custom_minimum_size = Vector2(288, 0)
	txt.add_theme_font_size_override("font_size", 12)
	txt.add_theme_color_override("font_color", INK)   # kağıt üstünde mürekkep
	vb.add_child(txt)
	var from := Label.new()
	from.text = "●  — %s" % l.from
	from.add_theme_font_size_override("font_size", 10)
	from.add_theme_color_override("font_color", Color(Palette.PANEL_BORDER, 1.0))
	from.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(from)
	if l.replied:
		var r := Label.new()
		r.text = Loc.t("replied")
		r.add_theme_font_size_override("font_size", 10)
		r.add_theme_color_override("font_color", SAGE.darkened(0.25))
		vb.add_child(r)
	else:
		var rb := _button(Loc.t("reply"))
		rb.add_theme_color_override("font_color", Palette.MINT)
		var lid := int(l.get("lid", -1))
		rb.pressed.connect(func(): if main != null and main.has_method("reply_letter"): main.reply_letter(lid))
		vb.add_child(rb)
	return card

# ---- ANA MENÜ v2 (S2 yeniden tasarım): birincil eylem hiyerarşisi + ⚙ Ayarlar bloğu +
# dil seçici + sürüm/ipucu satırı; menü açıkken alt bar gizlenir (çift-katman karmaşası bitti) ----
var menu_screen: PanelContainer = null
var _menu_msg: Label
var _confirm_new := false
var _quick_cb: CheckBox

func show_menu() -> void:
	if menu_screen == null:
		_build_menu()
	_confirm_new = false
	_menu_msg.text = Loc.t("identity")
	_quick_cb.set_pressed_no_signal(Settings.get_flag("quick_start"))
	if _bar != null:
		_bar.visible = false
	menu_screen.visible = true
	menu_screen.modulate.a = 0.0
	create_tween().tween_property(menu_screen, "modulate:a", 1.0, 0.3)

func hide_menu() -> void:
	if _bar != null:
		_bar.visible = true
	if menu_screen != null:
		var tw := create_tween()
		tw.tween_property(menu_screen, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func(): menu_screen.visible = false)

func menu_visible() -> bool:
	return menu_screen != null and menu_screen.visible

## Birincil eylem butonu: HONEY dolgu + ink metin (S2: hiyerarşi — göz önce buraya)
func _primary_button(txt: String) -> Button:
	var b := _button(txt)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_stylebox_override("normal", _btn_style(HONEY, HONEY.darkened(0.2)))
	b.add_theme_stylebox_override("hover", _btn_style(Color(1.0, 0.94, 0.75), HONEY))
	var pr := _btn_style(HONEY.darkened(0.08), HONEY.darkened(0.3))
	pr.content_margin_top = 7.0
	pr.content_margin_bottom = 3.0
	b.add_theme_stylebox_override("pressed", pr)
	return b

func _build_menu() -> void:
	menu_screen = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.PANEL_BG, 0.92)   # 0.82 idi — metin okunmuyordu (S2)
	menu_screen.add_theme_stylebox_override("panel", sb)
	menu_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_screen.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_screen.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)
	var title := _label("N E F E S", 36, HONEY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	_menu_msg = _label("", 12, MUTED)
	_menu_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_msg.custom_minimum_size = Vector2(440, 0)
	vb.add_child(_menu_msg)
	# birincil: Devam Et (tam genişlik, HONEY) — S2 hiyerarşi
	var bresume := _primary_button(Loc.t("resume"))
	bresume.custom_minimum_size = Vector2(440, 0)
	bresume.pressed.connect(func(): hide_menu())
	vb.add_child(bresume)
	# ikincil satır
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	var bnew := _button(Loc.t("new_town"))
	bnew.pressed.connect(_on_new_town)
	row.add_child(bnew)
	var bcred := _button(Loc.t("credits"))
	bcred.pressed.connect(func(): _confirm_new = false; _menu_msg.text = Loc.t("credits_body"))
	row.add_child(bcred)
	var bquit := _button(Loc.t("quit"))
	bquit.pressed.connect(func(): if main != null: main.quit_game())
	row.add_child(bquit)
	# ⚙ AYARLAR — çerçeveli blok (playtest: "ayar göremedim" — artık görünür bir grup)
	var spanel := PanelContainer.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(Palette.PANEL_BG, 0.6)
	ssb.border_color = Palette.PANEL_BORDER
	ssb.set_border_width_all(1)
	ssb.set_corner_radius_all(8)
	ssb.set_content_margin_all(12)
	spanel.add_theme_stylebox_override("panel", ssb)
	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 8)
	spanel.add_child(svb)
	svb.add_child(_label(Loc.t("settings"), 13, HONEY))
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	srow.add_child(_label(Loc.t("scale") + ":", 11, MUTED))
	var fitb := _button(Loc.t("fit"))
	fitb.pressed.connect(func(): if main != null and main.has_method("set_window_scale"): main.set_window_scale(0))
	srow.add_child(fitb)
	for n in [1, 2, 3]:
		var sbtn := _button("%d×" % n)
		var nn: int = n
		sbtn.pressed.connect(func(): if main != null and main.has_method("set_window_scale"): main.set_window_scale(nn))
		srow.add_child(sbtn)
	var vbtn := _button(Loc.t("vertical"))
	vbtn.pressed.connect(func(): if main != null and main.has_method("toggle_vertical"): main.toggle_vertical())
	srow.add_child(vbtn)
	svb.add_child(srow)
	# dil seçici (S3 — playtest: "dil seçimi bulamadım")
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 8)
	lrow.add_child(_label(Loc.t("language") + ":", 11, MUTED))
	for lg in [["tr", "Türkçe"], ["en", "English"]]:
		var lb := _button(lg[1])
		var code: String = lg[0]
		if Loc.lang == code:
			lb.add_theme_color_override("font_color", HONEY)
		lb.pressed.connect(func():
			Loc.set_lang(code)
			rebuild_ui())
		lrow.add_child(lb)
	svb.add_child(lrow)
	# DEV hız (yalnız debug build)
	if OS.is_debug_build():
		var drow := HBoxContainer.new()
		drow.add_theme_constant_override("separation", 8)
		drow.add_child(_label(Loc.t("dev_speed") + ":", 11, MUTED))
		for m in [1, 50, 500]:
			var db := _button("×%d" % m)
			var mm: float = float(m)
			db.pressed.connect(func(): if main != null and main.has_method("set_time_mult"): main.set_time_mult(mm))
			drow.add_child(db)
		svb.add_child(drow)
	_quick_cb = CheckBox.new()
	_quick_cb.text = Loc.t("quick")
	_quick_cb.add_theme_font_size_override("font_size", 10)
	_quick_cb.add_theme_color_override("font_color", MUTED)
	_quick_cb.focus_mode = Control.FOCUS_NONE
	_quick_cb.toggled.connect(func(v): Settings.set_flag("quick_start", v))
	svb.add_child(_quick_cb)
	vb.add_child(spanel)
	# sürüm + kısayol ipuçları (S2: cilasız/yönlendirmesiz his)
	var vinfo := _label("v%s · %s" % [ProjectSettings.get_setting("application/config/version", "dev"), Loc.t("hint")], 10, Palette.FADED)
	vinfo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(vinfo)
	add_child(menu_screen)   # CanvasLayer'a — her şeyin üstünde

## Yeni Kasaba: iki aşamalı NAZİK onay (cozy: yanlışlıkla kayıp yok; mevcut kayıt .bak'a alınır).
func _on_new_town() -> void:
	if not _confirm_new:
		_confirm_new = true
		_menu_msg.text = Loc.t("confirm_new")
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
	_streak_btn.text = Loc.t("series") % world.streak
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
	_mail_btn.text = (Loc.t("letters_btn_s") if _compact else Loc.t("letters_btn")) % unreplied
	# zarf salınımı YALNIZ yeni mektup gelince ~10sn (sürekli sallanma bunaltıcıydı — playtest)
	if unreplied > _mail_seen:
		_sway_until = _t + 10.0
	_mail_seen = unreplied
	_mail_btn.pivot_offset = _mail_btn.size / 2.0
	_mail_btn.rotation = (sin(_t * 2.4) * 0.045) if (unreplied > 0 and _t < _sway_until) else 0.0
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
		var dw := 380.0 if _compact else VW()
		_person_card.position = Vector2(clampf(px.x + 10.0, 4.0, dw - 170.0), clampf(px.y - 46.0, 4.0, 310.0))
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
			_focus_btn.text = Loc.t("work_fmt") % [rem / 60, rem % 60]
			_mode_opt.disabled = true
		"break":
			_focus_btn.text = Loc.t("break_skip") % [rem / 60, rem % 60]
			_mode_opt.disabled = false
		_:
			_focus_btn.text = Loc.t("start")
			_mode_opt.disabled = false
