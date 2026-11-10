#!/bin/bash
# render_rui.sh <out-dir> [screen...] -- each RUI mockup screen to <out-dir>/<screen>.png
#
# One private Xvfb exactly the phone's size, so a capture of the root window is
# the app and nothing else (the pattern of tools/visual_snapshot.sh). Fonts are
# pinned with mobile/compare/fonts.conf so both sides draw Roboto.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/mobile/env/env.sh"
OUT="$1"; shift
mkdir -p "$OUT"
W=360; H=800
export RUI_PREFERENCES=/nonexistent/rui-preferences.yaml
export FONTCONFIG_FILE="$ROOT/mobile/compare/fonts.conf"
THEME="${RUI_MOCKUP_THEME:-material}"

DEP=""
for pkg in naylib yaml db_connector; do
  p="$(nimble path "$pkg" 2>/dev/null | tail -1)"; [ -n "$p" ] && DEP="$DEP --path:$p"
done
BIN="$OUT/.mockups"
( cd "$ROOT" && nim c --hints:off --warnings:off -d:useGraphics $DEP \
    --nimcache:/tmp/rui_mobile_nc -o:"$BIN" mobile/mockups/rui/mockups.nim ) >"$OUT/.build.log" 2>&1 \
  || { echo "BUILD FAIL"; tail -20 "$OUT/.build.log"; exit 1; }

SCREENS=("$@")
[ ${#SCREENS[@]} -gt 0 ] || SCREENS=($(ls "$ROOT/mobile/mockups/rui/screens" | sed -n 's/^s\(.*\)\.nim$/\1/p'))

N=""
for d in $(seq 170 199); do
  if mkdir "/tmp/.rui_mobile_lock_$d" 2>/dev/null; then N=$d; break; fi
done
[ -n "$N" ] || { echo "no free display"; exit 2; }
Xvfb ":$N" -screen 0 "${W}x${H}x24" -nolisten tcp >"$OUT/.xvfb.log" 2>&1 &
XPID=$!
trap 'kill $XPID 2>/dev/null; rmdir /tmp/.rui_mobile_lock_'"$N"' 2>/dev/null' EXIT
for _ in $(seq 50); do [ -S "/tmp/.X11-unix/X$N" ] && break; sleep 0.1; done
export DISPLAY=":$N"

for s in "${SCREENS[@]}"; do
  "$BIN" "$s" "$THEME" >"$OUT/.$s.log" 2>&1 &
  APID=$!
  sleep "${RUI_SHOT_WAIT:-3}"
  import -window root "$OUT/$s.png" 2>/dev/null
  kill $APID 2>/dev/null; wait $APID 2>/dev/null || true
  echo "  rui     $s -> $OUT/$s.png"
done
