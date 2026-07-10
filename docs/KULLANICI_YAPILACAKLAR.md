# NEFES — SENİN Yapman Gerekenler (H turu kapanışı, 2026-07-11)

Kod/içerik tarafı bitti: oyun iki dilde eksiksiz, Windows+macOS build'leri üretiliyor,
demo modu hazır, Steam iskeleti kurulu, mağaza metni+screenshot'lar taslakta.
Kalanlar hesap/para/donanım/karar işleri — sadece sen yapabilirsin:

## Hemen (para/hesap)
1. **Steam Direct kaydı** — $100 + vergi/kimlik formları (docs/STEAM_SETUP.md adım 1).
2. **App ID** alınca: `steam_appid.txt` + `scripts/steam_bridge.gd` (480 → gerçek ID).
3. **Steamworks paneli**: achievements tablosu (docs/ACHIEVEMENTS.md), Cloud, depot
   (docs/STEAM_SETUP.md adım 3).

## Donanım testi (Windows makine)
4. `build/NEFES_windows/NEFES.exe`'yi gerçek Windows'ta aç: always-on-top, borderless
   şerit konumu, çoklu monitör, DPI, taskbar davranışı, perf (%CPU idle <5 hedef).
5. macOS'ta `build/NEFES_macos.zip` → NEFES.app (Gatekeeper "tanımlanamayan geliştirici"
   uyarır — sağ tık → Aç; Steam dağıtımında sorun olmaz).
6. Oyun içinde **V** ile dikey modu dene (headless doğrulanamıyor); Ayarlar'daki
   🪟 çerçeveli pencere ve 🔋 pil modunu dene.

## Karar (Açık Kararlar 1-6 + fiyat)
7. **Fiyat**: öneri $6.99 (store/STORE_PAGE.md analizi) — onayla/değiştir.
8. **İkon/capsule**: programatik taslaklar (icon.png, store/capsule_header_draft.png)
   yeterli mi, yoksa sanatçı/Retro Diffusion mı? (AI kullanılırsa Steam beyanı — Karar #2)
9. Repo public/private (Karar #1), Next Fest zamanlaması (Karar #3), code signing
   sertifikası (Karar #4, SmartScreen), pixel font seçimi (Türkçe glyph'li lisanslı).
10. TAD müzikleri CC0 ama GarageBand-türevi — kalsın mı, yalnız omfgdude mu? (ASSETS.md)

## Mağaza kurulumu (hesap açılınca)
11. Coming Soon sayfası: store/STORE_PAGE.md metinleri + store/screenshots/ kareleri.
12. Trailer (30-60sn): dev hız ×500 timelapse + odak seansı akışı — kayıt senin makinende.
13. Kapalı playtest (Steam Playtest, 10-20 kişi) → geri bildirim turu.

## Launch öncesi son kapı (birlikte yaparız)
14. 8 saat soak testi + temiz makinede kurulum + verify.sh all + Steam review gönderimi.
