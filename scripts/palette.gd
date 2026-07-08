class_name Palette
extends RefCounted
## NEFES merkezi renk paleti (ANAYASA kural 4 + CLAUDE.md §1 — bu modül kuralın dayandığı yerdi
## ve şimdiye dek HİÇ kurulmamıştı; QA denetimi yakaladı). Kaynak tek: dünya renkleri, çatılar,
## kişiler, UI tonları buradan okunur. YENİ TON EKLEMEK = PALETİ GENİŞLETMEK = önce kullanıcıya sor.

# ---- DÜNYA (kilitli 12-renk ailesi; HTML SEASONS birebir) ----
const SEASONS := [
	{ "name": "ilkbahar", "grass": Color8(92,124,78),  "tree": Color8(111,155,95), "flowers": [Color8(232,160,176), Color8(245,215,110), Color8(201,160,224)], "road": Color8(120,104,92),  "snow": false },
	{ "name": "yaz",      "grass": Color8(80,120,62),   "tree": Color8(90,150,74),  "flowers": [Color8(245,215,110), Color8(255,255,255), Color8(232,128,106)], "road": Color8(128,112,98),  "snow": false },
	{ "name": "sonbahar", "grass": Color8(124,96,58),   "tree": Color8(200,120,56), "flowers": [Color8(224,128,64), Color8(208,160,64), Color8(192,80,48)],    "road": Color8(118,98,84),   "snow": false },
	{ "name": "kış",      "grass": Color8(168,176,186), "tree": Color8(164,180,190),"flowers": [Color8(255,255,255), Color8(224,232,240), Color8(208,218,232)], "road": Color8(150,150,160), "snow": true },
]
const ROOF_COLS := [
	[Color8(194,90,74), Color8(168,72,58)],    # c25a4a
	[Color8(201,155,70), Color8(168,130,58)],  # c99b46
	[Color8(122,155,106), Color8(104,138,88)], # 7a9b6a
	[Color8(106,134,168), Color8(88,111,146)], # 6a86a8
	[Color8(154,106,140), Color8(131,86,117)], # 9a6a8c
]
const PCOL := [Color8(255,207,122), Color8(194,90,74), Color8(106,134,168), Color8(122,155,106), Color8(201,143,176), Color8(232,220,200)]

# ---- UI TOKENLARI (fiilî kullanımın resmileşmesi — genişleme değil, tek kaynağa toplama) ----
const INK := Color("2b1e2e")          # anayasa: en koyu uç
const HONEY := Color("ffe6a8")        # anayasa: en açık uç (yalnız ışık/vurgu)
const CREAM := Color("e8dcc8")        # metin/kağıt
const SAGE := Color("7a9b6a")         # olumlu/yeşil vurgu (çatı ailesinden)
const MUTED := Color("c9a892")        # ikincil metin
const MINT := Color("c9e0b0")         # eylem butonu (sage'in açığı)
const LILAC := Color("c9b8e0")        # anı/veda tonu
const FADED := Color("7a6a72")        # sönük ipucu metni
const PANEL_BG := Color("1d1424")     # panel zemini (ink'in koyusu)
const PANEL_BORDER := Color("5a3f52") # panel kenarı
const CARD_BG := Color("241a2a")      # mektup kartı zemini
const MEL_CELL := Color("2a1f30")     # melodi ızgara hücresi
const MEL_BORDER := Color("3d2b40")   # melodi hücre kenarı
