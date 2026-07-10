# NEFES — Steam Mağaza Sayfası Taslağı (H4)

> Durum: TASLAK. Kullanıcı onayı + gerçek App ID sonrası Steamworks'e girilecek.
> Kaynak analiz: Rusty's Retirement ($6.99, %97), Tiny Pasture ($4.99), Spirit City ($12.99),
> Chill Pulse ($4.99). Nişin tatlı noktası $5-8; NEFES'in imza özellikleri (mektup + melodi +
> gerçek-Pomodoro) üst banda yaklaşmayı haklı çıkarır.

## Fiyat önerisi
**$6.99** (launch %10 indirim → $6.29). TR fiyatı bölgesel öneriye bırak.
Gerekçe: Rusty's ile birebir aynı bant — "screen-buddy idle" alıcısının referans fiyatı.

## Tag önerisi (Steam)
Idler, Cozy, Pixel Graphics, Simulation, Relaxing, Ambient, City Builder, Life Sim,
2D, Cute, Singleplayer, Casual — (+ "Productivity" desteklenmiyorsa Utilities YOK; oyun kimliği önde)

## Kısa açıklama (EN, ≤300 karakter)
A tiny town lives at the bottom of your screen while you work. Residents write you real
letters, the clock tower plays a melody YOU compose, and every focus session makes the
town grow. No penalties, no FOMO — just a warm little world that breathes with you.

## Kısa açıklama (TR, ≤300 karakter)
Sen çalışırken ekranının altında minik bir kasaba yaşar. Sakinler sana gerçek mektuplar
yazar, saat kulesi SENİN bestelediğin melodiyi çalar, her odak seansı kasabayı büyütür.
Ceza yok, FOMO yok — seninle birlikte nefes alan sıcak bir dünya.

## Uzun açıklama (EN)
**NEFES is a miniature town that lives at the bottom of your screen — and grows because you do.**

Start a real Pomodoro session (25/5 or 50/10, real minutes) and the town builds faster.
Finish one, and something visible ALWAYS happens: a new building rises, a hut becomes a
stone house, or flowers bloom in the square.

**Your residents actually know you.** They write letters — about the fountain you built,
the baby born last night, the wedding in the square. You can reply. When an elder passes
(gently, into the stars), they leave you a farewell letter and a memory tree on the meadow.

**The clock tower plays YOUR melody.** Compose on a pentatonic grid where every note fits.
Write a good one and the town throws a concert.

**Watch a hamlet become a city.** Population milestones change the town sign: Hamlet →
Village → Town → City. Wells, bakeries, markets, tea houses, schools and windmills appear
as the town needs them. Seasons drift softly; snow settles on rooftops; a traveling
merchant might leave a gift.

**Strictly cozy, by constitution.** No penalties. No streak-shaming. No microtransactions.
Closing the game is fine — the town naps, then tells you what you missed.

- Deterministic daily seed: share your town code with a friend, they get the same town
- Fully hand-synthesized lo-fi soundscape + CC0 lo-fi tracks, every channel mixable
- Horizontal desktop strip or vertical side-panel mode
- English & Turkish

## Uzun açıklama (TR)
**NEFES, ekranının altında yaşayan minyatür bir kasaba — sen ürettikçe büyür.**

Gerçek dakikalı Pomodoro seansı başlat (25/5 ya da 50/10); kasaba daha hızlı büyüsün.
Seansı bitir; HER SEFERİNDE görünür bir şey olur: yeni bina yükselir, kulübe taş eve
dönüşür ya da meydanda çiçek açar.

**Sakinlerin seni gerçekten tanır.** Sana mektup yazarlar — yaptığın çeşme, dün gece doğan
bebek, meydandaki düğün hakkında. Yanıtlayabilirsin. Bir bilge (nazikçe, yıldızlara
karışarak) veda ettiğinde ardında bir veda mektubu ve çayırda bir anı ağacı bırakır.

**Saat kulesi SENİN melodini çalar.** Her notanın uyumlu olduğu pentatonik ızgarada beste
yap; güzel bir beste kasabada konsere dönüşür.

**Mezradan şehre.** Nüfus eşikleri kasaba tabelasını değiştirir: Mezra → Köy → Kasaba →
Şehir. Kuyular, fırınlar, pazarlar, çayevleri, okullar ve değirmenler kasaba ihtiyaç
duydukça belirir. Mevsimler yumuşakça süzülür; kar çatılara oturur; gezgin bir tüccar
meydana hediye bırakabilir.

**Anayasa gereği cozy.** Ceza yok. Seri utandırması yok. Mikro ödeme yok. Oyunu kapatmak
sorun değil — kasaba şekerleme yapar, dönünce neler kaçırdığını anlatır.

- Deterministik günlük tohum: kasaba kodunu arkadaşınla paylaş, aynı kasabayı kursun
- Tamamı elde sentezlenmiş lo-fi ses + CC0 lo-fi parçalar, her kanal ayrı mikserde
- Yatay masaüstü şeridi ya da dikey kenar-paneli modu
- İngilizce ve Türkçe

## Özellik listesi (mağaza yan sütunu)
- Real-minute Pomodoro that feeds a living town
- Residents who write you letters (and remember your replies)
- Compose the clock tower's melody — pentatonic, always in tune
- Hamlet→City progression with need-buildings and house upgrades
- Gift-only random events: weddings, merchants, star showers
- 100% cozy: no penalties, no FOMO, no MTX
- Deterministic shareable town seeds
- Horizontal strip & vertical side-panel modes

## Capsule kompozisyon yönergesi (sanatçıya / Retro Diffusion'a)
- Ana motif: ışıklı saat kulesi + 2-3 sıcak pencereli ev, alacakaranlık gradyanı
  (uygulama ikonuyla aynı dil — assets/icon_1024.png referans).
- Logotype: "NEFES" — yumuşak yuvarlak hatlı, krem (#e8dcc8) üstüne bal (#ffe6a8) vurgu;
  alt satır "your town breathes with you" (EN) / küçük punto.
- Boyutlar: header 460×215, small 231×87, main 616×353, vertical 374×448, library 600×900.
- Screenshot'lar store/screenshots/ altında (1920×720; oyun 960×360'ın 2×'i).

## Steam yapılandırma notları
- Kategori: Casual/Simulation; Steam Cloud AÇIK (save.json + save.json.bak + settings.cfg).
- Overlay: borderless always-on-top'ta test edilecek (Faz F).
- AI beyanı: mağaza asset'lerinde AI kullanılırsa zorunlu (Açık Karar #2).
