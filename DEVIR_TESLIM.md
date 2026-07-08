# NEFES v10 — CLAUDE CODE DEVİR TESLİM NOTU
## Bu HTML'i indirip Claude Code'da geliştirmeye devam etmek için

## 1. NE DEĞİŞTİ (v9 → v10, kullanıcı kusur listesine karşı)
| Kusur | Çözüm (v10) |
|---|---|
| Gece/gündüz sokaklara işlemiyor | TAM 24h döngü (`timeOfDay`, `nightAmount()`); gökyüzü 3-faz (gündüz açık → alacakaranlık altın → gece koyu); zemin+yol+duvar+çatı hepsi `evening` ile karartılıyor |
| Lambalar hep yanıyor | Direk her zaman görünür ama parıltı SADECE `evening>0.15`; pencereler gündüz %4, gece %76 yanar (`litFrac` hedefi `0.04+evening*0.72`) |
| Sokak düzeni kötü, yol yok | GERÇEK yol ağı: `buildRoadNetwork()` — ana omurga yol TÜM harita boyunca (ormana kesintisiz), dallanan meandering sokaklar; binalar yol kenarına yerleşir (Foundation/Town-to-City modeli) |
| 65 ev / 4 sakin, büyüme görünmüyor | 6 ev / 2 sakinle başlar; `startConstruction()` → ev YÜKSELEREK inşa olur (buildProg 0→1, iskele çizgileri+toz) → `queueMoveIn()` → sakin yolda YÜRÜYEREK taşınır → varınca ev uyanır (ışık halkası). Ev:sakin ~1:1 |
| Orman yolu şehirde kayboluyor | Omurga yol tek parça; kasaba zemininden çayıra opaklık geçişi; yol her iki tarafta da çizilir |

