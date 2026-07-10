# NEFES (pomo-village) — Steam'e Hazır Oyun Roadmap'i

> **GÜNCEL DURUM (H turu, 2026-07-11):** Bu dosyanın checkbox'ları 07-08'de donduruldu;
> fiilî durum DEVIR_TESLIM.md'dedir. Faz B+/0/C/D + Q + S + G + H turları TAMAM:
> i18n TR/EN eksiksiz, Windows/macOS/Demo build'leri üretiliyor (export_presets.cfg),
> uygulama ikonu var, GodotSteam iskeleti + 18 achievement hazır, mağaza metni +
> screenshot'lar store/ altında. Kalan işler kullanıcı-taraflı:
> docs/KULLANICI_YAPILACAKLAR.md. Kod-taraflı açık kalanlar: web senaryo rig'i (Faz 0,
> opsiyonel), native ışıklar (opsiyonel), şerit genişliği/UI metin ölçeği/test matrisi
> (Windows makinesi ister), pixel font (lisans seçimi kullanıcıda).


> Bu doküman repoya kural/yol haritası olarak eklenir. Kod yazılmadan önce ilgili faz maddesi
> buradan okunur; her faz kapanışında bu dosyadaki madde işaretlenir. Kaynaklar:
> DEVIR_TESLIM.md (mevcut durum), JUICE_YAPILACAKLAR.md (ertelenen işler),
> UnpaidAttention/fable5-methodology (geliştirme disiplini).

## Bağlam

NEFES, Godot 4.7 ile yazılmış bir "cozy idle masaüstü kasabası": ekranın altında borderless
şerit olarak yaşar, kullanıcı Pomodoro seansı çalıştıkça kasaba büyür, sakinler mektup yazar,
kule oyuncunun melodisini çalar. Doğrudan pazar karşılaştırması **Rusty's Retirement**
($6.99, aynı "ekran altı idle" türünün kanıtlanmış başarısı). NEFES'in farkı: gerçek Pomodoro
entegrasyonu + mektup/cevap duygusal çekirdeği + oyuncunun bestelediği kule melodisi.

Çekirdek oyun büyük ölçüde bitmiş durumda (Faz0 + A0–A7 + B1–B4 tamam): deterministik sim,
hane/yaşam döngüsü, ışık bütçesi, partiküller, gerçek 25/50 dk odak seansları + seri ödülleri,
dilek/mektup/bond, kule melodisi + paylaşım kodu, %100 sentez ses motoru, save + offline
"sen yokken" kartı, gündüz rutini, `verify.sh` doğrulama pipeline'ı.

Bu plan, oyunun Steam'de bitmiş ücretli oyun olarak çıkması için kalan işi fazlara böler.
Alınan kararlar: **Windows-first**, **EN+TR launch**, **fable5-methodology hafif adaptasyon**,
**ürün + pazarlama birlikte**.

---

## Kod Denetimi (2026-07-08) — bitmiş oyunda olması gerekip repoda OLMAYANLAR

Tüm `.gd` kaynak dosyaları satır satır incelendi (world.gd 866, town_view.gd 481, ui.gd 384,
main.gd 202, audio_engine.gd 145, save.gd, melody.gd, names.gd, rng.gd). Dokümanlar
"tamamlandı" dese de aşağıdakiler kodda eksik ya da hatalı. Bunlar Faz B+'ta toplanır ve
her şeyden önce yapılır.

### Gerçek buglar (kırık vaatler)

1. **Kule saat başı melodiyi ÇALMIYOR.** `world.chime_t` sadece görsel nabız + kuş ürkmesi
   tetikliyor; `main.gd`/`town_view.gd`'de chime → `audio.play_melody(world.melody)` bağlantısı
   yok. "Kule her saat başı senin melodini çalar" oyunun imza vaadi ve UI bunu yazıyor
   (ui.gd:300) ama gerçekleşmiyor.
2. **Kayıtlı melodi UI'a geri yüklenmiyor.** `world.melody` save'e yazılıyor ama `ui._melody`
   her açılışta default `[0,2,4,2,-1,3,1,0]` (ui.gd:33). Oyuncu ızgarayı açınca kendi
   bestesini değil default'u görür.
3. **`growth_mult` save sızıntısı.** Odak sırasında Esc/kapanış → `growth_mult: 1.5` save'e
   yazılır ve yüklemede geri gelir; seans aktif olmadığı halde ×1.5 kalıcı kalır.
   Yüklemede 1.0'a zorlanmalı (ya da seans durumu restore edilmeli).
4. **Vefat eden dilek sahibi → save crash riski.** `_pass_away` `wish`'i temizlemiyor;
   `wish.who` people listesinden silinmiş kişiyi işaret ederse `to_save`'deki
   `wish.who["_sid"]` erişimi patlar (kişiye `_sid` damgalanmamış olur).
5. **Kütüphane hiç İNŞA EDİLMİYOR.** `unlocked.kutuphane` true olur + mektup gelir ama
   dünyaya bina eklenmez (atölye `b.type="shop"` dönüşümüyle kuruluyor, kütüphanenin
   karşılığı yok). "Sözü verildi" mektubu sonsuza dek söz kalıyor.
6. **Mektup→kişi eşleşmesi isimle yapılıyor.** `Names.POOL` 20 isim ve döngüsel — aynı isimde
   birden çok sakin oluşur; `reply_letter` ilk eşleşen `p.name == l.from`'a atkı verir
   (yanlış kişiye gidebilir). Mektuba kalıcı kişi id'si gerek.
