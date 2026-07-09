class_name Letters
extends RefCounted
## Mektup şablon havuzu (Faz D — içerik derinliği; "1 haftada bitti" şikâyetine panzehir).
## Parametrik {name} formatı: i18n'e hazır (Faz E tid'den yeniden render edecek).
## SEÇİM DETERMİNİST: pick(pool, salt) — salt world._h'ten gelir, randi YASAK.
## Ton: Rain City cozy — nazik, birinci tekil, kısa; suçluluk/aciliyet ASLA yok.

# ---- VEDA (yıldızlara karışan bilge; duygusal çekirdek) ----
const VEDA := [
	"Bu kasabada güzel bir ömür geçirdim. Penceremden hep senin ışıklarını izledim. Çayırdaki ağacıma ara sıra uğra, olur mu?",
	"Giderken ardımda bir bahçe, birkaç iyi komşu ve sana bu mektubu bırakıyorum. İyi ki büyüttün burayı.",
	"Küçükken kule çalınca pencereye koşardım. Bu akşam son kez dinledim; hâlâ aynı güzellikte. Teşekkür ederim.",
	"Yağmurlu günleri en çok severdim. Damların sesini benim için de dinle. Ben artık yıldızların arasındayım.",
	"Kimseye söylemedim ama en sevdiğim yer çeşmenin başıydı. Orada bir taş var, altında sana bir dilek bıraktım.",
	"Meydandaki konserleri, komşu kapılarında biten akşamları, dere kenarındaki sohbetleri... Hepsini yanıma alıyorum.",
	"Sen çalışırken kasaba büyüdü; ben büyürken kasaba hep yanımdaydı. Şimdi sıra bende: yukarıdan ışık tutacağım.",
	"Torunlarıma anlatacak çok şeyim oldu bu sokaklarda. Ağacımın gölgesinde dinlenen olursa, benden selam söyle.",
	"Son isteğim: kimse benim için üzülmesin. Çayıra bir ağaç dikin, kuşlar konsun yeter.",
	"Hayatım boyunca tek bir sırrım oldu: her sabah kuleye bakıp 'bugün de güzel olacak' derdim. Hep oldu.",
	"Elveda demeyeceğim; kasabanın rüzgârında, derenin sesinde, lambaların ilk tutuşmasında ben de olacağım.",
	"Defterimin son sayfasına şunu yazdım: 'İyi yaşadım, iyi komşularım oldu, kasabam beni sevdi.' Ne mutlu bana.",
]
# atkı sahibi (yanıtlanmış bağ) vedası — kişisel dokunuş
const VEDA_ATKI := [
	"Hediye ettiğin atkıyla geldim bu son yolculuğa. Sıcaklığı hep üstümde. Sana minnettarım.",
	"Mektubuma yanıt yazdığın gün, hayatımın en güzel günlerinden biriydi. Atkın omzumda, gönlüm rahat gidiyorum.",
	"Atkımı anı ağacımın dalına asın. Üşüyen bir kuş olur belki; benim gibi ısınsın.",
]

# ---- ODAK (seans kutlaması — kasaba halkından) ----
const ODAK := [
	"Bugün masanda çalışırken hepimiz hissettik: birlikte üretiyoruz. Meydanda senin için bir kutlama yaptık.",
	"Sen odaklanınca sokaklar bile sakinleşiyor. Bu huzur için teşekkürler.",
	"Fırıncı bugünkü ilk somunu senin adına ayırdı. 'Emeğe saygı' dedi, başka bir şey demedi.",
	"Çocuklar pencerenin altından geçerken fısıldaşıyor: 'Şşşt, çalışıyor.' Sonra kıkırdayıp koşuyorlar.",
	"Seansın bitince kule bir kez fazladan çaldı — duydun mu? O bizim alkışımızdı.",
	"Bugün derenin suyu daha berrak aktı sanki. İhtiyar Salih 'çalışan bir dost varken böyle olur' diyor.",
	"Meydanda toplandık, senin penceren yanarken gökyüzüne baktık. İyi ki varsın.",
	"Marangoz yeni bir tabela astı: 'Bu kasaba emekle büyür.' Hepimiz altına imza attık.",
	"Sen çalışırken kasabaya bir kuş sürüsü uğradı. Kuleye kondular, dinlediler, sonra selam verip gittiler.",
	"Bugünkü emeğin şerefine akşam herkes fenerini biraz erken yaktı. Kasaba senin için parladı.",
	"Kimse söylemedi ama herkes biliyor: bu kasabanın kalbi senin masanda atıyor.",
	"Bir bardak ıhlamur bıraktık kapına. Soğumadan iç; sonrası yine bizden.",
]

