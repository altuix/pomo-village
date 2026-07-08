#!/usr/bin/env bash
# NEFES doğrulama orkestratörü — anayasa çalışma döngüsü (CLAUDE.md §Çalışma döngüsü).
# Tümü tek Godot binary ile: export template / Chromium / Playwright GEREKMEZ.
#
# Kullanım:
#   tools/verify.sh check     # tüm .gd script'leri --check-only ile doğrula
#   tools/verify.sh sim       # headless pop-band + determinizm testi
#   tools/verify.sh visual    # gündüz/akşam/gece PNG yakala + piksel denetimi
#   tools/verify.sh endgame   # 365 gün hızlandırılmış koşu (sim'e dokunan HER işte zorunlu)
#   tools/verify.sh timelapse # gün 0..365 büyüme kareleri (.verify_out/timelapse/) — gözle incele
#   tools/verify.sh all       # check+sim+visual
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

# Gerçek oyunun süreç CPU'su (ps) — nişin 1 no'lu şikâyet metriği ("oyun %70 CPU yiyor").
# NOT: kare-zamanı ölçümü macOS arka plan pencere kısıtlamasıyla güvenilmez çıktı (tools/perf.gd
# draw-call/bileşen profili için elle kullanılır); kullanıcıya görünen metrik budur.
cmd_perf() {
	local budget="${1:-35}"   # dev build macOS eşiği (%, tek çekirdek); Windows release hedefi Faz E'de ayrı
	echo "== perf (gerçek oyun, %CPU örneklemesi, bütçe %$budget) =="
	# önceki kill'lenmiş koşudan kalan bayat kilidi temizle (yoksa oyun kendini kapatır)
	rm -f "$HOME/Library/Application Support/Godot/app_userdata/NEFES/nefes.lock" 2>/dev/null
	"$GODOT" --path "$ROOT" >/dev/null 2>&1 &
	local pid=$!
	perl -e 'select(undef,undef,undef,8)'   # açılış + offline ileri-sarma bitsin
	local sum=0 cnt=0 c
	for i in 1 2 3 4 5 6; do
		c=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' ')
		if [[ -n "$c" ]]; then sum=$(echo "$sum + $c" | bc); cnt=$((cnt + 1)); fi
		perl -e 'select(undef,undef,undef,2)'
	done
	local rss=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')
	kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
	if [[ "$cnt" == 0 ]]; then echo "  FAIL: süreç örneklenemedi"; FAIL=1; return; fi
	local avg=$(echo "scale=1; $sum / $cnt" | bc)
	local mb=$(( ${rss:-0} / 1024 ))
	echo "  ort. CPU = %$avg (bütçe %$budget)  ·  RAM ≈ ${mb}MB"
	if (( $(echo "$avg > $budget" | bc) )); then
		echo "  RESULT: FAIL"; FAIL=1
	else
		echo "  RESULT: PASS"
	fi
}

cmd_ui() {
	echo "== ui (sözleşme + sinyal akışları, headless) =="
	if "$GODOT" --headless --script "$ROOT/tests/run_ui.gd"; then
		echo "  ui PASS"
	else
		echo "  ui FAIL"; FAIL=1
	fi
}

cmd_endgame() {
	echo "== endgame (365 gün) =="
	if "$GODOT" --headless --script "$ROOT/tests/run_endgame.gd" -- "$@"; then
		echo "  endgame PASS"
	else
		echo "  endgame FAIL"; FAIL=1
	fi
}

cmd_timelapse() {
	echo "== timelapse (büyüme kareleri, akşam 19:00, tohum sabit) =="
	local tl="$OUT/timelapse"
	mkdir -p "$tl"
	for day in 0 3 7 14 30 60 120 365; do
		local png="$tl/day_$(printf '%03d' "$day").png"
		rm -f "$png"
		# ileri-sarma senkron: kill penceresi gün sayısıyla büyür (365 gün ≈ 80-120s sim)
		run_windowed $((30 + day / 2)) "$GODOT" --script "$ROOT/tools/capture.gd" -- "out=$png" "time=19.0" "seed=20260707" "steps=$((day * 2400))"
		if [[ -f "$png" ]]; then
			echo "  OK   gün $day -> $png"
		else
			echo "  FAIL gün $day yakalanamadı"; FAIL=1
		fi
	done
	echo "  (kareleri GÖZLE incele: büyüme hikâyesi tek bakışta okunmalı)"
}

case "${1:-all}" in
	check)  cmd_check ;;
	sim)    shift; cmd_sim "$@" ;;
	visual) cmd_visual ;;
	ui)     cmd_ui ;;
	endgame) shift; cmd_endgame "$@" ;;
	perf) shift; cmd_perf "$@" ;;
	timelapse) cmd_timelapse ;;
	all)    cmd_check; cmd_sim; cmd_ui; cmd_visual ;;
	*) echo "kullanım: verify.sh {check|sim|visual|endgame|timelapse|all}"; exit 2 ;;
esac

echo "======================================"
[[ "$FAIL" == 0 ]] && echo "VERIFY: PASS" || echo "VERIFY: FAIL"
exit "$FAIL"