7. **Yürüyen sakin nehrin üstünden geçebiliyor.** `_step_mover` fallback adayları
   (`better`/`cand`) `river_set` kontrolü yapmıyor.

### Eksik çekirdek mantık (Pomodoro tarafı zayıf)

8. **Seans geri sayımı yok.** Odak sırasında UI sadece "Odaktasın…" yazıyor; kalan süre
   (24:59 → 00:00) gösterilmiyor. Bir Pomodoro uygulamasının özü sayaçtır.
9. **Mola hiç yok.** Mod "Pomodoro 25/**5**" ama 5 dk mola timer'ı, mola bildirimi, mola
   sonu "devam?" akışı kodda yok; work_min bitince direkt ödül.
10. **Seans iptali yok.** Başlat'a basınca buton disabled; HTML'deki "erken bırakma cezasız"
    (cozy ilkesi) Godot'ta kayboldu. İptal butonu + cezasızlık geri gelmeli.
11. **Seans kalıcılığı yok.** Uygulama seans ortasında kapanır/çökerse seans sessizce yanar.
    En az: kapanışta aktif seansın bitiş zamanını save'e yaz, açılışta değerlendir.
12. **Streak asla sıfırlanmıyor ve tanımı yok.** Sadece artıyor; "art arda" kavramı
    (aynı gün? aralıksız?) kodda tanımsız. 5'ten sonra da yeni seri ödülü yok.
13. **İstatistik ekranı yok.** `sessions` sayılıyor ama toplam odak dakikası, bugün/bu hafta
    özeti, en uzun seri hiçbir yerde gösterilmiyor — üretkenlik uygulamasının temel beklentisi.
14. **Sakinlere dokunulamıyor.** İsimli sakinler retention özelliği ama ekranda kim kim belli
    değil: hover/tıklama ile isim+evre+bond kartı yok. Mektubun duygusal değeri, göndereni
    kasabada bulamayınca düşüyor.

### Görsel / asset eksikleri (repoda SIFIR asset var)

15. **Hiç görsel asset yok** — her şey `_draw()` rect/circle. Sakinler 3px daire, binalar
    dikdörtgen+üçgen. Bu "prosedürel minimal" bilinçli stil olarak cilalanabilir AMA Steam
    screenshot'ında prototip gibi okunma riski yüksek. **Karar gerekli** (Açık Kararlar #5):
    önerim hibrit — zemin/ışık prosedürel kalır (zaten güzel), sakinler + landmark binalar
    (kule/atölye/kütüphane) sprite olur. Duygusal çekirdek sakinlerde; 3px daire mektup
    yazan bir karakteri taşıyamıyor. `dev-pipeline` dosyası zaten bu iş için yazılmış
    (Retro Diffusion, palet kilidi) ama hiç kullanılmamış.
16. **Font yok.** UI Godot default fontuyla çiziliyor; Türkçe glyph'li, lisansı temiz bir
    pixel font şart (EN+TR launch için iki dilin de glyph seti).
17. **UI ikonları emoji** (🎯🔊🎼✉💭🗼). OS emoji fontuna bağımlı: Windows'ta farklı görünür,
    bazı sistemlerde tofu (☐) çıkar. Gerçek ikon sprite'larıyla değiştirilmeli.
18. **Uygulama ikonu yok** (proje ikonu, exe ikonu, pencere ikonu, Steam kütüphane ikonu).
19. **Yağmur görseli yok.** Ses motorunda yağmur kanalı var ama görsel yağmur/hava durumu
    sistemi yok (kar var). Ambians slider'ı açan kullanıcı görsel karşılık bekler —
    hafif hava durumu sistemi (yağmur çizgileri + ıslak zemin tonu) Faz D'ye.
20. **Atölye görsel olarak sıradan dükkân.** Seri ödülü binası `type="shop"`a dönüşüyor —
    özel bina hissi yok; kütüphaneyle birlikte ayırt edilebilir landmark görseli gerek.

### Sistem eksikleri (bitmiş oyun standardı)

21. **Ayarlar kalıcı değil.** Ses slider değerleri save edilmiyor — her açılışta amblans 0'a
    döner (üstelik default 0: ilk açılışta oyun sessiz, keşfedilebilirlik düşük).
    `user://settings.cfg` (ConfigFile) + makul default'lar gerek.
22. **Atomic save yok.** `FileAccess.WRITE` doğrudan truncate ediyor; yazım ortasında
    crash/elektrik kesintisi = save tamamen gider. tmp dosyaya yaz + rename + `.bak` tut.
23. ~~Multi-instance koruması yok~~ ✔ (nefes.lock + canlılık damgası; bayat kilit devralınır).
24. ~~Input map yok~~ ✔ (nefes_menu/nefes_vertical aksiyonları).
25. ~~Sürüm numarası yok~~ ✔ (0.4.0 + save 'app' damgası + v>1 migrasyon iskeleti + şema kontrolü).
26. ~~Offline cap 4 saat~~ ✔ (28800 tick = 6 saat/12 oyun günü; boot senkron ~2.6s M4 ölçümü).
27. **Mektup listesi sınırsız büyüyor.** `letters` hiç kırpılmıyor — uzun save'lerde şişer;
    albüm/arşiv tasarımıyla birlikte çözülür (aktif kutu + arşiv).
