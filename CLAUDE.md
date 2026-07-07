# CLAUDE.md — NEFES (Godot 4.x masaüstü cozy idle)

## Kimlik (tek cümle — asla sapma)
"Ekranının altında, sen çalışırken uyanan minyatür bir kasaba; sakinler yaşar,
sana mektup yazar, kule senin melodini çalar." Rain City evreni, solo geliştirici + Claude.

## Dokümanlar (önce oku)
- `DEVIR_TESLIM.md` → v10-v15 tüm kurallar/formüller (yol ağı, hane, yaşam döngüsü,
  ışık bütçesi, odak, mektup, melodi). Kurallar buradan değiştirilmeden taşınır.
- `JUICE_YAPILACAKLAR.md` → sıralı görev listesi (A juice / B port / C pazar).
  Madde 0: Web export + otomatik ekran görüntüsü pipeline'ı kur.

## ANAYASA (ihlal edilemez)
1. DETERMİNİZM: tüm rastgelelik `h(x)` hash'inden (main.gd'deki). `randi()` YASAK.
   Aynı tohum = aynı kasaba. Günlük tohum: YYYYMMDD.
2. COZY İLKESİ: ceza yok, kayıp korkusu yok, zorunlu tıklama yok. Ölüm bile nazik
   (veda mektubu + anı ağacı). MTX/FOMO/streak-cezası ASLA eklenmez.
3. IŞIK BÜTÇESİ: `lightCurve = evening × (1 − sleep×0.55)`. 23:00-05:00 kasaba uyur.
   Yeni ışık kaynağı ekliyorsan bütçeden düşür (bloom `min(1, 14/ev_sayısı)`).
4. SANAT İNCİLİ: 12 renk kilitli palet (ink #2b1e2e → honey #ffe6a8; çatılar
   c25a4a/c99b46/7a9b6a/6a86a8/9a6a8c). Value hiyerarşisi: zemin koyu < bina orta
   < ışık açık. Doygun sarı SADECE ışıkta (%10 kuralı). Yeni asset bu palete uyar.
5. TEK CÜMLE NETLİĞİ: her yeni mekanik OPSİYONEL katmandır; çekirdek (izle→büyür→
   mektup) asla mekanik zorunluluğuyla kirletilmez.

## Teknik kurallar
- Godot 4.x, GDScript. Tab girinti, `snake_case`, tipli değişkenler (`var x: float`).
- Sahne yapısı: Main.tscn tek dünya node'u; UI ayrı CanvasLayer; ses AudioStreamPlayer
  havuzunda. Sim mantığı render'dan AYRI tutulur (sim fonksiyonları saf, test edilebilir).
- Süreler: 1 oyun günü = 30dk gerçek zaman (2400 tick sabiti korunur, tick süresi ayarlanır).
  Odak: Pomodoro 25/5, Derin 50/10 GERÇEK dakika (Timer node).
- Save: `user://save.json` — nüfus, evler, mektuplar, bond, melodi, seri, son-çıkış
  zamanı. Açılışta OFFLINE ÖZET kartı üret ("sen yokken: ...").
- Pencere: borderless, always_on_top, ekran-altı şerit; dikey mod ikinci kadraj.

## Çalışma döngüsü (her görevde)
1. `godot --headless --check-only` ile script doğrula (commit öncesi zorunlu).
2. Görsel iş: Web export al → Playwright ile aç, `.frame` screenshot →
   piksel denetimi (parlaklık gündüz~115/akşam~90/gece~70; sıcaklık R−B>0;
   value aralığı>60). Sayılar tutmadan "güzel oldu" deme.
3. Sim işi: hızlı-ileri testi (stepWorld×N) — 30 günde nüfus 20-90 bandında
   dalgalanmalı; çökme (=0) veya patlama (>150) = regresyon.
4. Her görev sonunda JUICE_YAPILACAKLAR.md'de maddeyi işaretle, öğrenilen
   kuralı DEVIR_TESLIM.md'ye ekle.
5. Küçük commit'ler; mesaj Türkçe: "juice: lamba kaskadı PointLight2D".

## Ses
- %100 sentez (telif yok): AudioStreamGenerator ya da numpy→ogg stem render.
- Kanallar (yağmur/dere/pad/cırcır) kullanıcı slider'lı; cırcır × evening.
- Olay sesleri ödüldür: odak arpeji, seri fanfarı, lamba tıkı, mektup hışırtısı,
  veda çift notası. Yeni özellik = yeni minik ses düşün.
- Kule melodisi: pentatonik (C-D-E-G-A-C) — kullanıcı ne yaparsa yapsın uyumlu.
  İyi beste kuralı (≥5 nota, ≥3 farklı, ≥3 hareket) → Meydan Konseri ödülü.

## Yasaklar
- randi/randf, telifli asset/müzik, karanlık desen (bildirim spam'i, suçluluk metni),
  çekirdeği zorunlu mekanikle boğmak, paleti genişletmek, ışık bütçesini delmek.
