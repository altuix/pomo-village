class_name Names
extends RefCounted
## NEFES sakin isim havuzu (Türkçe) — HTML NAMES. Deterministik sıra atama (name_idx).

const POOL := [
	"Elif", "Kemal", "Ayşe", "Demir", "Zeynep", "Ali", "Nazlı", "Cem", "Melis", "Onur",
	"Sude", "Baran", "Derya", "Emre", "İpek", "Rüzgar", "Lale", "Poyraz", "Mina", "Aras",
]

static func at(i: int) -> String:
	return POOL[i % POOL.size()]
