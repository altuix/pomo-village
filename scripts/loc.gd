class_name Loc
extends RefCounted
## NEFES yerelleştirme çekirdeği (S3): Loc.t(anahtar) → aktif dilde metin.
## Kapsam-1: menü/bar/panel yüzeyi + isimler. Olay/mektup havuzları S3-devam (TR şimdilik).
## Dil Settings("lang")'de; ilk açılışta OS dilinden tahmin. Değişim ui.rebuild ile anında.

static var lang := "tr"

static func boot() -> void:
	var d := Settings.get_str("lang", "")
	if d == "":
		d = "tr" if OS.get_locale_language() == "tr" else "en"
	lang = d

static func set_lang(l: String) -> void:
	lang = "tr" if l == "tr" else "en"
	Settings.set_str("lang", lang)

static func t(k: String) -> String:
	var e: Dictionary = T.get(k, {})
	return e.get(lang, e.get("tr", k))

const T := {
	"identity": { "tr": "ekranının altında, sen çalışırken uyanan minyatür bir kasaba", "en": "a miniature town at the bottom of your screen, waking as you work" },
	"resume": { "tr": "▶  Devam Et", "en": "▶  Resume" },
	"new_town": { "tr": "🌱 Yeni Kasaba", "en": "🌱 New Town" },
	"credits": { "tr": "ℹ Krediler", "en": "ℹ Credits" },
	"quit": { "tr": "✕ Kaydet ve Çık", "en": "✕ Save & Quit" },
	"confirm_new": { "tr": "Emin misin? Mevcut kasaban güvenle yedeklenecek (save.json.bak) ve bugünün tohumuyla yepyeni bir kasaba uyanacak. Bir daha dokunursan başlıyoruz.", "en": "Are you sure? Your current town will be safely backed up (save.json.bak) and a brand-new town will wake with today's seed. Tap again to begin." },
	"credits_body": { "tr": "NEFES — Rain City evreni.\nGodot Engine ile yapıldı (MIT lisansı, © Godot Engine katkıcıları).\nTüm görseller prosedürel, tüm sesler %100 sentez.\nSolo geliştirici + Claude.", "en": "NEFES — the Rain City universe.\nMade with Godot Engine (MIT license, © Godot Engine contributors).\nAll visuals procedural, all audio 100% synthesized.\nSolo developer + Claude." },
	"settings": { "tr": "⚙  AYARLAR", "en": "⚙  SETTINGS" },
	"scale": { "tr": "pencere ölçeği", "en": "window scale" },
	"fit": { "tr": "⛶ sığdır", "en": "⛶ fit" },
	"vertical": { "tr": "↕ dikey/yatay", "en": "↕ vertical/horizontal" },
	"language": { "tr": "dil / language", "en": "language / dil" },
	"quick": { "tr": "açılışta menüyü atla, doğrudan kasabaya gel", "en": "skip this menu on launch, go straight to town" },
	"dev_speed": { "tr": "⏩ dev hız", "en": "⏩ dev speed" },
	"hint": { "tr": "Esc: menü/panel kapat · V: dikey · pencereyi boş alandan sürükle", "en": "Esc: menu/close panel · V: vertical · drag window from empty space" },
	"start": { "tr": "🎯 Başlat", "en": "🎯 Start" },
	"leave": { "tr": "bırak", "en": "stop" },
	"break_skip": { "tr": "☕ mola %02d:%02d · yeni seans", "en": "☕ break %02d:%02d · new session" },
	"work_fmt": { "tr": "🎯 %02d:%02d · bırak", "en": "🎯 %02d:%02d · stop" },
	"series": { "tr": "seri %d", "en": "streak %d" },
	"letters_btn": { "tr": "✉ Mektuplar %d", "en": "✉ Letters %d" },
	"letters_btn_s": { "tr": "✉ %d", "en": "✉ %d" },
	"town_menu": { "tr": "☰ Kasaba", "en": "☰ Town" },
	"snd_row": { "tr": "🔊 Ses atmosferi", "en": "🔊 Sound atmosphere" },
	"mel_row": { "tr": "🎼 Kule melodisi", "en": "🎼 Tower melody" },
	"alb_row": { "tr": "📖 Albüm", "en": "📖 Album" },
	"cam_row": { "tr": "📷 Kartpostal", "en": "📷 Postcard" },
	"p_sound": { "tr": "SES ATMOSFERİ  (tamamı sentez, telifsiz)", "en": "SOUND ATMOSPHERE  (fully synthesized)" },
	"p_melody": { "tr": "KULE MELODİN", "en": "YOUR TOWER MELODY" },
	"p_mail": { "tr": "MEKTUPLAR", "en": "LETTERS" },
	"p_stats": { "tr": "EMEĞİN", "en": "YOUR EFFORT" },
	"p_album": { "tr": "ALBÜM", "en": "ALBUM" },
	"p_town": { "tr": "KASABA", "en": "TOWN" },
	"reply": { "tr": "İçtenlikle yanıtla", "en": "Reply warmly" },
	"replied": { "tr": "✓ yanıtladın · bağ +1", "en": "✓ replied · bond +1" },
	"tt_focus": { "tr": "Odak seansı: sen çalışırken kasaba ×1.5 büyür", "en": "Focus session: your town grows ×1.5 while you work" },
	"tt_series": { "tr": "Bugünkü seri · emek istatistikleri", "en": "Today's streak · effort stats" },
	"tt_town": { "tr": "Ses · Melodi · Albüm · Kartpostal", "en": "Sound · Melody · Album · Postcard" },
	"tt_mute": { "tr": "Sesi sustur / aç", "en": "Mute / unmute" },
	"tt_mail": { "tr": "Sakinlerden gelen mektuplar", "en": "Letters from your residents" },
	"tt_close": { "tr": "Kapat (Esc)", "en": "Close (Esc)" },
	"date_fmt": { "tr": "%d. yıl · gün %d", "en": "year %d · day %d" },
	"tier0": { "tr": "Mezra", "en": "Hamlet" },
	"tier1": { "tr": "Köy", "en": "Village" },
	"tier2": { "tr": "Büyük Köy", "en": "Large Village" },
	"tier3": { "tr": "Kasaba", "en": "Town" },
	"tier4": { "tr": "Küçük Şehir", "en": "Small City" },
	"tier5": { "tr": "Şehir", "en": "City" },
	"season0": { "tr": "ilkbahar", "en": "spring" },
	"season1": { "tr": "yaz", "en": "summer" },
	"season2": { "tr": "sonbahar", "en": "autumn" },
	"season3": { "tr": "kış", "en": "winter" },
	"mode0": { "tr": "Pomodoro 25/5", "en": "Pomodoro 25/5" },
	"mode1": { "tr": "Derin 50/10", "en": "Deep Work 50/10" },
}