# ---- DİLEK TEŞEKKÜRLERİ (dilek tipine göre) ----
const DILEK := {
	"çeşme": [
		"Çeşmenin sesi geceleri pencereme geliyor. Su gibi aziz ol.",
		"Bu sabah çeşmeden ilk suyu ben içtim. Buz gibiydi, şeker gibiydi. Ellerine sağlık.",
		"Kuşlar çeşmenin başını çok sevdi. Artık her sabah şarkılı uyanıyorum. Teşekkürler.",
		"Komşular çeşmenin başında buluşup sohbet ediyor artık. Bir taş, bir su — bir mahalle kurdun.",
		"Çocuklar sıcak günlerde çeşmede serinliyor. Kahkahalarını duydukça seni anıyorum.",
	],
	"ağaç": [
		"Diktiğin ağacın ilk yaprağını kitabımın arasına koydum.",
		"Ağacın gölgesi tam penceremin önüne düşüyor. Öğlen uykularım artık serin. Minnettarım.",
		"Bu sabah ağaca bir serçe yuva yapmaya başladı. Ev evi çeker derler; doğruymuş.",
		"Ağacın altına küçük bir bank koydum. İlk oturan sen ol istedim ama komşu kaptı bile.",
		"Yıllar sonra bu ağaç kocaman olacak ve ben 'onu sana bir dost dikti' diye anlatacağım.",
	],
	"fener": [
		"Artık eve dönerken karanlıktan korkmuyorum. Fenerin için teşekkürler.",
		"Fener yanınca kapımın önü bal rengine boyanıyor. Her akşam içim ısınıyor.",
		"Dün gece fenerin ışığında kitap okudum kapı önünde. Yıldızlar kıskandı.",
		"Kedim artık fenerin altında uyuyor. İkimiz de sana minnettarız.",
		"Geceleri fenerin ışığı camda dans ediyor. Karanlığı değil, artık gölgelerin oyununu izliyorum.",
	],
	"bank": [
		"Bank geldi ve hayatım değişti: artık akşamları oturup kasabayı izliyorum. Sen de gel bir gün.",
		"İhtiyar dizlerim sana dua ediyor. Bankta oturup gelene geçene selam veriyorum.",
		"Bugün bankta bir yabancıyla sohbet ettim; komşu olduk. Bir tahta parçası neler yapıyor.",
		"Bankın üstüne bir yastık koydum. Resmen benim köşem artık. Teşekkürler.",
	],
	"kuş yuvası": [
		"Yuvaya ilk kiracı taşındı: kırmızı gagalı bir serçe. Sabahları beni o uyandırıyor artık.",
		"Kuş yuvasını her sabah kontrol ediyorum. Bugün üç minik yumurta vardı. Heyecandan uyuyamıyorum.",
		"Kışın kuşlara ekmek kırıntısı bırakıyorum; yuvan sayesinde bahçem şarkı dolu.",
		"Torunuma yuvadaki kuşları gösterdim; gözleri kocaman oldu. Bu hediye ikimize.",
	],
	"posta kutusu": [
		"Posta kutuma ilk mektup düştü! Kimden mi? Senden — bu mektup. Döngü tamamlandı.",
		"Artık mektuplarım yağmurda ıslanmıyor. Kapı önünde kutuyu her görüşümde gülümsüyorum.",
		"Komşu çocuklar kutuma çizimler bırakıyor. Küçük bir sanat galerim oldu.",
		"Kutunun üstüne adımı yazdım. Küçük şey ama insana 'buradayım' dedirtiyor.",
	],
	"rüzgâr gülü": [
		"Rüzgâr gülü dönerken izliyorum; rüzgârın yönünü değil, zamanın geçişini gösteriyor sanki.",
		"Fırtına gelmeden gül hızlanıyor; çamaşırları hep vaktinde topluyorum artık. Ellerine sağlık.",
		"Çatıdaki gül gıcırdamıyor bile — usta işi. Kuşlar tepesine konup dönmesini bekliyor.",
		"Rüzgâr gülünü penceremden görüyorum. Döndükçe kasaba yaşıyor diyorum içimden.",
	],
}

