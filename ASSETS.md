# ASSETS.md — Üçüncü parti varlık kaydı

Anayasa gereği ses %100 sentezdir; aşağıdaki CC0 ambient dosyaları KULLANICI ONAYIYLA
eklendi (playtest: "deniz/su sesleri kötü, free indirebilirsin"). Yeni dosya eklerken
bu tabloya kaynak + lisans + indirme tarihi yaz — kayıtsız varlık commit edilemez.

| Dosya | Kaynak | Yazar | Lisans | Not |
|---|---|---|---|---|
| `assets/ambient/rain.ogg` | [Rain (loopable) — OpenGameArt](https://opengameart.org/content/rain-loopable) | Ylmir | CC0 | Paketteki `3.ogg` (45sn seamless loop, 160kbps). İndirme: 2026-07-09 |
| `assets/ambient/stream.ogg` | [30 CC0 SFX loops — OpenGameArt](https://opengameart.org/content/30-cc0-sfx-loops) | rubberduck | CC0 | Paketteki `water_flowing.ogg` (1.9sn seamless loop; motor ±%25 gain drift'iyle loop hissi kırılır). İndirme: 2026-07-09 |
| `assets/music/01_chill_lofi.ogg` | [Chill Lofi Inspired — OpenGameArt](https://opengameart.org/content/chill-lofi-inspired) | omfgdude | CC0 | Saf CC0 (Yamaha synth). ~125sn. İndirme: 2026-07-10 |
| `assets/music/02_countryside.mp3` | [lofi Compilation — OpenGameArt](https://opengameart.org/content/lofi-compilation) | TAD | CC0 | ~92sn. Not: GarageBand telifsiz loop kütüphanesinden; yazar CC0 yayımlamış, atıf rica ediyor. |
| `assets/music/03_florist.mp3` | [lofi Compilation — OpenGameArt](https://opengameart.org/content/lofi-compilation) | TAD | CC0 | ~113sn. (aynı kaynak/lisans) |
| `assets/music/04_cup_of_tea.mp3` | [lofi Compilation — OpenGameArt](https://opengameart.org/content/lofi-compilation) | TAD | CC0 | ~169sn. (aynı kaynak/lisans) |
| `assets/music/05_cat_cafe.mp3` | [lofi Compilation — OpenGameArt](https://opengameart.org/content/lofi-compilation) | TAD | CC0 | ~133sn. (aynı kaynak/lisans) |

Müzik motoru: parçalar `assets/music/` altından ada göre sıralı çalınır, parça arası 20-40sn
sessiz nefes (loop hissi kırma), müzik çalarken sentez pad %30'a düşer (ducking). Ses panelinde
"🎵 müzik" slider'ı; kapalıyken sentez pad tek başına sürer (fallback korunur).
**Kredi önerisi:** kapanış/kredi ekranında "Müzik: omfgdude, TAD (CC0, OpenGameArt)" anılabilir.

CC0 = atıf zorunluluğu yok; yine de krediler panelinde anılabilir.
Diğer her şey (sprite'lar dahil) prosedürel/sentez — `tools/make_sprites.gd`, `scripts/audio_engine.gd`.
