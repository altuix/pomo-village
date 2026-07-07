#!/usr/bin/env bash
# NEFES doğrulama orkestratörü — anayasa çalışma döngüsü (CLAUDE.md §Çalışma döngüsü).
# Tümü tek Godot binary ile: export template / Chromium / Playwright GEREKMEZ.
#
# Kullanım:
#   tools/verify.sh check     # tüm .gd script'leri --check-only ile doğrula
#   tools/verify.sh sim       # headless pop-band + determinizm testi
#   tools/verify.sh visual    # gündüz/akşam/gece PNG yakala + piksel denetimi
#   tools/verify.sh all       # üçü birden
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$ROOT/tools/godot.sh"
OUT="$ROOT/.verify_out"
mkdir -p "$OUT"
FAIL=0

# Pencereli (GPU) komut için güvenli çalıştırma: kendini kapatmazsa süre sonunda öldür.
run_windowed() {
	local timeout_s="$1"; shift
	"$@" &
	local pid=$!
	perl -e "select(undef,undef,undef,$timeout_s)"
	if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null; fi
	wait "$pid" 2>/dev/null
}

cmd_check() {
	echo "== check-only =="
	# class_name kayıt defterini tazele (izole --check-only aksi halde class_name'i çözemez)
	"$GODOT" --headless --import >/dev/null 2>&1 || true
	local any=0
	while IFS= read -r f; do
		any=1
		# --check-only sadece script parse/analiz; tek dosya
		if "$GODOT" --headless --check-only --script "$f" >/dev/null 2>"$OUT/check.err"; then
			echo "  OK   $f"
		else
			echo "  FAIL $f"; cat "$OUT/check.err"; FAIL=1
		fi
	done < <(find "$ROOT/scripts" "$ROOT/tools" "$ROOT/tests" -name '*.gd' 2>/dev/null | sort)
	[[ "$any" == 0 ]] && echo "  (script bulunamadı)"
}

cmd_sim() {
	echo "== sim (pop-band + determinizm) =="
	if "$GODOT" --headless --script "$ROOT/tests/run_sim.gd" -- "$@"; then
		echo "  sim PASS"
	else
		echo "  sim FAIL"; FAIL=1
	fi
}

cmd_visual() {
	echo "== visual (capture + pixelcheck) =="
	# gündüz 12:00, akşam 19:00, gece 01:00
	local phases=("day 12.0" "eve 19.0" "night 1.0")
	for p in "${phases[@]}"; do
		local name="${p%% *}"; local tod="${p##* }"
		local png="$OUT/frame_$name.png"
		rm -f "$png"
		run_windowed 20 "$GODOT" --script "$ROOT/tools/capture.gd" -- "out=$png" "time=$tod" "seed=20260707"
		if [[ -f "$png" ]]; then
			"$GODOT" --headless --script "$ROOT/tools/pixelcheck.gd" -- "$png" "$name" || FAIL=1
		else
			echo "  FAIL: $name yakalanamadı"; FAIL=1
		fi
	done
}

case "${1:-all}" in
	check)  cmd_check ;;
	sim)    shift; cmd_sim "$@" ;;
	visual) cmd_visual ;;
	all)    cmd_check; cmd_sim; cmd_visual ;;
	*) echo "kullanım: verify.sh {check|sim|visual|all}"; exit 2 ;;
esac

echo "======================================"
[[ "$FAIL" == 0 ]] && echo "VERIFY: PASS" || echo "VERIFY: FAIL"
exit "$FAIL"
