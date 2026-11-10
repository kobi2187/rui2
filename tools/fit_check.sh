#!/bin/bash
# fit_check.sh [options] <app.nim> [-- app args] -- does the app fit these phones?
#
# Lays the app out at the size of each device in a list -- headless, a fraction
# of a second each -- and reports, per device, whether everything fits or what
# does not (packages/rui/src/fit_check.nim):
#
#   offscreen     part of a widget outside the screen, with no scroll view to reach it
#   overflow      a widget sticking out of its parent
#   cut           a label or button with less room than its text needs
#   small-target  something to tap under 44 px (a warning)
#
#   tools/fit_check.sh examples/tutorial/form.nim
#   tools/fit_check.sh --shots mobile/mockups/rui/mockups.nim -- 04_inbox
#   tools/fit_check.sh --devices "Watch=184x224,Kiosk=1080x1920" app.nim
#   tools/fit_check.sh --touch 48 app.nim          Material's 48 instead of Apple's 44
#
# Sizes are logical pixels (dp / pt), which is what layout sees; a phone's
# resolution is that times its density, and RUI does not scale by density yet,
# so only the logical size matters today. Touch input is assumed (RUI_INPUT=
# touch), as on a phone. Output in $RUI_FIT_OUT (default /tmp/rui_fit_check):
# report.md, <device>.json, and with --shots <device>.png with the problems
# outlined (red: errors, amber: small targets). Exit status 1 if any device has
# an error, so it can gate CI.
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
ROOT="$PWD"
SHOTS=0; TOUCH=44; DEVICES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --shots) SHOTS=1; shift ;;
    --touch) TOUCH="$2"; shift 2 ;;
    --devices) DEVICES="$2"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) break ;;
  esac
done
APP="${1:?usage: tools/fit_check.sh [--shots] [--devices N=WxH,...] app.nim [-- args]}"; shift
[ "${1:-}" = "--" ] && shift
ARGS=("$@")

# Logical sizes of common devices, portrait unless named otherwise.
DEFAULT_DEVICES="iPhone SE=375x667,iPhone 16=393x852,iPhone 16 Pro Max=440x956,\
Pixel 9=412x923,Galaxy S24=360x780,Galaxy A15=384x854,Galaxy Z Fold (folded)=344x882,\
Small phone=320x568,Pixel 9 landscape=923x412,iPad mini=744x1133,Galaxy Tab S9=800x1280,\
Laptop=1280x800"
DEVICES="${DEVICES:-$DEFAULT_DEVICES}"

OUT="${RUI_FIT_OUT:-/tmp/rui_fit_check}"
mkdir -p "$OUT"; rm -f "$OUT"/*.json "$OUT"/*.png
export PATH="$HOME/.nimble/bin:/root/.nimble/bin:$PATH"
[ -f mobile/env/env.sh ] && source mobile/env/env.sh
export RUI_PREFERENCES=/nonexistent/rui-preferences.yaml
export FONTCONFIG_FILE="$ROOT/tools/fontconfig/fonts.conf"
export RUI_INPUT=touch
DEP=""
for pkg in naylib yaml db_connector; do
  p="$(nimble path "$pkg" 2>/dev/null | tail -1)"; [ -n "$p" ] && DEP="$DEP --path:$p"
done
BIN="$OUT/.app"
nim c --hints:off --warnings:off -d:useGraphics $DEP --nimcache:/tmp/rui_fit_check_nc \
  -o:"$BIN" "$APP" >"$OUT/.build.log" 2>&1 || { echo "BUILD FAIL"; tail -20 "$OUT/.build.log"; exit 2; }

slug() { echo "$1" | tr -c 'A-Za-z0-9' '_' | sed 's/_*$//'; }
IFS=',' read -ra LIST <<<"$DEVICES"
failed=0
{ echo "# Does $(basename "$APP") fit?"; echo
  echo "| device | size | fits? | errors | small targets |"; echo "|---|---|---|---|---|"; } >"$OUT/report.md"
details=""
for entry in "${LIST[@]}"; do
  name="${entry%%=*}"; size="${entry##*=}"; s=$(slug "$name")
  RUI_WINDOW_SIZE="$size" RUI_FIT_CHECK="$OUT/$s.json" timeout 30 "$BIN" "${ARGS[@]}" \
    >"$OUT/.$s.log" 2>&1
  if [ ! -s "$OUT/$s.json" ]; then
    printf '  %-24s %-9s  did not run (see %s)\n' "$name" "$size" "$OUT/.$s.log"
    echo "| $name | $size | did not run | | |" >>"$OUT/report.md"; failed=1; continue
  fi
  read -r errs warns < <(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["errors"], d["warnings"])' "$OUT/$s.json")
  if [ "$errs" -eq 0 ]; then verdict="fits"; else verdict="DOES NOT FIT"; failed=1; fi
  printf '  %-24s %-9s  %-13s %2s errors, %2s small targets\n' "$name" "$size" "$verdict" "$errs" "$warns"
  echo "| $name | $size | $verdict | $errs | $warns |" >>"$OUT/report.md"
  details+=$(python3 - "$OUT/$s.json" "$name" "$size" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
errs = [i for i in d["issues"] if i["kind"] != "small-target"]
if errs:
    print(f"\n## {sys.argv[2]} ({sys.argv[3]})\n")
    for i in errs:
        print(f"- **{i['kind']}** `{i['path']}`: {i['detail']}")
PY
)
  if [ $SHOTS = 1 ]; then
    w=${size%x*}; h=${size#*x}; d=$((170 + RANDOM % 20))
    Xvfb ":$d" -screen 0 "${w}x${h}x24" -nolisten tcp >/dev/null 2>&1 & xp=$!
    for _ in $(seq 50); do [ -S "/tmp/.X11-unix/X$d" ] && break; sleep 0.1; done
    RUI_WINDOW_SIZE="$size" DISPLAY=":$d" "$BIN" "${ARGS[@]}" >/dev/null 2>&1 & ap=$!
    sleep "${RUI_FIT_WAIT:-3}"
    DISPLAY=":$d" import -window root "$OUT/$s.png" 2>/dev/null
    kill $ap $xp 2>/dev/null; wait $ap $xp 2>/dev/null
    python3 - "$OUT/$s.png" "$OUT/$s.json" <<'PY'
import json, sys
from PIL import Image, ImageDraw
img = Image.open(sys.argv[1]).convert("RGB"); d = ImageDraw.Draw(img)
for i in json.load(open(sys.argv[2]))["issues"]:
    x, y, w, h = i["rect"]
    col = "#f5a623" if i["kind"] == "small-target" else "#e0182d"
    d.rectangle([x, y, x + w - 1, y + h - 1], outline=col, width=2 if col == "#e0182d" else 1)
img.save(sys.argv[1])
PY
  fi
done
echo "$details" >>"$OUT/report.md"
echo "report: $OUT/report.md"
exit $failed
