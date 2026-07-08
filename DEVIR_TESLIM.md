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
# FAZ B+ — SAKİN KARTI + ATOMIC SAVE + AYARLAR (tamamlandı — B+ KAPANDI)
- Sakin hover kartı: tespit RENDER'da (town_view._process, _ppos piksel konumları; ~10px en yakın),
  köprü main.hovered_person(), kart UI'da (imleci izler, viewport'a clamp). Hover halkası ince arc —
  ışık kaynağı DEĞİL (bütçe delinmez). Kart: isim + evre (🌱çocuk/yetişkin/🕰bilge) + 💛atkı + 🌿yuva.
- Atomic save (denetim #22): tmp'ye yaz → eski kayıt .bak'a → rename. Bozuk asıl kayıt →
  push_warning + .bak'tan dönüş (kural 9: sessiz yutma yok). has_save .bak'ı da sayar.
- Ayarlar (denetim #21): scripts/settings.gd (user://settings.cfg, ConfigFile) — ses slider'ları
  kalıcı; save.json'dan AYRI (cihaz tercihi ≠ kasaba durumu). İlk açılış default'ları keşfedilebilir:
  pad 0.25 / dere 0.20 / cırcır 0.20 / master 0.7 (sıfır-sessiz açılış kalktı). main kapanışta +
  60sn otokayıtta Settings.save_audio; ui.sync_from_world slider'ları set_value_no_signal ile doldurur.
- TEST DERSİ: headless user:// GERÇEK oyunla paylaşımlı — dosyaya dokunan test önce mevcut
  save/settings'i yedekler, sonunda geri koyar (run_features._test_atomic_save deseni).
- Görsel: .verify_out/hover.png (Kemal · bilge kartı + halka). Testler: B+a atomic PASS.

# FAZ 0 — ENDGAME + TIMELAPSE TEST ALTYAPISI (tamamlandı)
- `verify.sh endgame` (tests/run_endgame.gd, 365 gün ≈ 80s headless): bant 20-90 + çökme/patlama,
  bellek tavanları (letters ≤ 100, mem_trees ≤ 40), perf düzlüğü (son 10 gün ≤ ilk 10 × 3),
  365. gün TAM-STRINGIFY save roundtrip, timelapse günlerinde İNŞA sayısı monotonluğu.
  KURAL (kalıcı): sim'e dokunan HER işten sonra endgame de koşulur.
- `verify.sh timelapse`: gün 0/3/7/14/30/60/120/365 kareleri (akşam 19:00, tohum sabit) →
  .verify_out/timelapse/. Kill penceresi güne orantılı (365 gün senkron ileri-sarma ~80-120s).
  capture.gd BUG düzeltildi: steps parse ediliyordu ama capture_setup'a İLETİLMİYORDU.
- Endgame testinin yakaladığı GERÇEK buglar (test kendini hemen ödedi):
  1) from_save int normalizasyonu eksikti: letters.who, trees/lamps/fountains/mem_trees gx/gy/s
     JSON'dan float kalıyordu (kritik tuzak 2'nin devamı) → tam-stringify roundtrip FAIL veriyordu.
  2) Monotonluk metriği dersi: lit_count OLMAZ (veda ile ev kararır, dalgalanır) —
     monoton olan İNŞA EDİLMİŞ (built==1) bina sayısıdır.
