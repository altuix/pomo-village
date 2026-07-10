class_name Letters
extends RefCounted
## Mektup şablon havuzları — TR/EN çift dilli (H1 i18n içerik tamamlama).
## Her havuz { "tr": [...], "en": [...] } (anahtarlılar { "tr": {k: v}, "en": {k: v} }).
## SEÇİM DETERMİNİST: pick(pool, salt) — salt world._h'ten gelir, randi YASAK.
## Aynı tohum + aynı dil = aynı mektup (dil-içi determinizm; mektup üretim anındaki dilde save'e girer).
## Ton: Rain City cozy — nazik, birinci tekil, kısa; suçluluk/aciliyet ASLA yok.
## EN metinler düz çeviri değil: aynı duygusal çekirdek, İngilizce'de yeniden yazım.

# ---- VEDA (yıldızlara karışan bilge; duygusal çekirdek) ----
const VEDA := {
	"tr": [
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
	],
	"en": [
		"I lived a good life in this town. From my window I always watched your lights. Stop by my tree in the meadow now and then, will you?",
		"I leave behind a garden, a few good neighbors, and this letter for you. I'm glad you grew this place.",
		"As a child I'd run to the window when the tower rang. Tonight I listened one last time; it's as lovely as ever. Thank you.",
		"Rainy days were my favorite. Listen to the rooftops for me sometime. I'm among the stars now.",
		"I never told anyone, but my favorite spot was by the fountain. There's a stone there — under it, I left you a wish.",
		"The concerts in the square, the evenings that ended at neighbors' doors, the talks by the stream... I'm taking them all with me.",
		"While you worked, the town grew; while I grew, the town was always beside me. Now it's my turn: I'll hold a light for you from up there.",
		"These streets gave me so many stories to tell my grandchildren. If anyone rests in the shade of my tree, say hello from me.",
		"My last wish: let no one be sad for me. Plant a tree in the meadow and let the birds land on it — that's enough.",
		"All my life I kept one little secret: every morning I'd look at the tower and say 'today will be lovely too.' It always was.",
		"I won't say goodbye; I'll be in the town's wind, in the sound of the stream, in the first flicker of the lamps.",
		"On the last page of my notebook I wrote: 'I lived well, I had good neighbors, my town loved me.' How lucky I was.",
	],
}
# atkı sahibi (yanıtlanmış bağ) vedası — kişisel dokunuş
const VEDA_ATKI := {
	"tr": [
		"Hediye ettiğin atkıyla geldim bu son yolculuğa. Sıcaklığı hep üstümde. Sana minnettarım.",
		"Mektubuma yanıt yazdığın gün, hayatımın en güzel günlerinden biriydi. Atkın omzumda, gönlüm rahat gidiyorum.",
		"Atkımı anı ağacımın dalına asın. Üşüyen bir kuş olur belki; benim gibi ısınsın.",
	],
	"en": [
		"I set out on this last journey wearing the scarf you gave me. Its warmth never left my shoulders. I'm grateful to you.",
		"The day you answered my letter was one of the finest days of my life. Your scarf around me, I go with a peaceful heart.",
		"Hang my scarf on a branch of my memory tree. Maybe a cold little bird will find it and be warm, the way I was.",
	],
}

# ---- ODAK (seans kutlaması — kasaba halkından) ----
const ODAK := {
	"tr": [
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
	],
	"en": [
		"While you worked at your desk today, we all felt it: we're building this together. We held a little celebration for you in the square.",
		"When you focus, even the streets grow calm. Thank you for this peace.",
		"The baker set aside the first loaf of the day in your name. 'Respect for good work,' was all he said.",
		"The children whisper as they pass under your window: 'Shhh, they're working.' Then they giggle and run off.",
		"When your session ended, the tower rang one extra time — did you hear it? That was our applause.",
		"The stream ran clearer today, I'm sure of it. Old Salih says 'that's what happens when a friend is hard at work.'",
		"We gathered in the square and watched the sky while your window glowed. Glad you're here.",
		"The carpenter hung a new sign: 'This town grows by honest work.' We all signed our names beneath it.",
		"A flock of birds visited while you worked. They perched on the tower, listened a while, then tipped their wings and flew on.",
		"In honor of today's work, everyone lit their lanterns a little early. The town glowed for you.",
		"Nobody says it out loud, but everyone knows: this town's heart beats at your desk.",
		"We left a cup of linden tea at your door. Drink it while it's warm; the rest is on us, as always.",
	],
}

