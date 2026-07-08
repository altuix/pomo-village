# CLAUDE.md — NEFES (Godot 4.x masaüstü cozy idle)

Bu dosya iki şeyi birleştirir: **anayasa** (ihlal edilemez ilkeler) + **geliştirme &
review kuralları** (kod yazarken ve incelerken uygulanacak maddeler). Anayasa üsttür;
kurallar onu review-odaklı, uygulanabilir maddelerle genişletir.

Kuralların kaynağı: NEFES anayasası + başka bir projeden (web-streaming) taşınabilir
genel review prensipleri (Godot/GDScript'e uyarlandı; React/SCSS'e özel olanlar elendi).

---

## Kimlik (tek cümle — asla sapma)

"Ekranının altında, sen çalışırken uyanan minyatür bir kasaba; sakinler yaşar,
sana mektup yazar, kule senin melodini çalar." Rain City evreni, solo geliştirici + Claude.

## Dokümanlar (önce oku)

- `DEVIR_TESLIM.md` → v10-v15 tüm kurallar/formüller (yol ağı, hane, yaşam döngüsü,
  ışık bütçesi, odak, mektup, melodi). Kurallar buradan değiştirilmeden taşınır.
- `JUICE_YAPILACAKLAR.md` → sıralı görev listesi (A juice / B port / C pazar).

---

# BÖLÜM 1 — ANAYASA (ihlal edilemez)

1. **DETERMİNİZM:** tüm rastgelelik `Rng.h(x)/Rng.hf(x)` hash'inden. `randi/randf/randomize`
   YASAK. Aynı tohum = aynı kasaba. Günlük tohum: YYYYMMDD.
2. **COZY İLKESİ:** ceza yok, kayıp korkusu yok, zorunlu tıklama yok. Ölüm bile nazik
   (veda mektubu + anı ağacı). MTX/FOMO/streak-cezası ASLA eklenmez.
3. **IŞIK BÜTÇESİ:** `light_curve = evening × (1 − sleep×0.55)`. 23:00-05:00 kasaba uyur.
   Yeni ışık kaynağı ekliyorsan bütçeden düşür (bloom `min(1, 14/ışık_sayısı)`).
4. **SANAT İNCİLİ:** 12 renk kilitli palet (ink #2b1e2e → honey #ffe6a8; çatılar
   c25a4a/c99b46/7a9b6a/6a86a8/9a6a8c). Value hiyerarşisi: zemin koyu < bina orta
   < ışık açık. Doygun sarı SADECE ışıkta (%10 kuralı). Yeni asset bu palete uyar.
5. **TEK CÜMLE NETLİĞİ:** her yeni mekanik OPSİYONEL katmandır; çekirdek (izle→büyür→
   mektup) asla mekanik zorunluluğuyla kirletilmez.

## Teknik kurallar

- Godot 4.x, GDScript. Tab girinti, `snake_case`, tipli değişkenler (`var x: float`).
- Sahne yapısı: `Main.tscn` tek dünya node'u; UI ayrı CanvasLayer; ses AudioStreamPlayer
  havuzunda. Sim mantığı render'dan AYRI tutulur (sim fonksiyonları saf, test edilebilir).
- Süreler: 1 oyun günü = 30dk gerçek zaman (2400 tick sabiti korunur, tick süresi ayarlanır).
  Odak: Pomodoro 25/5, Derin 50/10 GERÇEK dakika (Timer node).
- Save: `user://save.json` — nüfus, evler, mektuplar, bond, melodi, seri, son-çıkış
  zamanı. Açılışta OFFLINE ÖZET kartı üret ("sen yokken: ...").
- Pencere: borderless, always_on_top, ekran-altı şerit; dikey mod ikinci kadraj.

## Ses

- %100 sentez (telif yok): AudioStreamGenerator ya da numpy→ogg stem render.
- Kanallar (yağmur/dere/pad/cırcır) kullanıcı slider'lı; cırcır × evening.
- Olay sesleri ödüldür: odak arpeji, seri fanfarı, lamba tıkı, mektup hışırtısı,
  veda çift notası. Yeni özellik = yeni minik ses düşün.
- Kule melodisi: pentatonik (C-D-E-G-A-C) — kullanıcı ne yaparsa yapsın uyumlu.
  İyi beste kuralı (≥5 nota, ≥3 farklı, ≥3 hareket) → Meydan Konseri ödülü.

## Yasaklar