## 2. MİMARİ (dosya: NEFES_v10.html, tek dosya ~450 satır)
- `buildRoadNetwork(maxX)` → `roadSet` (Set "x,y") + `roadList`. Omurga: `GH*0.5` çevresinde sinüs meander, 2 hücre kalın. Dallar omurgadan çıkar.
- `gen()` → nehir, yol ağı, plaza+landmark, yol-kenarı binalar (`hf<0.45` boşluk=bahçe), ağaçlar, lambalar (yol hücrelerinde `%5===0`).
- Büyüme durum makinesi: `growth` birikir → `goal` (×1.14) → `startConstruction()` (landmark'a en yakın inşasız bina `buildProg` yükselir) → bitince `queueMoveIn` → `movers[]` içindeki kişi greedy yol-yürüyüşüyle gider (90 adım zaman aşımı emniyeti) → varınca `awake=true`.
- `nightAmount()`: 8-17 gündüz 0; 17-21 rampa; 21-05 gece 1; 05-08 şafak inişi.
- Renk: hep `mixA(gündüzRengi, geceRengi, evening*k)` deseni. Mevsim `SEASONS[season]` (çayır/ağaç/çiçek/yol tonu; kışta kar parçacıkları).

## 3. GODOT'A TAŞIRKEN (öneri)
- roadSet/binalar → TileMapLayer'lar; `evening` → CanvasModulate rengi (aynı mixA eğrisi); lamba/pencere → PointLight2D + WorldEnvironment glow (yalnız `evening>0.15`).
- İnşa animasyonu: bina sprite'ı `scale.y` tween 0→1 + toz partikülü; taşınma: sakin sahnesi yol hücrelerinden `Path2D`/adım adım tween.
- Deterministik `h()` hash'ini aynen taşı (günlük tohum uyumu için).

## 4. BİLİNEN SINIRLAR / SIRADAKİ İŞLER
- Büyüme temposu demo için hızlı (40sn'de ~10 ev); Godot'ta `growth+=` katsayısını 5-10× yavaşlat.
- Sakinlerin gündüz rutini yok (hep geziyorlar) → gündüz: evde/dükkânda, akşam: sokakta olmalı.
- Mevsim geçişi ani; 2-3 sn'lik renk lerp'i ekle.
- Retention katmanları (özeleştiri Ç7-Ç13) henüz kodda YOK: offline özet kartı, sürpriz ziyaretçi, mektuplar UI, kartpostal modu, Pomodoro. Sıradaki büyük iş bunlar.
- Ses yok.

## 5. AYAR DÜĞMELERİ (hızlı deney için)
- Tempo: `growth += 0.4 + evening*0.3` ve `goal*=1.14`
- Gün uzunluğu: `tick/2400*24` (2400 tick = 1 gün ≈ 2.8 dk; Godot'ta 20-40 dk yap)
- Işık yoğunluğu: lamba `0.4*evening`, pencere bloom `0.22*e`, landmark halo `0.04+0.3*evening`
- Başlangıç çekirdeği: `b.awake = i<6`


---
# v11 EKİ — YAŞAM DÖNGÜSÜ & KURAL SİSTEMİ (Godot'a birebir taşınır)

## Hane sistemi (Banished modeli)
- Ev = hane. `cap: 2-4`. `members[]`. Kişi/ev hedefi ~2-2.5 (artık adam başı 1 ev YOK).
- İnşaat KURALI: `housingPressure() = nüfus/toplamKapasite ≥ 0.75` VEYA (yuva arayan var VE boş ev yok). Başka koşulda inşaat başlamaz.
- Yeni ev bitince: %60 dışarıdan 2 kişilik aile taşınır, %40 boş kalır ("sahibini bekliyor" → kuşak/göç doldurur).

## Yaşam döngüsü (nazik — Foundation dersi: ceza yok, mikroyönetim yok)
- Evreler: çocuk(≈1g) → yetişkin(3-6.5g, GENİŞ varyans: kohort dalgasını kırar) → bilge(2-3g) → veda.
- Veda: kişi yıldıza karışıp süzülür (star partikülü), çayıra ANI AĞACI dikilir (maks 40, eskiler usulca gider), veda olayı yazılır; ev boşalırsa IŞIKLARI SÖNER (duygusal an + ışık bütçesi).
- Doğum: 2+ yetişkinli ve boş kapasiteli evde, her 40 tick %10 (tek doğum/kontrol).
- Kuşak: büyüyen çocuk `wantsHome` → boş eve yürüyerek taşınır → yeni hane.
- Göç: boş ev + baskı<0.75 → dışarıdan aile; kasaba boşsa (baskı<0.45) göç HIZLANIR (400 tick) → kasaba asla ölmez.
- 30 gün testi: pop 46→59→44→40→35 dalgalı denge, 146 veda. Denge düğmeleri: doğum %10, göç 400/800 tick, spanB varyansı.

## Işık bütçesi (kullanıcı: "oyun çok ışıklı oluyor")
- `lightCurve = evening × (1 − sleep×0.55)`: 20-23 zirve, 23'ten sonra kasaba uykuya dalar.
- Pencereler 23-05 arası %85 söner; gece yarısı sadece ana yol lambaları; yan sokaklar uyur.
- Bloom bütçesi: `min(1, 14/ev)` — kasaba büyüdükçe ev başı parıltı kısılır, toplam sabit.
- "Gezen ışıklar" kaldırıldı (taşınan sakin halesi yok); ölçüm: gündüz 117 / akşam 87 / gece yarısı 77.

## Retention (yeni)
- İsimli sakinler (Türkçe havuz) + OLAY AKIŞI: 🌱 doğum, 🌿 yuva arama, 🏡 taşınma, 🕰 bilgelik, ✦ veda, 🌒 sönen ev. Mektup sistemine bağlanacak ham olay kaynağı bu akış.
- Anı ağaçları = kalıcı duygusal koleksiyon (çayırda mor-ışıltılı).


---
# v12 EKİ — GAME JUICE KATMANI
Tek partikül sistemi (`parts[]`, tavan 240, tipler: mote/dust/petal/leaf/stardust/spark)
+ easing (`easeOutBack`, `easeOutCubic`). Godot'ta karşılığı: GPUParticles2D + Tween.

Juice sözlüğü (an → his):
- LAMBA KASKADI: her lambanın kişisel eşiği (`0.15+ph/6.28*0.5`) — alacakaranlıkta
  ~1 saat boyunca TEK TEK kıvılcımla tutuşurlar (oyunun günlük 'gösterisi').
- İNŞAAT: easeOutBack zıplayan yükseliş + süren toz + bitince 10 mote havai patlaması.
- İNSANLAR: hücreye ışınlanma yok — piksel-lerp takip (0.14) + yürürken bob salınımı.
- DOĞUM: evden süzülen 7 taç yaprağı. VEDA: yıldız + stardust izi; anı ağacı
  easeOutBack ile büyüyerek doğar. SÖNENEV: ışıklar kararır (v11'den).
- SAAT BAŞI: kule kadranı nabız atar (chimeT), kuşlar 1.4sn ürküp hızlanır.
- MEVSİM: sonbaharda ağaçlardan yaprak, ilkbaharda taç yaprağı serpintisi;
  gece çayırda 8 ateşböceği (ışık bütçesine sayılır, sabit adet).
Godot notu: kaskad eşiği ve lightCurve aynı formülle shader/uniform'a taşınır.


---
# v13 EKİ — OYUNCUDAN ALINAN KATMAN (rakip derslerinin uygulanması)
Rakip analizindeki süzülmüş özellikler artık kodda:

## 🎯 Odak Seansı (AL-3, Mini Cozy Room dersi — masaüstü kimliği)
- Buton → seans başlar (demo 45sn; GERÇEK OYUNDA 25dk Pomodoro).
- Bitince: anında bir inşaat ödülü + meydanda mote kutlaması + kasabadan teşekkür MEKTUBU.
- Erken bırakma cezasız (cozy ilkesi). Rusty'nin 'dikkat dağıtır' kusurunu erdeme çevirir:
  oyun, kullanıcının GERÇEK çalışmasını yakıt yapar.

## 💭 Dilekler (AL-5, Onsen misafir-memnuniyeti dersi; Ç12 nazik istekler)
- ~her 700 tick'te bir yetişkin dilek tutar (çeşme/ağaç/fener) → çip görünür.
- Tek dokunuş → obje sakinin evinin yanına kurulur (juice: mote patlaması) +
  kişisel TEŞEKKÜR MEKTUBU. Zorlamasız: görmezden gelinebilir, ceza yok.

## ✉ Mektuplar + CEVAP (imza özelliğimiz — hiçbir rakipte yok)
- Kaynaklar: dilek teşekkürü, odak kutlaması, VEDA mektubu (yıldızlara karışan sakin
  arkasında mektup bırakır — duygusal çekirdek).
- 'İçtenlikle yanıtla' → bond+1, sakin ATKI kazanır (dairesinde altın halka — bağın
  görünür nişanı, AL-4 varyant tohumu). Panel: sağ-alt çekmece, ✕ ile kapanır.

## Godot eşlemesi
- focus → Timer node + gerçek 25dk; mektup paneli → Control/RichTextLabel;
  dilek çipi → toast; bond → save'e yazılır; atkı → sakin sprite varyantı.
## Test kanıtı
- odak→mektup(kind:odak) ✓, dilek→fountains 0→1 + mektup ✓, cevap→bond1+atkı1 ✓, JS temiz.


---
# v14 EKİ — SES + ÇALIŞMA SİSTEMİ (Pomodoro derinleşmesi)
## Ses motoru (WebAudio, %100 SENTEZ — telif riski sıfır, bizim)
- 4 ambient kanal, kullanıcı slider'lı (🔊 paneli): 🌧 yağmur (lowpass gürültü),
  💧 dere (bandpass+LFO fokurtu), 🎹 lo-fi pad (detune üçgen akor+tremolo),
  🦗 gece cırcırı (kanal seviyesi × evening — geceyle nefes alır). + ana ses.
- Olay sesleri (ödül): odak bitişi (4-nota sıcak arpej), seri açılışı (5-nota fanfar),
  lamba tutuşması (minik tık), mektup (kağıt hışırtısı), veda (çift yumuşak nota), doğum (iki nota yukarı).
- GODOT: aynı sentez Python'la .ogg stem'lere render edilebilir (numpy→wav→ogg) ya da
  AudioStreamGenerator ile birebir taşınır. Mobil için de aynı motor (Web Audio→AudioStreamPlayer).

## Çalışma teknikleri + seri
- Mod seçici: Pomodoro 25/5 ve Derin Çalışma 50/10 (demo 45s/90s; gerçek süreler dakika).
- SEANS SIRASINDA kasaba ×1.5 büyür (ölçüldü: 100 tick'te ~%50 fazla) — "kullanıcı çalıştıkça büyür".
- SERİ: art arda 3 seans → ATÖLYE kurulur (özel bina+fanfar+mektup); 5 → KÜTÜPHANE sözü.
  Seri bozulunca ceza yok (cozy) — sayaç sıfırlanır, kazanılanlar kalır.
## Test kanıtı: AC+4 kanal ✓, ×1.5 çarpan ölçüldü ✓, streak3→atölye+mektup ✓, JS temiz.


---
# v15 EKİ — KULE MELODİSİ (oyuncu kendi müziğini yapar)
Animal Crossing 'Town Tune' dersi + myNoise mikser modeli birleşimi:
- 🎼 8 adım × 6 nota PENTATONİK ızgara (C-D-E-G-A-C: her kombinasyon uyumlu →
  ödül garantisi, müzik bilgisi gerektirmez). Dokun=nota, tekrar=sus. ▶ önizleme.
- 'Kuleye öğret' → SAAT KULESİ her saat başı OYUNCUNUN melodisini çalar
  (chime artık kişisel — sahiplenmenin zirvesi; kadran nabzıyla senkron).
- ÖDÜL KURALI (iyi beste): ≥5 nota + ≥3 farklı ses + ≥3 hareket →
  MEYDAN KONSERİ: sakinler kuleye akın eder, 18-mote havai, fanfar,
  'Gezgin Müzisyen' MEKTUBU + kasabaya yerleşir, bağ+1. (Bir kez; tekrarı
  mevsim şarkıları olarak genişletilebilir.) Zayıf beste: ceza yok, nazik ipucu.
- GODOT: ızgara→GridContainer, melodi→AudioStreamGenerator dizisi; mobilde aynı.
  İleri fikir (Godot fazı): melodi paylaşım kodu (8 harf) → arkadaşının kulesi
  senin şarkını çalar; ambient mikser preset'leri kaydet/paylaş.
Test: 48 hücre ✓, zayıf beste ödülsüz ✓, iyi beste→konser+mektup+bağ ✓, JS temiz.


---
# GODOT FAZI — DOĞRULAMA PIPELINE (Faz 0, kuruldu)
HTML v15 → Godot 4.7 portu başladı. Referans: `NEFES_v15.html` (davranış kaynağı, değiştirilmez).

## Godot binary
- Konum: `~/Downloads/Godot.app/Contents/MacOS/Godot` (v4.7.stable). PATH'te değil.
- Sarmalayıcı: `tools/godot.sh` binary'yi otomatik bulur (GODOT env ile override).

## Doğrulama TEK BİNARY ile — export template / Chromium / Playwright GEREKMEZ
CLAUDE.md'nin "web export + Playwright" akışı yerine daha hafif ve doğrudan Godot render'ını
sınayan yol seçildi (export template kurulu değil; bu yaklaşım bağımlılıksız + deterministik):
- `tools/verify.sh check` → tüm `.gd` `--headless --check-only` (commit öncesi zorunlu).
- `tools/verify.sh sim`   → `tests/run_sim.gd` headless pop-band (30g 20-90) + determinizm.
- `tools/verify.sh visual`→ `tools/capture.gd` PENCERELİ viewport PNG (GPU şart, headless render YOK;
  verify.sh kill-fallback ile sarar) → `tools/pixelcheck.gd` headless metrik
  (parlaklık gündüz~115/akşam~90/gece~70, sıcaklık R−B>0, value aralığı>60).
- `tools/verify.sh all` → üçü birden.

## capture_setup(seed, tod) sözleşmesi (A0'da Main'e eklenecek)
`capture.gd`, Main.tscn'de `capture_setup(seed_val:int, tod:float)` metodu varsa çağırır →
deterministik tohum + sabit günün-saati ile frame yakalanır. Yoksa oyunun kendi durumu yakalanır.

## Faz 0 baseline bulgusu (gerçek, pipeline hatası değil)
Çıplak port (89 satır main.gd) sanat metriklerinde FAIL: parlaklık 164 (yüksek), R−B=−23.6 (soğuk).
A0 render paritesi (sıcak zemin/çatı + gece eğrisi) + capture_setup zaman kontrolü ile düzelecek.

# A0 — REFACTOR + DÜNYA/RENDER PARİTESİ (tamamlandı)
Mimari (tek yönlü akış): `scripts/rng.gd` (class_name Rng, statik h/hf — JS 32-bit emülasyonu),
`scripts/world.gd` (class_name World, RefCounted SAF sim: gen/step_world/force_time, grid-tabanlı),
`scripts/town_view.gd` (Node2D, _draw paritesi + kozmetik per-frame), `scripts/main.gd` (koordinatör).
`Main.tscn`: Main(Node2D) → TownView(Node2D).

## Öğrenilen kurallar (Godot 4.7)
- Sabit-adım: 1 gün=1800s / 2400 tick ⇒ tick=0.75s. main._process akümülatör; kare-başına sim YOK.
- Kozmetik (kuş/bulut/kar/kişi-easing/rüzgâr) render'da per-frame (delta) → 0.75s tick'e rağmen akıcı;
  sim grid'de tick-başına. Render World'e YAZMAZ (kişi easing town_view._ppos'ta, dict'te değil).
- Determinizm: HTML lifeCycle/particle Math.random'ları sim'de _h/_hf'e taşındı; snow/cloud/bird
  kozmetik init'i Rng.hf ile seedli. GDScript'te randi/randf YOK.
- Determinizm testi PASS; render metrikleri PASS: gündüz 120 / akşam 92 / gece 61 parlaklık,
  hepsinde R−B>0, value>160. `.verify_out/frame_*.png` gerçek kasaba (nehir/kule/ev/yol/çayır).

## Godot tuzakları (çözüldü)
- `class_name` izole `--check-only`'de çözülmez → verify.sh check ÖNCE `--headless --import`
  ile global sınıf önbelleğini tazeler.
- Dictionary/duplicate()'ten gelen değer Variant → `var x := b.gx*CW` runtime PARSE HATASI
  (check-only bunu kaçırabilir!). Çözüm: yerel değişkene açık tip: `var x: float = ...`.
  DERS: check-only YETMEZ; görsel/runtime capture ile de doğrula.

## A0 bilinen sınır (A1 kapısı)
Yaşam döngüsü yok → doğum yok → konut baskısı sabit → inşaat tetiklenmez → nüfus 4'te sabit
(HTML'de de büyümeyi lifeCycle sürer). `verify.sh sim` pop-band'i A1'den sonra geçer.

# A1 — HANE + YAŞAM DÖNGÜSÜ (tamamlandı)
`scripts/names.gd` (Türkçe havuz, deterministik sıra). world.gd: name_idx/event_log/letters,
`_life_cycle` (yaşlanma çocuk→yetişkin→bilge→veda; kuşak göçü %40 tick; dış göç 400/800 tick;
doğum 2+ yetişkin & boş kap %10/40 tick tek-kontrol), `_pass_away` (ev kararır + anı ağacı max40
+ veda mektubu + ✦ olay), olay akışı 🌱🌿🏡🕰✦🌒.
- Mektuplar: veda mektubu KAYNAĞI burada (world.letters); dilek/odak mektupları + UI + cevap = A4.
- SONUÇ (30 gün): tohum0 4→60→~38 dalgalı denge (min21/max60), tohum20260707 min33/max60;
  çökme/patlama yok; determinizm PASS. HTML "46→59→44→40→35" dengesiyle örtüşür.
- Test dersi: pop-band'de ilk WARMUP_DAYS=3 gün başlangıç rampası bandtan hariç (kasaba 4'ten uyanır);
  denge bandı 20-90 + hiç çökme(0)/patlama(>150) yok. capture.gd `steps=N` ile yaşayan kasaba yakalanır.

# A2 — IŞIK BÜTÇESİ + PARTİKÜL SİSTEMİ (tamamlandı)
Işık bütçesi zaten sim'de (light_curve=ev×(1−sleep×0.55), sleep 23-05) + render'da bloom min(1,14/ev).
Partiküller town_view'da (render-side; sim SAF kalır): parts[] tavan240 mote/dust/petal/leaf/stardust/spark
+ _pop_rings veda yıldızı + 8 ateşböceği (evening>0.5, bütçeli).
- KURAL: sim event YAYMAZ; render sim durumunu GÖZLEMLEYEREK tetikler — building_now ref takibi (bitiş→
  10-mote), _lamp_on[] kaskad kıvılcımı, yeni stage-0 seed→7 taçyaprağı, yeni mem_tree ref→yıldız,
  chime_t 1'e sıçrama→kuş ürkmesi. Böylece "render World'e yazmaz" ihlal edilmez.
- Determinizmsiz kozmetik jitter: render-side _fx_seed sayacı + Rng.hf (GDScript randf YOK, sim'e dokunmaz).
- Partikül zamanlaması delta×14 (HTML ~14fps hissi); life -= decay×delta×14. Metrikler PASS kalır
  (partikül geçici, donmuş capture'ı domine etmez). Native GPUParticles2D/glow yükseltmesi = B2.

# A7 — UI İSKELESİ (tamamlandı) + A4 — DİLEK/MEKTUP/BOND (tamamlandı)
`scripts/ui/ui.gd` (CanvasLayer, kod-tabanlı Control ağacı; editör gerekmez). HUD (saat/mevsim·durum,
ev·sakin), olay akışı satırı, alt bar (mod seçici, 🎯 Başlat, seri, 🔊, 🎼, dilek çipi, ✉ Mektuplar N),
boş paneller sound_box/melody_box/mail_box (A3/A5/A6 doldurur). Paneller varsayılan KAPALI (kural 5).
- Akış: ui World'ü OKUR (HUD/olay); eylemler main'e (start_focus/grant_wish/reply_letter) iletilir;
  main world'ü mutasyona uğratır + town_view.celebrate (mote patlaması) tetikler. Render↔sim ayrımı korunur.
- Capture'da UI GİZLENİR (main.capture_setup ui.visible=false) → piksel metrikleri kasabayı ölçer.
- A4 world: wish (700 tick'te yetişkin, hf<0.6), grant_wish (çeşme/ağaç/fener evin yanına + teşekkür mektubu),
  reply_letter (bond+1 + sakin.scarf). Mektup kaynakları: veda(A1)/dilek(A4)/odak(A3)/konser(A5).
- Test (tests/run_features.gd, headless): dilek→obje+mektup+temizlik OK, cevap→bond+atkı OK. Mail paneli
  görsel doğrulandı (Elif çeşme mektubu + yanıtla butonu, Kemal veda mektubu, ev37·sakin46 kasaba).
- GDScript tuzağı: test'lerde `var x := VariantDeğer.metod()` PARSE HATASI → untyped `var x = ...` kullan.

# A3 ODAK · A5 MELODİ · A6 SES (tamamlandı — HTML v15 A-fazları BİTTİ)
- A3 (world.finish_focus_reward + main Timer): gerçek dakika Pomodoro25/Derin50, growth_mult=1.5,
  seri 3→atölye 5→kütüphane, ödül mektupları. Test: ×1.5 (0.292→0.437), seri3→atölye OK.
- A5 (melody.gd + world.teach_tower): 8×6 pentatonik ızgara, iyi beste(≥5nota/≥3farklı/≥3hareket)→
  Meydan Konseri (Gezgin Müzisyen yerleşir + mektup + bond, bir kez). Paylaşım kodu 8 harf (A..G).
  Test: iyi/zayıf ✓, konser+mektup+bond+pop ✓, bir-kez ✓, kod round-trip ✓ (BDFDAECB).
- A6 (audio_engine.gd, AudioStreamGenerator @22050Hz): 4 ambient kanal (yağmur lowpass gürültü / dere
  bandpass+LFO / pad detune üçgen akor+tremolo / cırcır×evening) + 6 olay sesi (odak arpej/seri fanfar/
  lamba tık/mektup/veda/doğum). Gürültü iç LCG (randf DEĞİL, sim'e dokunmaz). Mikser 5 slider.
  Olay tetikleri: main (odak/konser/dilek), town_view (lamba/doğum/veda — render gözlemli).
  Smoke: playback geçerli + 11 ses aktif + çökme yok. İŞİTSEL kalite kullanıcı testine kalır (headless yargılayamaz).
- Tüm A-fazı doğrulama YEŞİL: verify check PASS, sim pop-band+determinizm PASS, features(A3/A4/A5) PASS,
  görsel metrikler gündüz120/akşam92/gece61 PASS. UI panelleri (mektup/melodi/ses) görsel doğrulandı.

# B1 — SAVE + OFFLINE "SEN YOKKEN" (tamamlandı)
`scripts/save.gd` (user://save.json) + world.to_save/from_save (TAM durum, oyuncu sapmaları için).
main: açılışta yükle+offline ilerlet, kapanışta+60s'de kaydet (NOTIFICATION_WM_CLOSE_REQUEST +
set_auto_accept_quit(false)), OfflineKart. capture'da _is_capture ile kayıt yok.
- KRİTİK TUZAK 1: person.home ↔ building.members DÖNGÜSEL ref → dict'i pidx anahtarı yapmak
  recursive_hash SONSUZ RECURSION. Çözüm: geçici `_sid` index damgası (identity, hash/eşitlik yok).
- KRİTİK TUZAK 2: Godot JSON TÜM sayıları float'a çevirir → seed/col/steps/roof/melody int-kritik
  alanlar bozulur (dizi indeksi/bitwise patlar). from_save'de _PERSON_INT/_BLD_INT + melody int()'lenir.
- Offline: elapsed_sec/0.75 tick (cap 20000 ≈ 8 oyun günü), step_world ile deterministik ileri-sar,
  doğum/veda/gelen say → kart. 1 gerçek saat = 4800 tick = 2 oyun günü.
- Test: roundtrip-eq ✓, yükleme-determinizmi ✓ (w==w2 3000 adım sonra), seed-int ✓, dosya round-trip ✓,
  offline advance ✓ (pop 8→47), OfflineKart görsel ✓.

# B2 KAMERA · B3 PENCERE · B4 GÜNDÜZ RUTİNİ (tamamlandı)
- B2 kamera mikro-zoom: Camera2D merkeze (480,180) → durağanda görüntü BİREBİR aynı (metrikler korunur).
  Konser + odak ödülünde zoom 1.0→1.012→1.0 Tween (cozy zoom-in; screenshake DEĞİL). Görsel metrikler PASS.
- B3 pencere: main._setup_window borderless + always_on_top + ekran-altı şerit konumlandırma;
  V = dikey/yatay kadraj geçişi; Esc = kaydet+çık (borderless'ta başlık çubuğu yok). capture'da atlanır.
- B4 gündüz rutini: _move_people hareket olasılığı = 0.12 + evening×0.40 → gündüz sakinler durur,
  akşam sokağa dökülür. pop-band korunur (min21/max60).
- B2 ERTELENEN (opsiyonel, working build'i riske atmamak için): native PointLight2D havuzu +
  WorldEnvironment glow — _draw radial-alpha juice zaten cozy etkiyi veriyor + sanat metriklerini geçiyor.
  B4 ERTELENEN: albüm/kartpostal/tek-menü (ekstra UI). Gerçek dikey render re-layout (şimdilik konumlandırma).

# FAZ B+ — ÇEKİRDEK TAMİR: BUGLAR & KIRIK VAATLER (STEAM_ROADMAP denetimi, bug 1-7 tamamlandı)
STEAM_ROADMAP.md'deki satır-satır kod denetiminin 7 gerçek bug'ı düzeltildi (verify check/sim/features PASS):
- Bug 1 (kırık imza vaadi): kule saat başı ÖĞRETİLMİŞ melodiyi çalmıyordu. main._process chime_t
  yükselen-kenarını (town_view desenini yansıtarak) yakalar → `audio.play_melody(world.melody)`;
  yalnız `melody_saved` ve `not world.is_asleep()` (23-05 uyku penceresi — ışık bütçesi ruhu). Boot'ta
  `_prev_chime = world.chime_t` ile hayalet çan engellenir.
- Bug 2: `ui._melody` açılışta default'tu → `ui.sync_from_world()` (main._wire çağırır) kayıtlı
  `world.melody`'yi ızgaraya yükler.
- Bug 3 (save sızıntısı): odak sırasında kapanış → `growth_mult:1.5` save'e yazılıp yüklemede kalıcı
  ×1.5 oluyordu. `from_save` artık `growth_mult = 1.0` zorlar (seans restore B+ Pomodoro'da gelecek).
- Bug 4 (save crash riski): vefat eden dilek sahibi → `_pass_away` `wish.who == p` ise `wish = null`
  (yoksa to_save silinmiş kişiye `_sid` erişip patlıyordu).
- Bug 5: kütüphane hiç inşa edilmiyordu (sadece söz + mektup). Artık atölye gibi inşasız bir binayı
  `type="library"` yapıp inşaatı başlatır. AYIRT EDİCİ GÖRSEL Faz C sanat işine bırakıldı (şimdilik
  jenerik bina çizilir; render "shop" dışını house gibi çizer — regresyon yok).
- Bug 6: mektup→kişi eşleşmesi İSİMLE yapılıyordu (Names.POOL 20 döngüsel isim → yanlış kişiye atkı).
  Mektuplara kalıcı `who: person.seed` eklendi (şehir-geneli odak/seri/konser mektuplarında who:-1 ya da
  yerleşen müzisyenin seed'i); `reply_letter` `int(l.get("who",-1))` ile seed eşleştirir (JSON int→float'a
  karşı int()). Eski save'ler who'suz → .get default -1 güvenli.
- Bug 7: `_step_mover` fallback adayları nehri kontrol etmiyordu → sakin nehir üstünden geçebiliyordu.
  Aday toplarken `river_set` elenir (90-adım emniyeti korunur). Pop-band 33-60 korundu (regresyon yok).
- KURAL: sim saf kaldı (world event yaymaz); main chime'ı GÖZLEMLEYEREK ses tetikler — render↔sim ayrımı korunur.

# FAZ B+ — POMODORO ÇEKİRDEĞİ + SERİ/İSTATİSTİK (tamamlandı)
- Durum makinesi (main): _focus_phase "" | "work" | "break", tek Timer. work bitince ödül +
  otomatik mola (5/10 dk); mola bitince nazik iki-nota "breakEnd" sesi (alarm değil — cozy).
  Buton üç iş: boşta başlat / çalışırken CEZASIZ bırak (ödül yok, seri dokunulmaz) /
  molada molayı atla + yeni seans. Mod seçici yalnız work sırasında kilitli.
- UI tek kaynaktan: main.focus_state() → {phase, remaining, mode}; ui._refresh_focus_button
  geri sayımı (🎯 24:59 · bırak / ☕ mola 04:59) her karede türetir. set_focus_active KALDIRILDI.
- SERİ TANIMI (kilitli karar): aynı gün (YYYYMMDD, main._daily_seed verir) art arda seans;
  gün değişince seri nazikçe 0'a döner, kazanılan ödüller (atölye/kütüphane) kalır.
  finish_focus_reward(day=-1, minutes=0): day=-1 → gün takibi yok (testler eski davranışla geçer).
- İstatistik (world): stat_focus_min, today_focus_min, focus_day, best_streak; UI "seri N" butonu →
  EMEĞİN paneli (bugün/toplam dk, seri/en uzun/seans). Save'e girer; eski save .get default'la açılır.
- SEANS KALICILIĞI: kapanışta world.focus_phase/mode/until (unix) save'e; açılışta
  _restore_focus_session: süresi kaldıysa kaldığı yerden sürer (growth_mult 1.5 geri),
  yokken bittiyse ödül açılışta verilir (cozy: emek asla yanmaz). Yüklemede growth_mult=1.0 kuralı korunur.
- Görsel doğrulama: .verify_out/pomo_work/stats/idle.png — geri sayım butonu, EMEĞİN paneli,
  iptal sonrası growth_mult=1.0 doğrulandı. Testler: B+ pomodoro (gün-değişimi/roundtrip/uyku) PASS.
- KALAN B+ (sıradaki): sakin hover/tık kartı, atomic save + settings.cfg + ambient default'ları.
