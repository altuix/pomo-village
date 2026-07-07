#!/usr/bin/env bash
# NEFES — Godot binary bulucu/wrapper. Tüm doğrulama tek binary ile çalışır
# (export template / Chromium / Playwright GEREKMEZ). Kullanım: tools/godot.sh <godot argümanları>
set -euo pipefail

# Aday konumlar (ilk çalışan kullanılır)
CANDIDATES=(
  "${GODOT:-}"
  "$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
  "/Applications/Godot.app/Contents/MacOS/Godot"
  "$(command -v godot 2>/dev/null || true)"
  "$(command -v godot4 2>/dev/null || true)"
)

GODOT_BIN=""
for c in "${CANDIDATES[@]}"; do
  if [[ -n "$c" && -x "$c" ]]; then GODOT_BIN="$c"; break; fi
done

if [[ -z "$GODOT_BIN" ]]; then
  echo "HATA: Godot 4.x binary bulunamadı. GODOT env değişkenini ayarlayın." >&2
  exit 127
fi

exec "$GODOT_BIN" "$@"
