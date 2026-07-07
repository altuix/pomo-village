class_name Rng
extends RefCounted
## NEFES deterministik hash motoru (ANAYASA kural 1: tüm rastgelelik h(x)'ten; randi/randf YASAK).
## HTML v15'teki JS h()'i BİREBİR emüle eder (32-bit unsigned + Math.imul) → ayarlı eşikler
## (hf<0.45, %18 dükkân, kaskad fazı…) HTML ile aynı davranır. Günlük tohum: YYYYMMDD.
## class_name ile statik erişilir: Rng.h(x), Rng.hf(x) — node/autoload gerekmez (saf sim uyumlu).

const MASK := 0xffffffff

## JS: x >>> n  (unsigned right shift, 32-bit)
static func _urs(v: int, n: int) -> int:
	return (v & MASK) >> n

## JS: Math.imul(a,b)  (32-bit çarpımın düşük 32 biti)
static func _imul(a: int, b: int) -> int:
	return ((a & MASK) * (b & MASK)) & MASK

## JS: function h(x){x=(x^61)^(x>>>16);x+=x<<3;x^=x>>>4;x=Math.imul(x,0x27d4eb2d);x^=x>>>15;return x>>>0}
static func h(x: int) -> int:
	x = x & MASK
	x = ((x ^ 61) ^ _urs(x, 16)) & MASK
	x = (x + (x << 3)) & MASK
	x = (x ^ _urs(x, 4)) & MASK
	x = _imul(x, 0x27d4eb2d)
	x = (x ^ _urs(x, 15)) & MASK
	return x  # unsigned 32-bit

## JS: function hf(x){return (h(x)%10000)/10000;}  → [0,1)
static func hf(x: int) -> float:
	return float(h(x) % 10000) / 10000.0
