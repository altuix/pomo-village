class_name Melody
extends RefCounted
## NEFES kule melodisi (HTML v15). 8 adım × 6 nota pentatonik (C-D-E-G-A-C):
## her kombinasyon uyumlu → ödül garantisi, müzik bilgisi gerektirmez. -1 = sus.

const SCALE := [262.0, 294.0, 330.0, 392.0, 440.0, 523.0]   # Hz (pentatonik + oktav)
const STEPS := 8
const ROWS := 6
const DEFAULT := [0, 2, 4, 2, -1, 3, 1, 0]

## İyi beste kuralı: ≥5 nota + ≥3 farklı ses + ≥3 hareket → Meydan Konseri.
static func quality(mel: Array) -> Dictionary:
	var notes := []
	for n in mel:
		if n >= 0:
			notes.append(n)
	var distinct := {}
	for n in notes:
		distinct[n] = true
	var moves := 0
	for i in range(1, notes.size()):
		if notes[i] != notes[i - 1]:
			moves += 1
	return {
		"ok": notes.size() >= 5 and distinct.size() >= 3 and moves >= 3,
		"notes": notes.size(), "distinct": distinct.size(), "moves": moves,
	}

# --- paylaşım kodu (8 harf): her adım -1..5 → A..G (7 durum) ---
const CODE_CHARS := "ABCDEFG"

static func to_code(mel: Array) -> String:
	var s := ""
	for i in range(STEPS):
		var n: int = mel[i] if i < mel.size() else -1
		s += CODE_CHARS[clampi(n + 1, 0, 6)]
	return s

static func from_code(code: String) -> Array:
	var out: Array = []
	for i in range(STEPS):
		if i < code.length():
			out.append(CODE_CHARS.find(code[i]) - 1)
		else:
			out.append(-1)
	return out