# ---- DİLEK TEŞEKKÜRLERİ (dilek tipine göre; anahtarlar sim durumu — TR kalır) ----
const DILEK := {
	"tr": {
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
	},
	"en": {
		"çeşme": [
			"The sound of the fountain drifts up to my window at night. Bless you for it.",
			"This morning I drank the first water from the fountain. Cold as ice, sweet as sugar. Bless your hands.",
			"The birds adore the fountain. I wake to their songs every morning now. Thank you.",
			"The neighbors gather at the fountain to chat now. One stone, a little water — and you built us a neighborhood.",
			"The children cool off at the fountain on hot days. Every time I hear their laughter, I think of you.",
		],
		"ağaç": [
			"I pressed the first leaf of the tree you planted between the pages of my book.",
			"The tree's shade falls right across my window. My midday naps are cool now. I'm grateful.",
			"A sparrow started building a nest in the tree this morning. A home draws a home, they say; it's true.",
			"I put a little bench under the tree. I wanted you to be the first to sit on it, but a neighbor beat you to it.",
			"Years from now this tree will be enormous, and I'll tell everyone: 'a friend planted it for me.'",
		],
		"fener": [
			"I'm not afraid of the dark on my way home anymore. Thank you for the lantern.",
			"When the lantern lights up, my doorstep turns the color of honey. It warms me through, every evening.",
			"Last night I read a book by lantern light on my doorstep. The stars were jealous.",
			"My cat sleeps under the lantern now. We're both grateful to you.",
			"At night the lantern light dances on my window. I don't watch the dark anymore — I watch the shadows play.",
		],
		"bank": [
			"The bench arrived and my life changed: now I sit in the evenings and watch the town. Come join me someday.",
			"These old knees of mine bless you daily. I sit on the bench and greet everyone who passes.",
			"Today I chatted with a stranger on the bench; now we're neighbors. What a little plank of wood can do.",
			"I put a cushion on the bench. It's officially my corner now. Thank you.",
		],
		"kuş yuvası": [
			"The first tenant moved into the birdhouse: a sparrow with a red beak. It wakes me every morning now.",
			"I check the birdhouse every morning. Today there were three tiny eggs. I can hardly sleep from excitement.",
			"In winter I leave breadcrumbs for the birds; thanks to your birdhouse, my garden is full of song.",
			"I showed my grandchild the birds in the nest; their eyes went wide. This gift is for both of us.",
		],
		"posta kutusu": [
			"The first letter landed in my mailbox! From whom, you ask? From you — this very letter. The circle is complete.",
			"My letters don't get soaked in the rain anymore. I smile every time I see the box by my door.",
			"The neighborhood kids leave little drawings in my box. I have my own art gallery now.",
			"I wrote my name on the box. A small thing, but it lets a person say: 'I'm here.'",
		],
		"rüzgâr gülü": [
			"I watch the weathervane turn; it doesn't show the wind's direction so much as the passing of time.",
			"The vane spins faster before a storm; I always bring the laundry in on time now. Bless your hands.",
			"The vane on the roof doesn't even creak — fine craftsmanship. Birds perch on top and wait for it to turn.",
			"I can see the weathervane from my window. As long as it turns, I tell myself, the town is alive.",
		],
	},
}

