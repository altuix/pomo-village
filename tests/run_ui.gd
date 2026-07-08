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
	"new_town", "quit_game", "set_window_scale", "toggle_vertical",
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
	var f2: bool = "bırak" in ui._focus_btn.text
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
