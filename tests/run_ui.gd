extends SceneTree
# NEFES UI sözleşme + sinyal testleri (headless — Control/sinyal render'sız çalışır).
# Kök neden: "Yeni Kasaba" butonu main'de olmayan metodu çağırıyordu (has_method sessizce false)
# ve hiçbir test yakalamadı. Bu dosya iki katman kurar:
#   A) SÖZLEŞME: ui.gd'nin main'den çağırdığı HER metod gerçek Main'de var olmalı.
#   B) SİNYAL AKIŞI: butona basış gerçekten dünyayı değiştirmeli (buton→main→world zinciri).
# Kullanım: tools/godot.sh --headless --script tests/run_ui.gd

# ui.gd'nin main üzerinde çağırdığı metodlar (yeni çağrı eklersen BURAYA da ekle — kapı budur)
const MAIN_CONTRACT := [
	"start_focus", "cancel_focus", "focus_state", "hovered_person", "reply_letter",
	"grant_wish", "teach_tower", "play_tone", "play_melody", "take_postcard",
	"new_town", "quit_game", "set_window_scale", "toggle_vertical", "set_time_mult",
	"set_framed", "set_powersave",
]

# @onready alanlar _init'te hazır değil (bilinen tuzak — null erişim script hatasıyla
# quit'e ulaşamayıp headless'ı SONSUZA DEK asar) → test gövdesi ilk karede koşar.
var _n := 0
var _main = null

func _init() -> void:
	_main = load("res://Main.tscn").instantiate()
	_main.set("_is_capture", true)   # pencere/kayıt IO yok
	get_root().add_child(_main)

func _process(_d: float) -> bool:
	_n += 1
	if _n < 2:
		return false
	_run_tests()
	return false