- `randi/randf`, telifli asset/müzik, karanlık desen (bildirim spam'i, suçluluk metni),
  çekirdeği zorunlu mekanikle boğmak, paleti genişletmek, ışık bütçesini delmek.

---

# BÖLÜM 2 — GELİŞTİRME & REVIEW KURALLARI

Anayasa "ne" der; bu bölüm "kod yazarken nasıl" der. Yeni yazdığın koda ve review'a uygula.

## 0. Kapsam: yazdığın koda uygula, mevcut kodu drive-by düzeltme

Stil maddeleri (isim, magic number, tip) **senin yazdığın** ya da zaten başka sebeple
değiştirdiğin satırlara uygulanır. Sırf kurala uymuyor diye eski satırı yeniden yazma.

- **Zaten kuralı ihlal eden mevcut kod:** başka iş için dokunmuyorsan olduğu gibi bırak.
- **Yeni kod:** baştan temiz form.
- **Gerçek bug** (determinizm sızıntısı, ışık bütçesi deliği) görürsen sessizce
  düzeltme; kullanıcıya **bildir**. Rapor kapsam içi, habersiz refactor değil.

## 1. Renk = palet token'ı, ham `Color()` değil

12 renk kilitli. Yeni renk **merkezi palet modülünden** çekilir. Dosyaya gömülü ham hex
(`Color("5a3f52")`) ya da float (`Color(0.82, 0.63, 0.67)`) magic renk **yeni kodda yasak**.

```gdscript
# ❌ Palete bağlı olmayan magic renk — denetlenemez, %10-sarı kuralı uygulanamaz
draw_rect(r, Color(0.82, 0.63, 0.67, 0.16))

# ✅ Palet token'ı; alpha/ışık baz rengi modüle ederek
draw_rect(r, Palette.MAUVE * Color(1, 1, 1, 0.16))
```

Yeni ton eklemek = paleti genişletmek = anayasa ihlali → önce kullanıcıya sor.
(Bu, "raw değer yerine token" prensibinin Godot karşılığı.)

## 2. Magic number'ları yerelde isimlendir

Anlam taşıyan sayı (eşik, oran, kapasite) `const` olur.

```gdscript
# ❌ 40 ne? 0.10 ne?
if pop > 40 and Rng.hf(tick) < 0.10:

# ✅
const BIRTH_CHANCE := 0.10
const CROWD_POP := 40
if pop > CROWD_POP and Rng.hf(tick) < BIRTH_CHANCE:
```

İstisna: aynı satırda apaçık `0`, `1`, `0.5`.

## 3. Tekrar eden formül/değer TEK KAYNAK

Aynı formül iki yere kopyalanmışsa biri değişince diğeri sessizce çatlar → helper'a çıkar.

```gdscript
# ❌ light_curve iki yerde birebir kopya (drift riski)
light_curve = ev * (1.0 - sleep * 0.55)

# ✅ tek kaynak
func _compute_light_curve(t24: float) -> float:
    return _evening(t24) * (1.0 - _sleep_amount(t24) * 0.55)
```

Bir değer birden çok yerde geçiyorsa isim ver; tek yerde geçiyorsa (madde 6) inline bırak.

## 4. Tipli değişkenler (compile-time > runtime)

`var x = ...` yerine `var x: Type` ya da çıkarımlı `:=`.

```gdscript
# ❌
var cur = world.building_now
var pos = world.grant_wish()

# ✅
var cur := world.building_now
var pos: Dictionary = world.grant_wish()
var building_now: Variant = null   # null'da := çalışmaz → açık tip
```

## 5. İsim = içindeki değer, mekanizma değil

| ❌ Mekanizma | ✅ İçerik |
|---|---|
| `selected_key_state` (dil tutuyor) | `selected_language` |
| `buttons` (alfabe tutuyor) | `ALPHABET` |
| `curBtns` | `current_letters` |

Modül-seviye değişmez veri (dizi/sözlük) `SCREAMING_SNAKE_CASE` + içerik adı:
`const SEASONS`, `const NAME_POOL`, `const ALPHABET`.

## 6. Tek-kullanımlık değişkeni inline et

Dosyada tam bir kez kullanılan değişken gürültüdür; saran fonksiyon/sınıf adı anlamı verir.
İstisna: aynı değer birden çok yerde → isim ver (madde 3).

## 7. İnce sarmalayıcı yazma

Tek satırlık işi saran ekstra fonksiyon/dosya katman ekler, mantık eklemez → inline et.

- Gövdesi tek `for ... draw_` olan çizim helper'ı → çağrı yerinde çiz.
- Kendi mantığı olmayan `match` dispatcher → tüketici doğrudan atom'u çağırsın.

Kural: sarmalayıcı çağıran başına **≥5 satır** kazandırıyorsa ya da non-trivial
state/sıralama gizliyorsa dosyasını hak eder.

## 8. Büyük modül-seviye veri → ayrı dosya

Statik lookup/alfabe/config dosyanın ilk ekranını asıl mantıktan uzaklaştırıyorsa ayrı
dosyaya taşı (`constants.gd`, `palette.gd`). ~30 satır veriyi geçip koda ulaşıyorsan çıkar.

## 9. Sessizce veri düşürme — hatayı görünür kıl

Save/load ya da parse ederken bozuk veriyi sessizce yutma; güvenli default'a düş ve **logla**.

```gdscript
# ❌ sebep kaybolur
var d = JSON.parse_string(txt)
if d == null: return

# ✅ sebep görünür
var d: Variant = JSON.parse_string(txt)
if d == null:
    push_warning("[load] save.json parse edilemedi, default'a dönülüyor")
    return _default_state()
```

## 10. Yorumlar: seyrek, "neden", Türkçe

Default yorum YOK. Sadece dört durumda: (1) gizli kısıt (determinizm hash'i, ışık
eşiği), (2) sezgiye aykırı seçim, (3) bug/geçici workaround (ne zaman kalkacağını yaz),
(4) şaşırtıcı davranış. WHAT değil WHY. Türkçe. Tek satır `#`; uzun açıklama dokümanlara.

## 11. Reuse-first

Yeni çizim/sistem yazmadan önce `world.gd`, `town_view.gd`, `Rng`, mevcut partikül/olay
sistemleri işi görüyor mu bak. Kopyala-yapıştır magic renk/formül değil, mevcut helper'ı çağır.

---

# BÖLÜM 3 — ÇALIŞMA DÖNGÜSÜ

## Doğrulama zorunlu: sayılar tutmadan "güzel oldu" deme

Her görevde, commit öncesi:

1. `godot --headless --check-only` → script derleniyor mu (ZORUNLU).
2. **Görsel iş:** export → screenshot → piksel denetimi (parlaklık gündüz~115 /
   akşam~90 / gece~70; sıcaklık R−B>0; value aralığı>60). Ölçmeden "güzel" deme.
3. **Sim iş:** `stepWorld×N` → 30 günde nüfus 20-90 bandında; çökme (=0) ya da
   patlama (>150) = regresyon.
4. `tools/verify.sh` (check/sim/visual) yeşil.
5. Görev sonunda `JUICE_YAPILACAKLAR.md`'de maddeyi işaretle; öğrenilen kuralı
   `DEVIR_TESLIM.md`'ye ekle.

## Atomik commit'ler, Türkçe mesaj

Her commit tek mantıksal iş; kendi başına derlenir, yarım iş bırakmaz, bağımsız revert
edilebilir. Mesaj Türkçe, imperative: `juice: lamba kaskadı PointLight2D`. Gövde *neden*'i
anlatır. "Consumer geçişi + eski kod silme" **aynı** commit'tir (ayırma → ölü kod / kırık import).

---

# HIZLI REVIEW CHECKLIST

- [ ] `randi/randf/randomize` yok, rastgelelik `Rng.h/hf`
- [ ] Yeni renk `Palette.*`'tan; dosyaya gömülü ham `Color(...)` yok
- [ ] Yeni ışık kaynağı bütçeden düşülmüş (`min(1, 14/ışık)`)
- [ ] Magic number'lar isimli `const`
- [ ] Tekrar eden formül/değer tek kaynak
- [ ] Değişkenler tipli (`:=` ya da `var x: T`)
- [ ] İsimler içeriği anlatıyor; modül sabiti `SCREAMING_SNAKE`
- [ ] Tek-kullanımlık değişken inline; ince sarmalayıcı yok
- [ ] Sim (`world.gd`) saf kaldı, render sızmadı
- [ ] Save/load bozuk veriyi sessizce yutmuyor
- [ ] Yorumlar seyrek + Türkçe + "neden"
- [ ] Ses %100 sentez, telifsiz
- [ ] `verify.sh` (check/sim/visual) yeşil; sayılar tutuyor
- [ ] Cozy: ceza/FOMO/suçluluk yok; çekirdek zorunlu mekanikle kirlenmedi
- [ ] Commit atomik + Türkçe mesaj