- MEKTUP TAVANI (denetim #27 minimal çözüm): world._push_letter tek kaynak (7 site dönüştü),
  LETTER_CAP=100; tavan aşılınca önce en eski YANITLANMIŞ düşer (yanıtsız duygusal çekirdek
  korunur); kalıcı arşiv albümle (Faz C) gelir.
- 365 GÜN ÖLÇÜMÜ (Faz D end-game tasarımının girdisi): pop bandı 30-80 sağlıklı; perf ×1.28 düz;
  AMA frontier 29/64'te kalıyor ve goal 55.611'e şişiyor (×1.18 üstel) → büyüme fiilen platoda.
  Gözle: gün 365'te kasaba haritanın ~%35'inde. "Kasaba doldu/bütünlendi" tasarımı + goal eğrisi
  yeniden ayarı Faz D'de bu sayılarla yapılacak.

# FAZ C (ilk blok) — ALBÜM · KARTPOSTAL · TEK MENÜ · UI JUICE · SANAT CİLASI (tamamlandı)
- ALBÜM (#17): 📖 panel — sakinler (evre+atkı), anı ağaçları (isimli), hikâye sayaçları
  (doğum/veda/gelen/dilek/bağ/seans/dk) + rozetler (konser/atölye/kütüphane). world.stat_wishes
  eklendi (dilek objeleri gen objeleriyle aynı listede — sayaç ayırt eder). Açılışta tazelenir.
- KARTPOSTAL (#20): main.take_postcard(dir_override="") — UI 2 kare gizlenir → ink çerçeve →
  Resimler'e NEFES_tohum<seed>_gun<N>_<saat>.png; world.town_seed() erişimcisi; "camera" çift-tık
  sesi. dir_override test kancası (.verify_out'a yazdırılıp gözle doğrulandı).
- TEK MENÜ (#18): bar 9→5 öğe (mode/🎯/seri/☰ Kasaba/✉); Ses/Melodi/Albüm/Kartpostal ☰ altında.
  Çekirdek etkileşimler barda (kural 5). Settings girişi Faz E'de buraya eklenecek.
- UI JUICE (#8): _button helper'da bal-tonu hover tween (tüm butonlar otomatik); yeni olay
  soldan kayarak süzülür (event değişim tespiti _last_event); yanıtsız mektupta zarf salınımı
  (pivot_offset + sin — bildirim spam'i değil, sessiz).
- SANAT CİLASI (Faz C sanat yönü, procedural karar): 
  · Çayır OPAK kolon şeritleri — eski yarı saydam hücre bindirmesi (CW+1) görünür GRID ÇİZGİSİ
    üretiyordu; kökü çözüldü. Bonus: zemin 1664 hücre → ~50 draw (perf).
  · Kasaba→çayır 4 kolonluk yumuşak geçiş bandı; uzak çayır ufka (sky_bot) karışır.
  · _dusk(c,k) helper: gün eğrisinde düz darkened yerine morumsu hue-shift + doygunluk
    (sınırlı-palet ramp dersi). Yol/çayır/ağaç geceyle kararır (ağaçlar gece parlak kalıyordu).
    PALET KİLİDİ korunur — kaynak renkler SEASONS'tan, yalnız ara-lerp yolu değişti.
  · status_text: öğlen "huzurlu bir akşam" (HTML kalıntısı) → gün/akşamüstü ayrımı.
  · Metrikler: gündüz 118.2 / akşam 88.5 / gece 59.1 (bant 58-88 alt sınıra yakın — gece
    ağaç karartması eklerken ölçmeden dokunma!), R−B>0, value>60. Üç kare gözle incelendi.
# FAZ C — MÜZİK DERİNLİĞİ (tamamlandı)
- Pad generative oldu (Eno modeli): 4 ses × ortak-katsız döngü (19.7/26.3/33.1/43.7s), her döngüde
  Rng.h ile pentatonik alt-oktav nota (C-D-E-G-A) — katmanlar hizalanmaz, tekrarsız. sin(π·t)
  döngü zarfı sınırda 0 → nota değişimi TIKSIZ. Frekans yalnız döngü sınırında hesaplanır (CPU).
- Vertical layering: odak seansında 5. üst-oktav katman (53.9s) — main start/cancel/timeout/restore
  noktaları audio.focus_active'i sürer. Akşam pad dolgunlaşır: ×(0.8+0.3·evening).
- Kule arası serpinti: CHIME_PERIOD 27.7s, %55 şans, pad kanalı açıkken kısık tek nota (0.03).
- SESSİZLİK ATLAMASI: audible değilken buffer sıfırla dolar, _t akmaya devam (döngü tutarlılığı);
  sinüs/LFO/noise hesaplanmaz. Perf: nişin 1 no'lu şikâyeti CPU'ya ilk somut önlem.
- Smoke (.verify_out/sndsmoke.gd): 60sn'de nota değişimi ✓ serpinti ✓ odak katmanı ✓ sessiz çökme yok ✓.
- KALAN FAZ C: dikey mod re-layout, ana menü/başlangıç ekranı, font/ikon/uygulama ikonu
  (asset işi — dev-pipeline), native ışıklar (perf bütçesine bağlı).

# FAZ D — MEKTUP DERİNLİĞİ + UZUN-VADE ANLARI + END-GAME (tamamlandı)
- letters.gd: ~70 parametrik şablon (i18n Faz E hazır). Kaynaklar: veda 12 + VEDA_ATKI 3
  (atkı sahibine kişisel), odak 12, dilek 3×5, taşınma 8 (%35 — aile/kuşak/göç, _maybe_move_letter
  tek kaynak), doğum 8 (%30 ebeveynden), an 4, bond-eki 4 (bond≥5, %40). Seçim Letters.pick +
  world._h → DETERMİNİST (test: aynı tohum = aynı mektup dizisi).
- Kilometre taşları (milestones dict, save'de): gun30 / sakin100 (name_idx) / veda50 — eşik
  aşımında tek seferlik _milestone (mektup + olay).
- END-GAME (denetim #29 tasarım karşılığı):
  · BÜTÜNLENME: _start_construction'da aday yok + frontier ≥ GW-8 → town_complete + "butunlendi"
    milestone (eski sessiz no-op görünür kutlamaya döndü). Sonrası her goal → _beautify (goal ×1.10).
  · PLATO TAŞMASI: goal > FLOWER_OVERFLOW(7200) iken growth eşiği aşarsa SABİT FLOWER_COST(2400
    ≈ 3 oyun-günü) düşülüp bir ev çiçeklenir (bloom) — goal BÜYÜMEZ. Hepsi çiçekliyse nazik şenlik.
  · DENGE DERSLERİ (iki başarısız deneme belgelendi): goal ×1.10 → harita doluyor AMA nüfus
    kapasiteyi takip edip 94-104 (bant 20-90 KIRILIR; nüfus kapasite-güdümlü — harita doldurma
    her yolda nüfusu şişirir). 3×goal taşma eşiği → goal üstel şişince 365 günde hiç tetiklenmez.
    Sabit-maliyet tasarımı bandı korur: 365-gün goal 7.631'de DENGEDE, bant 27-65, çiçekler akar.
  · Render: bloom → pencere altı mevsim-çiçek şeridi (_draw_building); save'de bloom bool taşınır.
- Testler: D mektup (çeşitlilik/milestone/determinizm) + De endgame (bütünlenme/tek-sefer/
  çiçek/roundtrip/taşma) + sim bandı + 365-gün endgame HEPSİ PASS. bloom karesi gözle doğrulandı.

# PERF BÜTÇESİ (ilk geçiş, tamamlandı)
- town_bg.gd STATİK KATMAN (z=-1, TownView çocuğu): gökyüzü/zemin/nehir-tabanı/yol/çayır-detay/
  plaza/anı-ağaçları. İmza: [season, frontier, int(evening×32), yol, anı, çeşme sayısı] —
  değişmedikçe redraw YOK (gündüz/gece 0, alacakaranlık ≤32). Çizimde imzadaki KUANTİZE ev
  kullanılır (tutarlılık). Palet/_mix/_dusk TownView'dan okunur (tek kaynak). NEHİR ışıltı
  çizgisi + kasaba ağaçları (sway) + çeşme (su animasyonu) dinamikte KALIR.
- Bina gy-sıralaması önbelleklendi (buildings.size() değişince) — önceden HER KAREDE
  duplicate+sort vardı. Kişi/lamba/bloom dinamik (ışık eğrisi sürekli).
- main: Engine.max_fps=30 (capture hariç). Ses tarafında sessizlik atlaması zaten var (C3).
- ÖLÇÜM DERSİ: pencereli kare-zamanı (TIME_PROCESS) macOS'ta ARKA PLAN PENCERE KISITLAMASI
  yüzünden güvenilmez (bileşenler kapalıyken bile ~30-45ms saçmalıyor). Kullanıcıya görünen
  metrik ps %CPU'dur → verify.sh perf gerçek oyunu başlatıp 6 örnek alır. tools/perf.gd
  (off=view,ui,audio,bg,sim bileşen-kapatma) elle draw-call/profil aracı olarak kalır.
- İLK ÖLÇÜM: %27.2 CPU / 487MB (30fps cap + statik katman + ses atlaması sonrası; bütçe %35
  dev-mac). Windows release hedefi (<%3-5 idle, <200MB) Faz E sağlamlaştırmasında.
- Görsel eşdeğerlik: pixelcheck 118.7/88.9/59.4 (±0.5 — ev kuantizasyonu) + akşam karesi gözle.

# FAZ D — HAVA DURUMU (yağmur, tamamlandı)
- world.rain_amount(): SAF türetim — günlük hash %28, gün içinde 3-6 saat pencere, 30dk rampa,
  kışın 0 (kar zaten var). SİM DURUMUNA ETKİMEZ (saflık testi: çağrı determinizmi saptırmaz).
  rain_was yalnız geçiş olayı için (save'e girmez; yüklemede tek sahte geçiş zararsız).
- Render: 80 çapraz çizgi (seedli kozmetik, town_view dinamik); bg imzasına int(rain×8) —
  gök MOR TABANLI griye çalar (Color8(104-118,...) — R−B>0 sıcaklık metriği korunur),
  zemin ıslak/koyu. Görsel metrikler PASS (gün-0 fazları yağmursuz denk geliyor).
- Ses: audio.weather_rain (main._process besler); etkin kazanç maxf(slider, weather×0.35) —
  cırcır×evening deseninin yağmur karşılığı. Sessizlik atlaması rain_gain'i hesaba katar.
- KALAN FAZ D: mevsimsel festivaller, milestone bina zinciri (rasathane/sera/hamam),
  dilek çeşitliliği (4-6 yeni obje), oyun saati↔gerçek saat kararı (Açık Karar #6).

# FAZ D (ikinci blok) — FESTİVALLER · DİLEK ÇEŞİTLİLİĞİ · BİNA ZİNCİRİ (tamamlandı — FAZ D KAPANDI)
- FESTİVAL: mevsim ortası (season_tick==600) bir kez; festival_t nabzı (chime_t deseni) render'da
  kutlama + mevsim serpintisi (petal/stardust/leaf/mote) + üç-nota festival sesi tetikler;
  sakinler meydana (%40); mektup %15 (mevsimler 1200 tick — spam değil). fest_done mevsim dönüşünde sıfırlanır.
- DİLEK 7 TİPE çıktı: +bank/kuş yuvası/posta kutusu/rüzgâr gülü → world.decor (save, int-güvenli);
  Letters.DILEK her tipe 4 metin (~90 şablon). Render dinamikte (rüzgâr gülü rüzgârla döner,
  yuvaya ara sıra kuş). REVIEW: bank/yuva renkleri palet dışıydı → yol kahvesi + c99b46'ya çekildi.
- BİNA ZİNCİRİ (denetim #12+#20): MILESTONE_BUILDINGS sabiti — rasathane(10)/sera(20)/hamam(35
  toplam seans). Görseller: kubbe+teleskop / camsı cephe+filiz / ikiz kubbe+buhar; kütüphaneye
  kitap sırtları. res["special"] → main unlock fanfarı.
- İKİ GERÇEK BUG (review/test yakaladı):
  1) _convert_unbuilt çakışması: aynı ödülde çoklu dönüşüm aynı binayı çalıyor, ilk inşaat 0.01'de
     SONSUZA DEK kalıyordu → el değmemiş bina seç + building_now yalnız boşsa al + step_world
     sahipsiz yarım inşaatı SAHİPLENİR (eski save'leri de iyileştirir).
  2) from_save unlocked hardcoded iki anahtar — yeni anahtarlar yüklemede DÜŞÜYORDU → sabit
     listeden .get ile genel yükleme. DERS: dict'e anahtar eklerken from_save'i kontrol et.
  3) (endgame yakaladı) festival_t/chime_t azalması negatif e-16 kalıntısında takılıyor; Godot JSON
     bu büyüklükte hassasiyet kaybediyor → 365-gün roundtrip FAIL. maxf(0.0, ...) clamp — dinlenme
     durumu TAM 0.0. DERS: azalan-sayaç alanları save'e giriyorsa sıfıra clamp'le.
- Doğrulama: features 12 test grubu + sim bandı + endgame 365 + görsel kareler (özel binalar,
  çiçekler, yağmur) + gerçek oyun 10sn açık-kalma kontrolü. HEPSİ PASS.