func _run_tests() -> void:
	var ok := true
	var main = _main
	main.capture_setup(0, 19.0, 6000)   # yaşayan dünya (yetişkinler/mektuplar için)
	main.set("_frozen", false)
	var ui = main.get("ui")
	ui.visible = true

	# ---- A) SÖZLEŞME ----
	var missing := []
	for m in MAIN_CONTRACT:
		if not main.has_method(m):
			missing.append(m)
	var contract_ok: bool = missing.is_empty()
	print("UI sözleşme: eksik=%s -> %s" % [str(missing), "OK" if contract_ok else "FAIL"])
	ok = contract_ok and ok

	# ---- B) SİNYAL AKIŞLARI ----
	var w = main.get("world")

	# melodi hücresi: basış _melody'yi değiştirir
	ui._mel_cells[2][3].pressed.emit()
	var mel_ok: bool = ui._melody[2] == 3
	ui._mel_cells[2][3].pressed.emit()   # tekrar basış = sus
	mel_ok = mel_ok and ui._melody[2] == -1
	print("UI melodi hücresi: %s" % ("OK" if mel_ok else "FAIL"))
	ok = mel_ok and ok

	# odak butonu 3-durum: boşta başlat → work; work'te bırak → boş
	ui._on_focus()
	var f1: bool = main.focus_state().phase == "work"
	ui._refresh_focus_button()
	var f2: bool = Loc.t("leave") in ui._focus_btn.text   # dil-bağımsız (S3: makine EN olabilir)
	ui._on_focus()
	var f3: bool = main.focus_state().phase == ""
	print("UI odak akışı: başlat=%s sayaç-metni=%s bırak=%s" % [str(f1), str(f2), str(f3)])
	ok = f1 and f2 and f3 and ok

	# mektup yanıtı DOĞRU HEDEFE gider: panel kurulur, SONRA yeni mektup push_front edilir,
	# ekranda görünen karta basılır → o kartın mektubu yanıtlanmalı (index kayması bug'ı)
	if w.letters.is_empty():
		w._push_letter({ "from": "Test", "who": -1, "kind": "odak", "replied": false, "text": "ilk" })
	ui.refresh_mail()
	var target = w.letters[0]                      # ekrandaki üst kart bu mektuba ait
	w._push_letter({ "from": "Araya", "who": -1, "kind": "odak", "replied": false, "text": "araya giren" })
	var card = ui.mail_list.get_child(0)           # panel TAZELENMEDİ — hâlâ eski dizilim
	var btn = _find_reply_button(card)
	if btn == null:
		print("UI mektup: yanıt butonu bulunamadı FAIL"); ok = false
	else:
		btn.pressed.emit()
		var right_target: bool = target.replied and not w.letters[0].replied
		print("UI mektup hedefi: doğru=%s (hedef=%s araya-giren=%s)" % [str(right_target), str(target.replied), str(w.letters[0].replied)])
		ok = right_target and ok
		# G2: yanıtlananlar alta iner — iki grup varken ayraç etiketi görünmeli
		ui.refresh_mail()
		var has_sep := false
		for c in ui.mail_list.get_children():
			if c is Label and Loc.t("replied_sep") in c.text:
				has_sep = true
		print("UI mektup sırası: ayraç=%s" % str(has_sep))
		ok = has_sep and ok

	# Yeni Kasaba onay akışı: iki basış → dünya yeniden üretilir (tick sıfırlanır)
	ui.show_menu()
	for t in range(50): w.step_world()
	var old_tick: int = w.tick
	ui._on_new_town()                               # 1. basış: onay ister
	var confirm_ok: bool = main.get("world").tick == old_tick   # henüz değişmedi
	ui._on_new_town()                               # 2. basış: yeni kasaba
	var new_ok: bool = main.get("world") != w or main.get("world").tick < old_tick
	var fresh: bool = main.get("world").tick == 0
	print("UI yeni-kasaba: onay-bekledi=%s yenilendi=%s taze=%s" % [str(confirm_ok), str(new_ok), str(fresh)])
	ok = confirm_ok and fresh and ok

	# S1: panel kapatma UX — tek-drawer politikası + close_open_panels + ✕ butonu
	ui.hide_menu()
	ui._toggle(ui.sound_box)
	var one1: bool = ui.sound_box.visible
	ui._toggle(ui.album_box)   # açılınca sound kapanmalı (hedef-durum meta)
	var one2: bool = not ui.sound_box.get_meta("open_target", true) and ui.album_box.get_meta("open_target", false)
	var closed_any: bool = ui.close_open_panels()
	var one3: bool = not ui.album_box.get_meta("open_target", true)
	var xbtn: Button = null
	for c in ui.mail_box.get_node("VB").get_child(0).get_children():
		if c is Button:
			xbtn = c
	ui._toggle(ui.mail_box)
	xbtn.pressed.emit()   # ✕ kapatır
	var one4: bool = not ui.mail_box.get_meta("open_target", true)
	print("UI panel-UX: tek-drawer=%s/%s esc-kapat=%s ✕=%s" % [str(one1), str(one2), str(closed_any and one3), str(one4)])
	ok = one1 and one2 and closed_any and one3 and one4 and ok

	# G4: dikey mod — set_vertical kompakt bayrağı + bar dar pencereye (380) sığar
	main.toggle_vertical()
	var compact_ok: bool = ui._compact and ui.VW() <= 400.0
	var bar_w: float = ui._bar.get_combined_minimum_size().x
	var bar_fits: bool = bar_w <= ui.VW() - 12.0
	main.toggle_vertical()   # yatay moda geri dön (diğer testler etkilenmesin)
	var back_ok: bool = not ui._compact and ui.VW() > 900.0
	print("UI dikey: kompakt=%s bar-genişlik=%.0f/%.0f sığar=%s geri=%s" % [str(compact_ok), bar_w, ui.VW(), str(bar_fits), str(back_ok)])
	ok = compact_ok and bar_fits and back_ok and ok

	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)

func _find_reply_button(card: Node) -> Button:
	for c in card.get_node("VB").get_children() if card.has_node("VB") else card.get_children():
		if c is Button:
			return c
		if c is VBoxContainer:
			for c2 in c.get_children():
				if c2 is Button:
					return c2
	return null