# ---- TAŞINMA (yeni gelen aile / yuva kuran genç) ----
const TASINMA := [
	"Uzaktan geldik, kimseyi tanımıyorduk. Daha ilk akşam kapımıza sıcak çorba bırakıldı. İyi bir yer burası.",
	"Yeni evimizin penceresinden kule görünüyor. Çocuğum her saat başı 'bizim şarkımız!' diye sevincinden zıplıyor.",
	"Bavulları açarken komşular yardıma geldi. Eşyadan çok gülüşme taşıdık. Teşekkür ederiz.",
	"Kendi yuvam ilk kez. Duvarları ben boyadım, yamuk oldu ama benim. Bu kasabada büyümek güzeldi.",
	"Buraya taşınmadan önce 'küçük bir kasaba işte' demiştim. Yanılmışım: burası küçük değil, sıcak.",
	"İlk sabah dere sesiyle uyandım. Sanki kasaba 'hoş geldin' diyordu.",
	"Anahtar elime geçtiğinde ellerim titredi. Şimdi bahçeye çiçek ekiyorum. Kök salıyoruz.",
	"Yeni komşum kapıda dedi ki: 'Burada kimse yalnız kalmaz.' Şimdiden inandım.",
]

# ---- DOĞUM (yeni ebeveynden) ----
const DOGUM := [
	"Bebeğimiz bu sabah gözlerini açtı. İlk gördüğü şey pencereden süzülen kasaba ışıklarıydı.",
	"Adını koyarken kulenin çalmasını bekledik. Melodi bitince fısıldadık. Artık o da bu kasabanın şarkısıyla büyüyecek.",
	"Komşular kapıya minik patikler bırakmış. Kimin ördüğünü bilmiyoruz; bu kasabada iyilik imzasız geliyor.",
	"Gece beşikte sallarken fenerin ışığı içeri vuruyor. İkimiz de o zaman sakinleşiyoruz.",
	"Bugün bebeğimiz ilk kez güldü — tam kule çalarken. Bu kasabada zamanlama diye buna denir.",
	"Bir gün ona anlatacağız: 'Sen doğduğunda kasaba küçüktü; seninle birlikte büyüdü.'",
	"Eve yeni bir ses geldi. Dere, kule ve cırcırlardan sonra en güzel dördüncü ses.",
	"Beşiğini pencereye yakın koyduk; yıldızları erken tanısın istedik.",
]

