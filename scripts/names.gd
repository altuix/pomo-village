class_name Names
extends RefCounted
## NEFES sakin isim havuzu (Türkçe) — HTML NAMES. Deterministik sıra atama (name_idx).

const POOL_TR := [
	"Elif", "Kemal", "Ayşe", "Demir", "Zeynep", "Ali", "Nazlı", "Cem", "Melis", "Onur",
	"Sude", "Baran", "Derya", "Emre", "İpek", "Rüzgar", "Lale", "Poyraz", "Mina", "Aras",
]
# S3: dile göre isim (playtest isteği) — cozy/pastoral EN havuzu; kayıtlı isimler değişmez,
# yeni sakinler aktif dilden gelir (karışım kabul — DEVIR notu)
const POOL_EN := [
	"Hazel", "Oliver", "June", "Arthur", "Willow", "Felix", "Clara", "Jasper", "Maeve", "Otto",
	"Ivy", "Rowan", "Pearl", "Elliot", "Flora", "Silas", "Nora", "Wren", "Alma", "Finn",
]

static func at(i: int) -> String:
	var pool := POOL_TR if Loc.lang == "tr" else POOL_EN
	return pool[i % pool.size()]
