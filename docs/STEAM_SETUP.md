# NEFES — Steam Kurulum Rehberi (kullanıcı adımları, Faz F/G)

Kod tarafı hazır: GodotSteam GDExtension `addons/godotsteam/` altında, `SteamBridge`
güvenli-yokluk köprüsü, 18 achievement kancası, `steam_appid.txt` (şimdilik 480 test ID).
Aşağıdakiler SENİN yapman gerekenler (hesap/para/panel işleri):

## 1. Steam Direct kaydı (~1 hafta)
- partner.steamgames.com → hesap aç → Steam Direct ücreti **$100** (ilk $1000 gelirde iade).
- Vergi (W-8BEN) + kimlik doğrulama formları. Onay birkaç gün sürer.

## 2. App oluştur → gerçek App ID
- Panelden yeni uygulama → App ID'yi al.
- Repoda İKİ yeri güncelle: `steam_appid.txt` (kökte) ve `scripts/steam_bridge.gd`
  içindeki `steamInitEx(480, ...)` → gerçek ID.

## 3. Steamworks panel ayarları
- **Achievements**: docs/ACHIEVEMENTS.md tablosunu birebir gir (API adı = kimlik sütunu).
- **Steam Cloud**: Auto-Cloud → `save.json`, `save.json.bak`, `settings.cfg`
  (root: `%APPDATA%/Godot/app_userdata/NEFES` Windows / `~/Library/Application Support/Godot/app_userdata/NEFES` macOS).
  Çakışma politikası: en yeni kazanır (Steam varsayılanı yeterli).
- **Depot**: Windows build = `build/NEFES_windows/` içeriği; macOS = NEFES.app zip.
- **Launch options**: Windows `NEFES.exe`; macOS `NEFES.app`.

## 4. Test
- Steam açıkken oyunu başlat → konsolda `[steam] bağlandı` görülmeli.
- Overlay (Shift+Tab) borderless always-on-top şeritte test et — sorun çıkarsa
  Ayarlar'daki çerçeveli pencere modunda tekrar dene (bilinen overlay atlatması).
- İlk odak seansını bitir → ACH_FIRST_SESSION düşmeli.

## 5. Steam Deck
- Öneri: "Playable" hedefleme (masaüstü şerit konsepti Deck'te ekran-altı yerine
  pencere olarak çalışır); launch sonrası değerlendir.

## 6. AI beyanı (Açık Karar #2)
- Mağaza asset'lerinde (capsule/trailer) AI üretimi kullanılırsa Steamworks'te
  zorunlu beyan. Oyun içi her şey prosedürel/CC0 — oyun içeriği için beyan GEREKMEZ.

## Bilinen sınırlar
- Kod imzasız (macOS Gatekeeper "tanımlanamayan geliştirici" uyarır; Steam üzerinden
  dağıtımda sorun değil). Windows SmartScreen için code signing = Açık Karar #4.
- steam_api dinamik kütüphaneleri addon içinde; export preset'leri addon'u pakete dahil eder.