# ---- TAŞINMA (yeni gelen aile / yuva kuran genç) ----
const TASINMA := {
	"tr": [
		"Uzaktan geldik, kimseyi tanımıyorduk. Daha ilk akşam kapımıza sıcak çorba bırakıldı. İyi bir yer burası.",
		"Yeni evimizin penceresinden kule görünüyor. Çocuğum her saat başı 'bizim şarkımız!' diye sevincinden zıplıyor.",
		"Bavulları açarken komşular yardıma geldi. Eşyadan çok gülüşme taşıdık. Teşekkür ederiz.",
		"Kendi yuvam ilk kez. Duvarları ben boyadım, yamuk oldu ama benim. Bu kasabada büyümek güzeldi.",
		"Buraya taşınmadan önce 'küçük bir kasaba işte' demiştim. Yanılmışım: burası küçük değil, sıcak.",
		"İlk sabah dere sesiyle uyandım. Sanki kasaba 'hoş geldin' diyordu.",
		"Anahtar elime geçtiğinde ellerim titredi. Şimdi bahçeye çiçek ekiyorum. Kök salıyoruz.",
		"Yeni komşum kapıda dedi ki: 'Burada kimse yalnız kalmaz.' Şimdiden inandım.",
	],
	"en": [
		"We came from far away and knew no one. On our very first evening, warm soup appeared at our door. This is a good place.",
		"The tower shows from our new home's window. Every hour, my child jumps for joy: 'that's our song!'",
		"The neighbors came to help as we unpacked. We carried more laughter than furniture. Thank you.",
		"A nest of my own, for the first time. I painted the walls myself — a little crooked, but mine. It was good to grow up in this town.",
		"Before moving here I said 'it's just a small town.' I was wrong: this place isn't small, it's warm.",
		"That first morning I woke to the sound of the stream. It was as if the town was saying 'welcome.'",
		"My hands trembled when the key was placed in them. Now I'm planting flowers in the garden. We're putting down roots.",
		"My new neighbor said at the door: 'No one stays lonely here.' I already believe it.",
	],
}

# ---- DOĞUM (yeni ebeveynden) ----
const DOGUM := {
	"tr": [
		"Bebeğimiz bu sabah gözlerini açtı. İlk gördüğü şey pencereden süzülen kasaba ışıklarıydı.",
		"Adını koyarken kulenin çalmasını bekledik. Melodi bitince fısıldadık. Artık o da bu kasabanın şarkısıyla büyüyecek.",
		"Komşular kapıya minik patikler bırakmış. Kimin ördüğünü bilmiyoruz; bu kasabada iyilik imzasız geliyor.",
		"Gece beşikte sallarken fenerin ışığı içeri vuruyor. İkimiz de o zaman sakinleşiyoruz.",
		"Bugün bebeğimiz ilk kez güldü — tam kule çalarken. Bu kasabada zamanlama diye buna denir.",
		"Bir gün ona anlatacağız: 'Sen doğduğunda kasaba küçüktü; seninle birlikte büyüdü.'",
		"Eve yeni bir ses geldi. Dere, kule ve cırcırlardan sonra en güzel dördüncü ses.",
		"Beşiğini pencereye yakın koyduk; yıldızları erken tanısın istedik.",
	],
	"en": [
		"Our baby opened her eyes this morning. The first thing she saw was the town lights drifting in through the window.",
		"We waited for the tower to ring before giving him his name. When the melody ended, we whispered it. Now he too will grow up with this town's song.",
		"The neighbors left tiny knitted booties at our door. We don't know whose hands made them; kindness comes unsigned in this town.",
		"Rocking the cradle at night, the lantern light spills in. That's when we both grow calm.",
		"Today our baby smiled for the first time — right as the tower rang. That's what we call timing in this town.",
		"One day we'll tell her: 'When you were born the town was small; it grew up with you.'",
		"A new sound has come to our home. The loveliest fourth, after the stream, the tower, and the crickets.",
		"We set the cradle close to the window; we wanted the stars to be early friends.",
	],
}