28. **Sistem tepsisi entegrasyonu yok.** Always-on companion için tepsiye küçültme /
    tepsiden geri getirme beklenen davranış (Godot'ta StatusIndicator, 4.3+).
29. **End-game tanımsız ve test edilmiyor.** `goal *= 1.18` üstel büyüyor — birkaç düzine
    inşaattan sonra hedef astronomikleşir, inşaat fiilen durur; `frontier` `GW-6`'ya dayanınca
    `_start_construction` sessiz no-op olur ve growth boşa akar. "Kasaba doldu" anının ne
    görseli ne mektubu ne kutlaması var; mevcut sim testi 30 günde kesiyor, 100+ günün
    davranışını kimse görmedi. Uzun oyunda kasaba sessizce plato yapar ve oyuncu bunun
    bir son mu bug mı olduğunu bilemez.

---

## Faz B+ — Çekirdek tamir: buglar + kırık vaatler — ~1-2 hafta (HER ŞEYDEN ÖNCE)

Denetimdeki maddelerin kritik kısmı. Sıra: önce buglar, sonra Pomodoro çekirdeği.

- [x] Bug 1: saat başı kule melodisi gerçekten çalsın (`chime` → `audio.play_melody(world.melody)`,
      yalnız `melody_saved` ise; gece 23-05 uykuda kule de sussun — ışık bütçesi ruhu).
- [x] Bug 2: `ui._melody` açılışta `world.melody`'den yüklensin.
- [x] Bug 3: yüklemede `growth_mult = 1.0` zorla (seans restore edilene kadar).
- [x] Bug 4: `_pass_away` dilek sahibini temizlesin (`wish.who == p` ise `wish = null`).
- [x] Bug 5: kütüphane binası gerçekten kurulsun (`type="library"` inşaatı; ayırt edici görsel Faz C sanat).
- [x] Bug 6: mektuplara kalıcı kişi id'si (`person.seed`) — isimle eşleşme kalktı.
- [x] Bug 7: `_step_mover` nehir hücrelerini adaylardan elesin.
- [x] Pomodoro çekirdeği: geri sayım göstergesi + mola akışı (25/5, 50/10) + cezasız iptal
      butonu + seans kalıcılığı (kapanışta bitiş zamanı save'e; yokken biten seansın ödülü açılışta verilir).
- [x] Streak tanımı netleşti (aynı gün içinde art arda; gün değişince nazikçe sıfır,
      kazanılanlar kalır — cozy) + istatistik paneli "EMEĞİN" (bugün/toplam odak dk, en uzun seri, seans).
- [x] Sakin etkileşimi: hover → isim + evre + atkı/yuva-arıyor mini kartı + ince vurgu halkası.
- [x] Atomic save (tmp+rename) + `save.json.bak` + bozukta yedekten dönüş + settings kalıcılığı
      (`user://settings.cfg`).
- [x] Ambient ses default'ları: ilk açılışta hafif pad (0.25) + dere (0.20) + cırcır (0.20) açık.

## Faz 0 — Geliştirme altyapısı (fable5 hafif adaptasyonu) — ~2-3 gün

Amaç: sonraki tüm fazlar Claude Code ile hızlı ve güvenli ilerlesin. fable5-methodology'nin
4 zorlama katmanından (hook / agent / context / eval) NEFES'te context katmanı (CLAUDE.md
anayasası) ve hook'un yarısı (`verify.sh`) zaten var; eksikler burada tamamlanır.

- [x] **Pre-commit / delivery gate hook'u**: `tools/hooks/pre-commit` (check+sim; yalnız-doküman
      commit'lerinde atlanır). Kurulum: `git config core.hooksPath tools/hooks`. Visual/endgame
      faz kapanışlarında elle (her commit'e GPU penceresi açtırmak pratik değil).
- [ ] **qa-verifier alışkanlığı**: her faz kapanışında, implementasyonu görmemiş bağımsız bir
      subagent'a "bu fazın kabul kriterlerini `verify.sh` + `tests/run_features.gd` çıktısıyla
      kanıtla" görevi verilir. fable5 `agents/qa-verifier.md` sözleşmesi örnek alınır,
      tam kurulum yapılmaz.
- [x] **Eval kuralı**: her yeni sistemle birlikte `tests/run_features.gd`'ye kabul testi ekleme
      zorunluluğu CLAUDE.md "Çalışma Döngüsü" bölümüne yazıldı (+ endgame kuralı).
- [ ] **Görev brifing şablonu**: fable5 `TASK_BRIEFING_TEMPLATE.md`'den sadeleştirilmiş tek
      şablon; her Claude oturumu faz maddesini bu şablonla alır.
- [x] **End-game testi** (`verify.sh endgame`, denetim #29): headless, hızlandırılmış
      365 oyun-günü koşusu (`step_world × 876000`, sim saf olduğu için dakikalar içinde
      biter). Assert edilenler:
      - Çökme/patlama yok: pop bandı uzun vadede de korunur (çökme=0, patlama>150 FAIL).
      - `letters` / `mem_trees` / `parts` sınırlı kalır (bellek şişmesi FAIL).
      - 365. günde save→load→save roundtrip byte-eşit (uzun save'de int/float bozulması FAIL).
      - `step_world` süresi düz kalır (ör. gün 1 ortalamasının 3 katını aşarsa FAIL —
        nüfusla O(n²) büyüyen bir döngü sızmış demektir).
      - Kasaba dolduktan sonra growth'un akıbeti loglanır — sessiz no-op görünür kılınır
        (end-game tasarımı Faz D'de çözülür, test burada sadece ölçer).
- [x] **Timelapse görsel testi** (`verify.sh timelapse`): şehrin büyüdüğünü GÖZLE
      doğrulamak için. Mevcut `tools/capture.gd` zaten `capture_setup(seed, tod, steps)`
      alıyor — sarmalayıcı script sabit tohum + sabit saat (ör. 19:00) ile gün
      0/3/7/14/30/60/120/365'te frame yakalar, `.verify_out/timelapse/` altına yazar ve
      tek bir contact-sheet PNG (+ opsiyonel GIF, ImageMagick `montage`/`convert`) üretir.
      Kabul: kareler arasında ev sayısı monoton artar (pixelcheck'e ev-sayısı metriği
      eklenir ya da `world.lit_count()` capture çıktısına yazılır); görsel olarak büyüme
      hikâyesi tek bakışta okunur. Bu çıktı aynı zamanda Faz G'nin pazarlama malzemesidir
      (büyüme timelapse'i en güçlü GIF).
- [ ] **Web tabanlı senaryo rig'i — Claude'un gözü** (denetim tamamlayıcısı; CLAUDE.md'deki
      eski "web export + Playwright" fikrinin geri gelişi, bu kez Chrome DevTools MCP ile):
      oyun tarayıcıda koşar, Claude kendisi sürer, her senaryonun ekran görüntüsünü alıp
      TEK TEK gözle inceler. Desktop `capture.gd` pipeline'ı sayısal metriklerin kanonik
      yolu olarak KALIR; web rig'i onun ölçemediklerini kapatır: UI etkileşimi (panel
      açma, buton tıklama, mektup yanıtlama), senaryo çeşitlemesi ve "göze güzel mi"
      yargısı.
      - **Export**: Godot web export template kurulur; `tools/web_build.sh` →
        `.verify_out/web/`. Bilinen tuzak: Godot 4 web build'i SharedArrayBuffer ister —
        yerel sunucu COOP/COEP header'ları göndermeli (basit `python http.server` yetmez;
        header ekleyen 10 satırlık sarmalayıcı yazılır).
      - **Test kancaları**: `JavaScriptBridge` ile `window.nefes` API'si expose edilir —
        `setup(seed, tod, steps)` (mevcut `capture_setup` sözleşmesinin webe uzantısı),
        `advance_days(n)` (ör. +100 gün ileri sar), `set_time(tod)`, `trigger(case)`
        (odak bitişi ödülü, dilek, veda, konser, offline kartı zorla göster),
        `state()` (ev/sakin/mektup sayıları JSON döner — screenshot'la çapraz kontrol).
        Kancalar yalnız debug build'de derlenir (`OS.is_debug_build()` guard'ı) —
        release'e sızmaz.
      - **Senaryo matrisi** (`tools/scenarios.json`, genişleyebilir): taze kasaba gün 0 /
        +7 / +100 / +365 × {gündüz, alacakaranlık lamba kaskadı, gece, gece yarısı uyku} ×
        4 mevsim; ayrıca UI durumları: mektup paneli açık, melodi ızgarası açık, ses
        mikseri açık, dilek çipi görünür, offline kartı, inşaat anı, konser anı, dikey mod.
      - **Akış**: Claude Chrome DevTools MCP ile sayfayı açar → her senaryo için
        `window.nefes` kancalarını `evaluate_script` ile çağırır → `take_screenshot` →
        `.verify_out/scenarios/<isim>.png`. Koşu sonunda Claude görüntüleri tek tek açıp
        inceler (palet/ışık bütçesi/kompozisyon + UI kırığı) ve bulgularını raporlar;
        şüpheli kare = ilgili faz maddesine geri bildirim.
      - **Kabul**: `verify.sh web-scenarios` matristeki her kareyi üretir; eksik kare FAIL.
        UI'a ya da render'a dokunan her işte bu koşu zorunludur (Doğrulama kuralları'na
        eklendi). Determinizm sayesinde aynı tohum = aynı kare — görsel regresyon,
        önceki koşunun PNG'siyle piksel-diff alınarak da yakalanabilir (fark eşiği aşılırsa
        Claude iki kareyi yan yana inceler).

Tam plugin kurulumu YAPILMAZ (token vergisi; fable5'in kendi README'si bile faydanın
ölçülmemiş olduğunu söylüyor).

## Faz C — Ürünü tamamla: ertelenen özellikler — ~2-3 hafta

JUICE_YAPILACAKLAR.md'deki ⏳ maddeler, öncelik sırasıyla:

- [x] **Albüm (madde 17)** — 📖 panel: sakin koleksiyonu (evre+atkı), anı ağaçları,
      hikâye sayaçları + rozetler (stat_wishes sayacı eklendi). Koleksiyon-tamamlama
      ödülü achievement'larla (Faz F) bağlanacak.
- [x] **Tek sakin menü / UI sadeleştirme (18)** — bar 9→5 öğe; Ses/Melodi/Albüm/Kartpostal
      ☰ Kasaba altında. Settings girişi Faz E'de bu menüye eklenecek.
- [x] **UI juice (8)** — zarf salınımı (yanıtsız mektupta), olay satırı soldan kayma,
      tüm butonlarda bal-tonu hover ısınması.
- [x] **Kartpostal modu (20)** — 📷: UI'sız kare + ink çerçeve + tohum/gün/saat dosya adı →
      Resimler klasörü; deklanşör sesi. Tohum paylaşımı = arkadaş aynı kasabayı kurar.
- [x] **Gerçek dikey mod (19)** — 380×700; kamera kasaba çekirdeğini genişliğe sığdırır,
      üstte ~285px bant + altta panel alanı; sıkışık bar; kamera pulse zoom-tabanlı.
- [x] **Ana menü / başlangıç ekranı** — canlı sim arka planlı perde; Devam/Yeni Kasaba
      (iki aşamalı nazik onay + .bak yedeği)/Krediler (Godot MIT)/Kaydet-Çık; hızlı-başlat
      toggle; Esc reworku (menü aç/kapa); fade. Orijinal kapsam notları:
      - Title screen: oyun adı + animasyonlu arka plan (dev-pipeline B akışı: konsept kare →
        image-to-video → `.ogv` loop, `VideoStreamPlayer`). Alternatif ucuz yol: canlı sim'in
        kendisi arka plan olur (kasabanın gece görünümü) — AI beyanı derdi de olmaz.
      - Menü öğeleri: Devam Et (save varsa) / Yeni Kasaba / Ayarlar / Albüm / Krediler / Çıkış.
      - "Yeni Kasaba" onayı nazik olmalı (mevcut kasaba silinmeden önce net uyarı + yedek —
        cozy ilkesi: yanlışlıkla kayıp yok).
      - Menüden şeride yumuşak geçiş (fade); sonraki açılışlarda menü atlanıp doğrudan
        şeride açılma seçeneği ("hızlı başlat" toggle — companion app kimliği korunur).
      - **Esc davranışı reworku**: şu an Esc = kaydet+çık (B3). Yeni akış: Esc → oyun-içi
        menü (Devam / Ayarlar / Ana Menü / Kaydet ve Çık). Tek sakin menü (18) ile birleşir.
      - Krediler: Godot lisans bildirimi (MIT notice zorunlu) + kullanılan araçlar burada.
- [ ] **Sanat yönü yükseltmesi** (denetim #15-20; Açık Karar #5 verildikten sonra):
      - Türkçe glyph'li, lisansı temiz pixel font seçimi + tüm UI'a uygulanması.
      - Emoji ikonların (🎯🔊🎼✉💭) palet-uyumlu ikon sprite'larıyla değiştirilmesi.
      - Uygulama ikonu (proje + exe + pencere + Steam kütüphane boyutları).
      - Önerilen hibrit: zemin/ışık prosedürel kalır; sakinler (evre başına 2-3 kare:
        çocuk/yetişkin/bilge + yürüme), saat kulesi, atölye ve kütüphane sprite olur.
        Üretim akışı `dev-pipeline` dosyasında hazır (Retro Diffusion + 12-renk palet
        kilidi/quantize). AI kullanılırsa Steam AI beyanı gerekir (Faz F).
- [ ] **Native PointLight2D + WorldEnvironment glow** — opsiyonel; `_draw` juice metrikleri
      zaten geçiyor. Perf bütçesine (Faz E) sığıyorsa yapılır, yoksa iptal.

Her madde: `verify.sh all` yeşil + `run_features.gd` kabul testi + DEVIR_TESLIM.md güncellemesi.

## Faz D — İçerik derinliği — ~3-4 hafta

Idle/cozy oyunlarda negatif Steam yorumunun 1 numaralı sebebi içerik sığlığı ("1 haftada
bitti"). Mevcut içerik ~1-2 haftalık yenilik sunuyor; hedef 4-6 hafta.

- [x] **Mektup havuzu genişletmesi** — letters.gd ~70 şablon (veda 12+3 atkılı, odak 12,
      dilek 3×5, taşınma 8, doğum 8, an 4, bond-eki 4); parametrik format (i18n hazır);
      bağlam: atkı sahibine kişisel veda, bond≥5'te sıcak not. Determinist seçim.
      (100+ hedefine Faz D devamında festival/mevsim mektuplarıyla ulaşılır.)
- [x] **Mevsimsel olaylar** — 4 festival (Çiçek Günü/Dere Şenliği/Hasat Akşamı/Fener Gecesi):
      meydan toplanması + mevsim serpintisi + festival sesi + %15 mektup. Kule mevsim
      şarkıları ileride (konser genişlemesi).
- [x] **Milestone zinciri** — rasathane(10)/sera(20)/hamam(35 toplam seans); ayırt edici
      görseller (kubbe+teleskop, camsı cephe, ikiz kubbe+buhar) + kütüphane kitap sırtları.
- [x] **Dilek çeşitliliği** — +4 obje (bank/kuş yuvası/posta kutusu/rüzgâr gülü), her birine
      4 teşekkür mektubu; decor listesi save'de.
- [x] **Kasaba yıldönümü / uzun-vade anları** — 30. gün, 100. komşu, 50. anı ağacı:
      tek seferlik kutlama mektubu + olay (milestones save'de).
- [x] **Hafif hava durumu** (denetim #19) — world.rain_amount() saf türetim (~%28 gün,
      3-6 saat, rampa; kışın kapalı); yağmur çizgileri + ıslak zemin + kurşuni gök (sıcaklık
      korunur); rain ses kanalı yağmurda hafif kendiliğinden; geçiş olayları.
- [x] **Seri ödül zinciri uzatması** (denetim #12) — milestone zinciriyle çözüldü
      (toplam seans eşikleri; _convert_unbuilt ortak yolu + çakışma/sahiplenme düzeltmesi).
- [x] **End-game tasarımı** (denetim #29) — "Kasaba bütünlendi" tek seferlik kutlama +
      mektup; PLATO TAŞMA kanalı: goal şişince biriken emek sabit maliyetle (~3 günde bir)
      evleri çiçeklendirir (goal eğrisi DEĞİŞMEDİ: ×1.10 denemesi nüfusu 94-104'e taşıyıp
      20-90 bandını kırdı — bant korunarak çözüldü). 365-gün: goal 7.631 dengede, bant 27-65.

Anayasa korunur: hepsi opsiyonel katman, çekirdek (izle→büyür→mektup) zorunlu mekanikle
kirletilmez.

## Faz E — i18n (EN+TR) + platform sağlamlaştırma — ~3-4 hafta

### i18n

- [ ] **Anahtar-tabanlı metin sistemi**: tüm UI/olay/mektup metinleri koddan
      `tr.json`/`en.json`'a çıkar (Godot `TranslationServer` akışı). Mektup şablonları
      parametrik (`{name}`, `{building}`) — Faz D'deki havuz baştan bu formatta yazılır
      (Faz D ile paralel yürütülebilir).
- [ ] **İsim havuzu kararı**: Türkçe sakin isimleri marka kimliği olarak korunur (EN oyuncuya
      sıcak/özgün gelir, Anadolu-cozy nişi). Geri bildirim gelirse EN havuzu toggle olarak
      eklenir — şimdilik iş yok.
- [ ] Dil seçimi settings'e; ilk açılışta OS locale'den tahmin.

### Ekran uyumluluğu ve ölçekleme

Şu an şerit sabit boyutlu ve yüksek çözünürlüklü ekranlarda çok küçük kalıyor. Bu bölüm
Steam yorumlarında "ekranımda minicik görünüyor" şikayetini baştan öldürmek için:

- [ ] **Ölçek ayarı (en kritik)**: pixel-art tabanı sabit kalır, pencere tamsayı katlarıyla
      büyür (1×/2×/3×/4× preset + Ayarlar'da slider). Godot tarafı: viewport sabit çözünürlük +
      `canvas_items` stretch + integer scaling — pixel art bulanıklaşmadan büyür.
- [ ] **İlk açılışta otomatik ölçek tahmini**: ekran çözünürlüğü + OS DPI faktöründen
      mantıklı başlangıç katı seç (1080p→1×/2×, 1440p→2×, 4K→3×; kullanıcı sonra değiştirir).
- [ ] **Şerit genişliği seçeneği**: tam ekran genişliği / %75 / %50 (Rusty's Retirement
      modeli) — ultrawide (21:9, 32:9) ekranda tam genişlik saçma kalabilir, kısmi genişlik +
      sol/orta/sağ hizalama seçeneği.
- [ ] **Görünür dünya genişliği ölçekten bağımsız**: pencere büyüyünce kasaba "yakınlaşmış"
      görünmeli (aynı içerik daha büyük piksellerle), dar pencerede kamera kaydırma/kadraj
      zaten var olan mikro-zoom + kadraj sistemine bağlanır. Sim grid'i DEĞİŞMEZ
      (determinizm anayasası — çözünürlük sim'e asla sızmaz).
- [ ] **Normal pencere modu**: borderless şerit istemeyen kullanıcı için sıradan,
      yeniden boyutlandırılabilir pencere seçeneği (title bar + resize). Bazı kullanıcılar
      oyunu ikinci monitörde tam pencere olarak yaşatmak istiyor.
- [ ] **Konum/boyut hafızası**: pencere konumu, monitör seçimi, ölçek ve mod save'e yazılır;
      monitör kaybolursa (laptop dock çıkarma) güvenli konuma düş.
- [ ] **UI metin ölçeği**: mektup paneli / HUD fontları pencere ölçeğiyle birlikte büyür;
      4K'da okunmayan minik font kalmaz. Erişilebilirlik: +1 kademe "büyük yazı" seçeneği.
- [ ] **Test matrisi**: 1366×768 (düşük uç laptop), 1920×1080, 2560×1440, 3840×2160 (4K,
      %150-200 Windows scaling), 3440×1440 (ultrawide) — her birinde şerit + dikey + normal
      pencere modu ekran görüntüsüyle doğrulanır. `tools/capture.gd` matrisi otomatize edebilir.

### Windows-first sağlamlaştırma

- [ ] **Windows test ortamı** (GPU gerektiği için gerçek makine tercih): `always_on_top` +
      borderless + ekran-altı konumlandırma + çoklu monitör + DPI scaling + taskbar
      etkileşimi Windows'ta doğrulanır. Bu katman OS'e en bağımlı kısım ve şu ana kadar
      sadece macOS'ta test edildi.
- [~] **Performans bütçesi** — İLK GEÇİŞ TAMAM: FPS cap 30, statik bg katmanı (redraw yalnız
      imza değişince), bina sort önbelleği, ses sessizlik atlaması, `verify.sh perf` (%CPU
      örnekleme; ilk ölçüm %27.2/487MB dev-mac). KALAN (Faz E): Windows release hedefi
      idle <%3-5 / RAM <200MB, 8 saat soak, pil dostu mod, dinamik katman optimizasyonu.
- [ ] **Settings menüsü**: ses slider'ları (var) + dil + FPS/güç modu + şerit konumu/monitör
      seçimi + başlangıçta otomatik başlat (opsiyonel).
- [ ] **İlk açılış onboarding'i**: 3-4 adımlık nazik tanıtım (kasaba → odak seansı →
      mektuplar). Zorunlu tıklama yok (cozy ilkesi), atlanabilir.
- [ ] **Sağlamlık**: bozuk save'de default'a düşüş + nazik mesaj (atomic save + `.bak`
      Faz B+'ta geldi); saat değişikliği / uyku-uyanma offline hesabı edge case'leri;
      multi-instance koruması (denetim #23); offline cap'in gün-bazlı özete çevrilmesi +
      boot'ta senkron ileri-sarma süresinin ölçülmesi (denetim #26); mektup arşivi ile
      `letters` büyümesinin sınırlanması (denetim #27, albümle birlikte).
- [ ] **Sistem tepsisi** (denetim #28): tepsiye küçültme / geri getirme (Godot
      `StatusIndicator`); kapat düğmesi davranışı ayarı (tepsiye küçült / tamamen çık).
- [ ] **Input map**: hardcoded Esc/V keycode'ları Godot InputMap aksiyonlarına taşınır
      (denetim #24).
- [ ] **Windows export preset**: ikon, sürüm bilgisi (`application/config/version` +
      save migrasyon iskeleti, denetim #25), exe adı. Code signing opsiyonel
      (yoksa SmartScreen uyarısı — bilinen risk, launch sonrası EV sertifika değerlendirilir).

## Faz F — Steamworks entegrasyonu — ~2 hafta

- [ ] **Steam Direct kaydı**: $100 app ücreti + vergi/kimlik formları (süreç 1-2 hafta
      sürebilir — Faz E ile paralel başlat).
- [ ] **GodotSteam GDExtension** entegrasyonu (Godot 4.7 uyumlu sürüm).
- [ ] **Achievements (~15-20)** — mevcut milestone'lara haritalanır: ilk mektup, ilk cevap,
      ilk veda, atölye, kütüphane, meydan konseri, 10 seri, 100. sakin, albüm koleksiyonları,
      4 mevsimi görmek... Cozy ilkesiyle uyumlu (hepsi pozitif an, grind achievement yok).
- [ ] **Steam Cloud**: `user://save.json` + yedeği cloud'a. Çakışma çözümü: en yeni
      `last_exit` kazanır.
- [ ] **Overlay uyumu**: borderless always-on-top pencerede Steam overlay test edilir
      (sorunluysa overlay'siz de oyun tam çalışır — online zorunluluğu yok).
- [ ] **Steam Deck**: hedef değil; "Playable/Unsupported" olarak dürüstçe işaretlenir
      (masaüstü şerit konsepti Deck'te anlamsız).
- [ ] **AI içerik beyanı**: dev-pipeline AI sprite/video üretimi planlıyor (Retro Diffusion,
      Higgsfield vb.) → Steam'in zorunlu AI disclosure formu doldurulur. Alternatif: launch
      görsellerinde AI kullanmayıp beyandan kaçınmak — karar asset üretimi başlarken verilir.
- [ ] **Repo görünürlüğü kararı**: repo şu an public + Apache 2.0. Ticari oyun için ya
      private'a çek ya da bilinçli "open-source ticari oyun" konumlaması yap
      (ikisi de geçerli — launch öncesi karar).

## Faz G — Mağaza sayfası + pazarlama rampası — Faz C sonrası sürekli akar

- [ ] **Coming Soon sayfası mümkün olan en erken anda** (kartpostal modu asset üretebilir
      olduğunda). Wishlist birikimi launch görünürlüğünün ana girdisi; hedef: launch'ta
      5-7k wishlist (Popular Upcoming eşiği).
- [ ] **Mağaza assetleri**: capsule seti (header 460×215, main 616×353, vertical 374×448,
      small 231×87, library 600×900 + hero), 5+ screenshot (gündüz / alacakaranlık lamba
      kaskadı / gece / mektup paneli / melodi ızgarası), 30-60 sn trailer (5 sn hook —
      "kasaba senin çalışmanla büyüyor" → özellik kesitleri → isim/tarih).
- [ ] **Metin**: kısa açıklama tek cümle kimlikten türetilir ("A tiny town that wakes up
      while you work..."); tag'ler: Idle, Cozy, Relaxing, Pixel Graphics, Life Sim, Ambient.
      EN + TR mağaza metni.
- [ ] **GIF-first tanıtım döngüsü**: haftada 1-2 GIF (lamba kaskadı, inşaat zıplaması,
      veda yıldızı, mektup açılışı) → X/Bluesky, r/CozyGamers, r/godot, TikTok
      "study with me" nişi. Türkçe cozy/üretkenlik topluluğu ayrı kanal olarak beslenir.
- [ ] **Fiyat**: $5.99-7.99 bandı (Rusty's Retirement $6.99 emsal), %10-15 launch indirimi.

## Faz H — Demo + Next Fest + playtest — ~2-3 hafta

- [ ] **Demo build**: tam oyun, kısıtlı ilerleme (ör. 7 oyun-günü + 1 milestone; save
      launch'ta tam oyuna taşınır). Demo bitince suçluluk metni yok, nazik davet var (cozy).
- [ ] **Steam Next Fest**: bir kez katılım hakkı stratejik kullanılır — demo cilalı +
      wishlist ivmesi varken (launch'tan 1-2 ay önce ideal).
- [ ] **Kapalı playtest** (Steam Playtest özelliği): 10-20 gerçek kullanıcı, 1-2 hafta
      gerçek çalışma rutininde kullanır. Ölçülen: 7 gün retention, offline kart doğruluğu,
      Windows pencere davranışı çeşitli setup'larda, perf şikayeti.
- [ ] Geri bildirim → Faz D içerik ayarı + bug pass.

## Faz I — Launch — ~1-2 hafta

- [ ] Son QA pass: `verify.sh all` + full features + 8h soak + Windows matrisi + temiz
      makinede kurulum testi.
- [ ] Build review'a gönderim (Steam review süreci ~3-5 iş günü, ilk oyunda daha uzun
      olabilir — tarihe pay bırak).
- [ ] Launch günü: duyuru postları, topluluk hub hazır, ilk hafta günlük yorum/forum
      takibi + hızlı hotfix kanalı.
- [ ] Launch sonrası yol haritası (mağazada şeffaf): Mac/Linux portu, melodi paylaşım
      genişlemesi (arkadaşının kulesi senin şarkını çalar), yeni mevsim olayları.

---

## Sıralama özeti ve tahmini takvim (solo dev + Claude, part-time)

| Faz | İş | Süre | Paralellik |
|---|---|---|---|
| B+ | Çekirdek tamir: buglar + Pomodoro eksikleri | 1-2 hafta | — (her şeyden önce) |
| 0 | Metodoloji adaptasyonu + endgame/timelapse test altyapısı | 3-5 gün | B+ ile paralel olabilir |
| C | Ertelenen özellikler + menü + sanat yönü (albüm, tek menü, juice, kartpostal, dikey) | 3-4 hafta | — |
| D | İçerik derinliği (mektuplar, festivaller, milestone'lar, hava, end-game) | 3-4 hafta | E ile paralel |
| E | i18n EN+TR + ekran uyumluluğu + Windows + perf + settings + onboarding | 3-4 hafta | D ile paralel |
| F | Steamworks (GodotSteam, achievements, cloud) | 2 hafta | G ile paralel |
| G | Coming Soon + assetler + GIF döngüsü | sürekli | C sonrası başlar |
| H | Demo + Next Fest + playtest | 2-3 hafta | — |
| I | Launch | 1-2 hafta | — |

Kabaca **5-7 ay** part-time tempoyla gerçekçi. Kritik yol: B+ → C → (D ∥ E) → F → H → I;
pazarlama (G) C biter bitmez sürekli akar.

## Doğrulama kuralları

- Her faz maddesi: `tools/verify.sh all` yeşil + `tests/run_features.gd`'ye kabul testi +
  bağımsız qa-verifier subagent onayı (Faz 0 kuralı).
- **End-game kuralı (kalıcı):** sim'e dokunan HER değişiklikten sonra `verify.sh endgame`
  (365 gün hızlandırılmış koşu) da koşulur — 30-günlük pop-band tek başına yeterli sayılmaz.
  Büyümeye dokunan değişikliklerde ek olarak `verify.sh timelapse` çıktısına bakılır:
  şehrin büyümesi contact-sheet üzerinde gözle doğrulanır, ev sayısı kareler arasında
  monoton artar. "Sim değişti ama timelapse'e bakılmadı" = tamamlanmamış iş.
- **Web senaryo kuralı (kalıcı):** UI'a ya da render'a dokunan her işte
  `verify.sh web-scenarios` koşulur; Claude üretilen ekran görüntülerini TEK TEK açıp
  inceler ve raporlar ("koştu, geçti" yetmez — hangi kareye bakıldı, ne görüldü yazılır).
  Aynı tohum = aynı kare olduğundan önceki koşuyla piksel-diff görsel regresyon kapısıdır;
  eşik aşan karelerde iki görüntü yan yana incelenmeden iş kapanmaz.
- Faz E kabul: Windows makinede pencere matrisi elle test + perf ölçümleri
  (idle CPU/RAM/soak) rapor edilir; "hafif çalışıyor" iddiası sayı olmadan kabul edilmez.
- Faz F kabul: achievements Steam dev ortamında tetiklenip doğrulanır; cloud save iki
  makine arasında round-trip test edilir.
- Faz H kabul: playtest kohortundan 7-gün retention + hata raporu özeti.

## Açık kararlar (ilerledikçe verilecek)

1. Repo public+Apache kalsın mı, private'a mı çekilsin (Faz F).
2. AI asset kullanılıp Steam AI beyanı mı verilecek, yoksa launch görselleri AI'sız mı (Faz F).
3. Next Fest zamanlaması (demo kalitesi + wishlist ivmesine göre, Faz H).
4. Code signing sertifikası (SmartScreen uyarısına karşı, launch sonrası da alınabilir).
5. **Sanat yönü** (denetim #15): tam prosedürel stil cilalanarak mı kalınacak, yoksa hibrit
   (sakinler + landmark binalar sprite, zemin/ışık prosedürel) mi? Öneri: hibrit — 3px daire
   sakinler mektup yazan karakterleri taşıyamıyor; ama karar screenshot/capsule üretiminden
   (Faz G) önce kesinleşmeli, çünkü mağazanın tüm görsel kimliği buna bağlı.
6. Oyun saati gerçek saatle senkron mu olsun (kullanıcı 14:00'te çalışırken kasabada gece
   olabiliyor; Rusty bağımsız saat kullanır, ama "ekranının altında yaşayan kasaba" fantezisi
   gerçek-saat senkronunu da savunulabilir kılar — Faz D'de karar).
