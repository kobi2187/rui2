#!/bin/bash
# visual_snapshot.sh [check|update] [theme...]
# Renders examples/widgets/theme_catalog.nim in every shipped theme on a private
# Xvfb and compares each picture with tests/visual_snapshots/<theme>.png.
# Layout snapshots check where widgets are; this checks what they look like --
# colours, contrast, bevels, shapes -- which a rect dump cannot see.
#
#   tools/visual_snapshot.sh            check every theme (the default)
#   tools/visual_snapshot.sh update     rewrite the reference pictures
#   tools/visual_snapshot.sh check beos daylight     just these themes
#
# A theme passes when at most RUI_VISUAL_BUDGET pixels (default 0.01% of the
# window, about 76) differ by more than RUI_VISUAL_FUZZ (default 3%). Rendering
# is deterministic on one machine (repeat runs differ by 0 pixels), so the
# budget is small: recolouring one hyperlink changes about 700. Fonts are
# pinned as for layout snapshots; pictures made on a machine with different
# fonts will differ, so update them on the machine that checks them.
# Failing pictures and their diffs are left in /tmp/rui2_visual.
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
MODE="${1:-check}"; shift || true
export PATH="$HOME/.nimble/bin:/root/.nimble/bin:$PATH"
export RUI_PREFERENCES=/nonexistent/rui-preferences.yaml
export FONTCONFIG_FILE="$PWD/tools/fontconfig/fonts.conf"
command -v Xvfb >/dev/null || { echo "Xvfb is not installed"; exit 2; }
command -v compare >/dev/null || { echo "ImageMagick (compare) is not installed"; exit 2; }

# The window size of the catalogue: the screen is made exactly this size, so a
# capture of the root window is the app and nothing else.
W=1000; H=760
FUZZ="${RUI_VISUAL_FUZZ:-3%}"
BUDGET="${RUI_VISUAL_BUDGET:-$((W * H / 10000))}"
THEMES=("$@")
if [ ${#THEMES[@]} -eq 0 ]; then
  # Every shipped theme; "light" and "dark" are other names for daylight and
  # midnight and would only repeat them.
  THEMES=(beos daylight midnight aurora ocean forest rose ember graphite punch
          hairline joy wide contrast contrast-dark)
fi

DEP=""
for pkg in naylib yaml db_connector; do
  p="$(nimble path "$pkg" 2>/dev/null | tail -1)"; [ -n "$p" ] && DEP="$DEP --path:$p"
done
OUT=/tmp/rui2_visual; mkdir -p "$OUT" tests/visual_snapshots
BIN="$OUT/theme_catalog"
nim c --hints:off --warnings:off -d:useGraphics $DEP -o:"$BIN" \
  examples/widgets/theme_catalog.nim >"$OUT/build.log" 2>&1 \
  || { echo "BUILD FAIL"; tail -15 "$OUT/build.log"; exit 1; }

# A free display, claimed atomically so two runs cannot share one.
N=""
for d in $(seq 120 160); do
  if mkdir "/tmp/.rui2_visual_lock_$d" 2>/dev/null; then N=$d; break; fi
done
[ -n "$N" ] || { echo "no free display"; exit 2; }
Xvfb ":$N" -screen 0 "${W}x${H}x24" -nolisten tcp >"$OUT/xvfb.log" 2>&1 &
XPID=$!
trap 'kill $XPID 2>/dev/null; rmdir /tmp/.rui2_visual_lock_'"$N"' 2>/dev/null' EXIT
for _ in $(seq 50); do [ -S "/tmp/.X11-unix/X$N" ] && break; sleep 0.1; done
export DISPLAY=":$N"

FAIL=0
for t in "${THEMES[@]}"; do
  "$BIN" "$t" >"$OUT/$t.log" 2>&1 &
  APID=$!
  sleep 4                                   # first frames, fonts, a settled switch
  import -window root "$OUT/$t.png" 2>/dev/null
  kill $APID 2>/dev/null; wait $APID 2>/dev/null
  if [ "$MODE" = "update" ]; then
    cp "$OUT/$t.png" "tests/visual_snapshots/$t.png"
    echo "  updated $t"
  elif [ ! -f "tests/visual_snapshots/$t.png" ]; then
    echo "  MISSING $t (run: tools/visual_snapshot.sh update $t)"; FAIL=$((FAIL + 1))
  else
    diff_px=$(compare -metric AE -fuzz "$FUZZ" "tests/visual_snapshots/$t.png" "$OUT/$t.png" \
                      "$OUT/$t.diff.png" 2>&1 >/dev/null | cut -d' ' -f1)
    diff_px=${diff_px%.*}
    if [ -n "$diff_px" ] && [ "$diff_px" -le "$BUDGET" ] 2>/dev/null; then
      echo "  PASS  $t ($diff_px px differ)"
    else
      echo "  FAIL  $t (${diff_px:-?} px differ, budget $BUDGET): $OUT/$t.png, $OUT/$t.diff.png"
      FAIL=$((FAIL + 1))
    fi
  fi
done
[ "$MODE" = "update" ] && exit 0
echo "$((${#THEMES[@]} - FAIL)) passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