# ---- UZUN-VADE ANLARI (tek seferlik; milestone anahtarıyla) ----
const AN := {
	"tr": {
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
	},
	"en": {
		"gun30": "Today is our town's 30th day. We held a quiet celebration in the square: everyone lit a candle, and the tower rang once. For being with us since the very first day — we're glad it's you.",
		"sakin100": "Today we welcomed the 100th neighbor to join us. A hundred names, a hundred stories, one town. On the first page of the ledger, we wrote your name: 'The one who built it.'",
		"veda50": "Today we planted our 50th memory tree. The meadow is a grove now — every tree a life, every leaf a memory. Thank you for never forgetting them.",
		"butunlendi": "The town is whole. The last house's chimney breathed its first smoke this evening. No one says 'if only we had a home' anymore. From here on, it's all garlands, festivals and joy: the town is COMPLETE, built by your effort. Thank you.",
		"tier_koy": "Have you heard? We're officially a VILLAGE now! Twenty-five of us; we hung a sign at the entrance and everyone carved their name below it. Yours went at the very top — the one who built it.",
		"tier_buyuk_koy": "We've passed sixty souls — the mapmakers call us a LARGE VILLAGE now. The baker grumbles sweetly that 'the bread can't keep up.' We've grown, but the evening talks in the square are as warm as ever.",
		"tier_kasaba": "Today we wrote the 100th name in the ledger: we're a TOWN now! The tower rang an extra time at noon, and the children asked what it meant. 'It means we grew up together,' we said.",
		"tier_kucuk_sehir": "A hundred and fifty of us... Travelers giving directions now call us 'that SMALL CITY.' We have street names now, and someone who plays the saz on the corner in the evenings. All of it grown from your patience.",
		"tier_sehir": "Two hundred and twenty neighbors. On the official map they've written CITY beside our name — but between us, we still say 'our little town.' Some things should never change, don't you think?",
	},
}

# ---- GÜN OLAYLARI (G1.8 — hediye olayların mektupları) ----
const OLAY := {
	"tr": {
		"tuccar": "Yollardan geçen bir tüccarım. Kasabanızda bir gece konakladım; kulenizin melodisi ve insanların güleryüzü için meydana küçük bir hediye bıraktım. Yolum yine düşer.",
		"dugun": "Bugün evlendik! Bütün kasaba meydandaydı; kule bizim için fazladan bir kez çaldı. Yeni evimizin penceresinden ilk baktığımız şey senin ışığındı. Mutluluğumuzda payın var.",
		"gocebe": "Merhaba. Uzaktan yazıyoruz — kasabanızın ışıklarını tepelerden gördük, insanların birbirine iyi davrandığını duyduk. Yarın geliyoruz. Bize küçük bir yer var mı? Not: taze reçel getiriyoruz.",
		"ziyaretci": "Ben Işık Toplayıcısı'yım. Kasabaların ışıklarını ve melodilerini toplarım. Seninki... seninki farklıydı. Fenerimde artık senin kulendin ezgisi de var. Bir gün yine geleceğim — o zamana dek ışığın hiç sönmesin.",
	},
	"en": {
		"tuccar": "I'm a merchant of the roads. I stayed a night in your town; for your tower's melody and your people's kind faces, I left a small gift in the square. My road will bring me back.",
		"dugun": "We got married today! The whole town was in the square; the tower rang an extra time just for us. The first thing we saw from our new home's window was your light. You are part of our happiness.",
		"gocebe": "Hello. We write from far away — we saw your town's lights from the hills, and heard how kindly people treat one another. We arrive tomorrow. Might there be a small place for us? P.S. we're bringing fresh jam.",
		"ziyaretci": "I am the Light Collector. I gather the lights and melodies of towns. Yours... yours was different. Your tower's tune lives in my lantern now. I will come again someday — until then, may your light never go out.",
	},
}