# ---- UZUN-VADE ANLARI (tek seferlik; milestone anahtarıyla) ----
const AN := {
	"gun30": "Bugün kasabamızın 30. günü. Meydanda sessiz bir kutlama yaptık: herkes bir mum yaktı, kule bir kez çaldı. İlk günden beri yanımızda olduğun için — iyi ki.",
	"sakin100": "Bugün aramıza katılan 100. komşumuzu karşıladık. Yüz isim, yüz hikâye, tek kasaba. Defterin ilk sayfasına senin adını yazdık: 'Kuran kişi.'",
	"veda50": "Bugün 50. anı ağacımızı diktik. Çayır artık bir koru — her ağaç bir hayat, her yaprak bir hatıra. Onları unutmadığın için teşekkür ederiz.",
	"butunlendi": "Kasaba bütünlendi. Son evin bacası bu akşam ilk dumanını tüttürdü. Artık kimse 'keşke bir evimiz olsa' demiyor. Bundan sonrası süsleme, şenlik ve keyif: kasaba senin emeğinle TAMAM. Sağ ol.",
	# kasaba ünvan atlamaları (G1.4 — nüfus eşikleri; tabela değişir, meydan şenlenir)
	"tier_koy": "Duydun mu? Artık resmen bir KÖY'üz! Yirmi beş kişi olduk; girişe tabela astık, altına herkes adını kazıdı. En üste de seninkini — kuran kişi.",
	"tier_buyuk_koy": "Altmış kişiyi geçtik — haritacılar artık bize BÜYÜK KÖY diyor. Fırıncı 'ekmek yetişmiyor' diye tatlı tatlı söyleniyor. Büyüdük, ama meydandaki akşam sohbetleri hâlâ aynı sıcak.",
	"tier_kasaba": "Bugün nüfus defterine 100. adı yazdık: artık bir KASABA'yız! Kule öğlen fazladan bir kez çaldı, çocuklar bunun ne demek olduğunu sordu. 'Birlikte büyüdük demek' dedik.",
	"tier_kucuk_sehir": "Yüz elli kişi... Gezginler artık yol tariflerinde bizi 'o KÜÇÜK ŞEHİR' diye anlatıyormuş. Sokak isimlerimiz oldu, bir de akşamları köşede saz çalan biri. Hepsi senin sabrınla.",
	"tier_sehir": "İki yüz yirmi komşu. Resmî haritada adımızın yanına ŞEHİR yazıldı — ama biz aramızda hâlâ 'bizim kasaba' diyoruz. Bazı şeyler hiç değişmesin, değil mi?",
}

# ---- GÜN OLAYLARI (G1.8 — hediye olayların mektupları) ----
const OLAY := {
	"tuccar": "Yollardan geçen bir tüccarım. Kasabanızda bir gece konakladım; kulenizin melodisi ve insanların güleryüzü için meydana küçük bir hediye bıraktım. Yolum yine düşer.",
	"dugun": "Bugün evlendik! Bütün kasaba meydandaydı; kule bizim için fazladan bir kez çaldı. Yeni evimizin penceresinden ilk baktığımız şey senin ışığındı. Mutluluğumuzda payın var.",
	"gocebe": "Merhaba. Uzaktan yazıyoruz — kasabanızın ışıklarını tepelerden gördük, insanların birbirine iyi davrandığını duyduk. Yarın geliyoruz. Bize küçük bir yer var mı? Not: taze reçel getiriyoruz.",
	"ziyaretci": "Ben Işık Toplayıcısı'yım. Kasabaların ışıklarını ve melodilerini toplarım. Seninki... seninki farklıydı. Fenerimde artık senin kulendin ezgisi de var. Bir gün yine geleceğim — o zamana dek ışığın hiç sönmesin.",
}

# ---- MEVSİM FESTİVALLERİ (her mevsim ortasında bir; kasaba halkından davet mektubu) ----
const FESTIVAL := [
	"Bugün Çiçek Günü! Meydan taçyaprağı içinde; çocuklar birbirinin saçına çiçek takıyor. En güzel taç senin masana bırakıldı.",
	"Dere Şenliği başladı! Herkes kıyıya indi; kâğıttan kayıklar yarışıyor, ayaklar suda. Senin kayığını da biz yüzdürdük — birinci geldi.",
	"Hasat Akşamı bu gece. Meydanda uzun bir sofra kurduk; balkabağı çorbası ve taze ekmek. Tabağın hep dolu, yerin hep ayrılmış.",
	"Fener Gecesi! Bütün kasaba el yapımı fenerlerle sokakta. Kar sessizce yağıyor, ışıklar süzülüyor. En büyük feneri kuleye senin adına astık.",
]

# ---- BOND EKİ (bağ yüksekken mektup sonuna eklenen not) ----
const BOND_EK := [
	"\n\nNot: Kasabada senin adın geçince herkes gülümsüyor, bilesin.",
	"\n\nNot: Bu mektubu yazarken komşular da selam söyledi.",
	"\n\nNot: Sen bu kasabanın en eski dostusun artık.",
	"\n\nNot: Kule bu akşam senin için bir kez fazladan çalacak; biz ayarladık.",
]

## Determinist seçim — salt world._h'ten gelmeli (aynı tohum = aynı mektup).
static func pick(pool: Array, salt: int) -> String:
	return pool[Rng.h(salt) % pool.size()]