# ---- MEVSİM FESTİVALLERİ (her mevsim ortasında bir; kasaba halkından davet mektubu) ----
const FESTIVAL := {
	"tr": [
		"Bugün Çiçek Günü! Meydan taçyaprağı içinde; çocuklar birbirinin saçına çiçek takıyor. En güzel taç senin masana bırakıldı.",
		"Dere Şenliği başladı! Herkes kıyıya indi; kâğıttan kayıklar yarışıyor, ayaklar suda. Senin kayığını da biz yüzdürdük — birinci geldi.",
		"Hasat Akşamı bu gece. Meydanda uzun bir sofra kurduk; balkabağı çorbası ve taze ekmek. Tabağın hep dolu, yerin hep ayrılmış.",
		"Fener Gecesi! Bütün kasaba el yapımı fenerlerle sokakta. Kar sessizce yağıyor, ışıklar süzülüyor. En büyük feneri kuleye senin adına astık.",
	],
	"en": [
		"It's Flower Day! The square is deep in petals; the children are tucking flowers into each other's hair. The prettiest crown was left on your desk.",
		"The Stream Festival has begun! Everyone's down at the water; paper boats are racing, feet dangling in the stream. We sailed a boat for you too — it came in first.",
		"Harvest Evening is tonight. We set a long table in the square; pumpkin soup and fresh bread. Your plate is always full, your seat always saved.",
		"Lantern Night! The whole town is out with handmade lanterns. Snow falls softly, lights drifting through it. We hung the biggest lantern on the tower — in your name.",
	],
}

# ---- BOND EKİ (bağ yüksekken mektup sonuna eklenen not) ----
const BOND_EK := {
	"tr": [
		"\n\nNot: Kasabada senin adın geçince herkes gülümsüyor, bilesin.",
		"\n\nNot: Bu mektubu yazarken komşular da selam söyledi.",
		"\n\nNot: Sen bu kasabanın en eski dostusun artık.",
		"\n\nNot: Kule bu akşam senin için bir kez fazladan çalacak; biz ayarladık.",
	],
	"en": [
		"\n\nP.S. Whenever your name comes up in town, everyone smiles — just so you know.",
		"\n\nP.S. The neighbors sent their greetings while this was being written.",
		"\n\nP.S. You're this town's oldest friend now.",
		"\n\nP.S. The tower will ring once extra for you tonight; we arranged it.",
	],
}

# ---- SEANS ZİNCİRİ MEKTUPLARI (world tablolarından taşındı — mektup gövdesi TEK KAYNAK burada) ----
const MILESTONE_TXT := {
	"tr": {
		"rasathane": "On seansın şerefine tepeye bir RASATHANE kuruyoruz. Gece gökyüzünü birlikte izleyeceğiz.",
		"sera": "Yirmi seans! Meydanın yanına bir SERA dikiyoruz; kışın bile domates, her mevsim çiçek.",
		"hamam": "Otuz beş seans... Emeğin şerefine kasabaya bir HAMAM yapıyoruz. Yorgunluk artık misafir, ev sahibi değil.",
	},
	"en": {
		"rasathane": "In honor of ten sessions, we're raising an OBSERVATORY on the hill. We'll watch the night sky together.",
		"sera": "Twenty sessions! We're building a GREENHOUSE beside the square; tomatoes even in winter, flowers in every season.",
		"hamam": "Thirty-five sessions... In honor of your effort, the town is building a BATHHOUSE. Weariness is a guest here now, not the master of the house.",
	},
}
const SESSION_TXT := {
	"tr": {
		"heykel": "Elli seans! Meydana küçük bir heykel diktik; kaidesinde tek kelime var: 'Emeğe.'",
		"kameriye": "Yetmiş beş seans... Çayıra sarmaşıklı bir kameriye kurduk. En güzel gölge artık orada.",
		"yuzyil_mesesi": "YÜZ seans. Çayırın ortasına bir meşe fidanı diktik ve adını şimdiden koyduk: Yüzyıl Meşesi. Senin gibi sabırla büyüyecek.",
		"fener_dizisi": "Yüz elli seans! Meydanın etrafına el yapımı fenerler astık. Akşamları hepsi senin için yanıyor.",
		"kule_yaldizi": "İki yüz seans... Ustalar kulenin kenarlarına ince bir yaldız işledi. Güneş vurunca bütün kasaba parlıyor.",
		"zafer_bahcesi": "Üç yüz seans! Meydanın yanına küçük bir bahçe yaptık: Zafer Bahçesi. Her çiçeği bir seansın anısı.",
		"ebedi_alev": "BEŞ YÜZ seans. Meydanda küçük, nazik bir alev yaktık; hiç sönmeyecek. Bu kasaba var oldukça emeğin anılacak.",
	},
	"en": {
		"heykel": "Fifty sessions! We set a small statue in the square; its base bears a single word: 'To honest work.'",
		"kameriye": "Seventy-five sessions... We built an ivy-clad pergola in the meadow. The finest shade in town lives there now.",
		"yuzyil_mesesi": "ONE HUNDRED sessions. We planted an oak sapling in the middle of the meadow and named it already: the Century Oak. It will grow with patience, just like you.",
		"fener_dizisi": "A hundred and fifty sessions! We hung handmade lanterns all around the square. In the evenings, every one of them burns for you.",
		"kule_yaldizi": "Two hundred sessions... The craftsmen worked a fine gilding into the tower's edges. When the sun strikes it, the whole town shines.",
		"zafer_bahcesi": "Three hundred sessions! We made a little garden beside the square: the Victory Garden. Every flower is the memory of a session.",
		"ebedi_alev": "FIVE HUNDRED sessions. We lit a small, gentle flame in the square; it will never go out. As long as this town stands, your effort will be remembered.",
	},
}
const SERI := {
	"tr": {
		"atolye": "Üç seanslık emeğinin şerefine bir ATÖLYE kuruyoruz. Ellerine sağlık.",
		"kutuphane": "Beş seans! Meydanda bir KÜTÜPHANE yükseliyor. Kasaba seninle akıllanıyor.",
	},
	"en": {
		"atolye": "In honor of three sessions of your effort, we're building a WORKSHOP. Bless your hands.",
		"kutuphane": "Five sessions! A LIBRARY is rising in the square. The town grows wiser with you.",
	},
}
const KONSER := {
	"tr": "Melodini kulenin tepesinden dinledim. Yıllardır yol alırım, böylesine yürekten bir ezgi az duydum. Bu akşam meydanda herkes senin şarkınla dans etti. Ben de artık burada kalıyorum.",
	"en": "I listened to your melody from the top of the tower. I've traveled for years, and rarely heard a tune so full of heart. Tonight the whole square danced to your song. I've decided to stay.",
}

## Determinist seçim — salt world._h'ten gelmeli (aynı tohum + aynı dil = aynı mektup).
static func pick(pool: Dictionary, salt: int) -> String:
	var arr: Array = pool.get(Loc.lang, pool["tr"])
	return arr[Rng.h(salt) % arr.size()]

static func an(key: String) -> String:
	return _by_key(AN, key)

static func olay(key: String) -> String:
	return _by_key(OLAY, key)

static func milestone_txt(key: String) -> String:
	return _by_key(MILESTONE_TXT, key)

static func session_txt(kind: String) -> String:
	return _by_key(SESSION_TXT, kind)

static func seri_txt(key: String) -> String:
	return _by_key(SERI, key)

static func dilek(kind: String, salt: int) -> String:
	var d: Dictionary = DILEK.get(Loc.lang, DILEK["tr"])
	var arr: Array = d.get(kind, DILEK["tr"].get(kind, []))
	if arr.is_empty():
		push_warning("[letters] bilinmeyen dilek tipi: " + kind)
		return kind
	return arr[Rng.h(salt) % arr.size()]

static func fest(season: int) -> String:
	var arr: Array = FESTIVAL.get(Loc.lang, FESTIVAL["tr"])
	return arr[season]

static func konser_txt() -> String:
	return KONSER.get(Loc.lang, KONSER["tr"])

## Aktif dil sözlüğünden anahtar; eksikse tr'ye düşer ve loglar (kural 9: sessiz veri düşürme yok).
static func _by_key(pool: Dictionary, key: String) -> String:
	var d: Dictionary = pool.get(Loc.lang, pool["tr"])
	if d.has(key):
		return d[key]
	push_warning("[letters] '%s' anahtarı '%s' dilinde yok — tr'ye dönülüyor" % [key, Loc.lang])
	return pool["tr"].get(key, key)
