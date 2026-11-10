#!/bin/bash
# run.sh [out-dir] [--update] -- the layout conformance suite: every case in cases.py laid
# out by Flutter and by RUI, compared node by node.
#
# Output (default /tmp/rui_layout_conformance): report.md, pictures/, the raw
# rects (flutter.json, rui.json) and summary.json (case names per status).
# Takes about 30 s: no window, no device -- Flutter through `flutter test`,
# RUI through its headless layout pass.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
source "$ROOT/mobile/env/env.sh"
DIR="${1:-/tmp/rui_layout_conformance}"; [ "$DIR" = --update ] && DIR=/tmp/rui_layout_conformance
OUT="$(mkdir -p "$DIR" && cd "$DIR" && pwd)"
rm -rf "$OUT/pictures"
python3 "$HERE/cases.py" > "$OUT/cases.json"

DEP=""
for pkg in naylib yaml db_connector; do
  p="$(nimble path "$pkg" 2>/dev/null | tail -1)"; [ -n "$p" ] && DEP="$DEP --path:$p"
done
( cd "$ROOT" && nim c --hints:off --warnings:off -d:useGraphics $DEP \
    --nimcache:/tmp/rui_layout_conformance_nc -o:"$OUT/.rui_runner" \
    mobile/layout_conformance/rui_runner.nim ) >"$OUT/.build.log" 2>&1 \
  || { echo "RUI BUILD FAIL"; tail -20 "$OUT/.build.log"; exit 1; }
RUI_PREFERENCES=/nonexistent FONTCONFIG_FILE="$ROOT/mobile/compare/fonts.conf" \
  "$OUT/.rui_runner" "$OUT/cases.json" > "$OUT/rui.json" 2>"$OUT/.rui.log"

ROBOTO="${RUI_ROBOTO_DIR:-/usr/share/fonts/truetype/roboto/unhinted/RobotoTTF}"
( cd "$ROOT/mobile/mockups/flutter" && flutter pub get >/dev/null 2>&1 &&
  RUI_LAYOUT_CASES="$OUT/cases.json" RUI_LAYOUT_OUT="$OUT/flutter.json" RUI_ROBOTO_DIR="$ROBOTO" \
    flutter test test/layout_conformance_test.dart >"$OUT/.flutter.log" 2>&1 ) \
  || { echo "FLUTTER RUN FAIL"; tail -20 "$OUT/.flutter.log"; exit 1; }

python3 "$HERE/compare.py" "$OUT/cases.json" "$OUT/flutter.json" "$OUT/rui.json" "$OUT"
echo "report: $OUT/report.md"

# The baseline: which cases are expected in which state (known.json, committed).
# A case that did better before and worse now is a regression; one that now does
# better than the baseline is progress -- write it down with `run.sh --update`.
if [ "${2:-}" = "--update" ] || [ "${1:-}" = "--update" ]; then
  cp "$OUT/summary.json" "$HERE/known.json"; echo "baseline updated: $HERE/known.json"; exit 0
fi
python3 - "$HERE/known.json" "$OUT/summary.json" <<'PY'
import json, sys
rank = {"match": 0, "mismatch": 1, "silent": 1, "inexpressible": 2, "rui-error": 3}
try:
    known = json.load(open(sys.argv[1]))
except FileNotFoundError:
    print("no baseline yet: run.sh --update"); sys.exit(0)
now = json.load(open(sys.argv[2]))
was = {c: s for s, cs in known.items() for c in cs}
cur = {c: s for s, cs in now.items() for c in cs}
worse = [(c, was[c], cur[c]) for c in cur if c in was and rank[cur[c]] > rank[was[c]]]
better = [(c, was[c], cur[c]) for c in cur if c in was and rank[cur[c]] < rank[was[c]]]
for c, a, b in better: print(f"  better  {c}: {a} -> {b}")
for c, a, b in worse: print(f"  WORSE   {c}: {a} -> {b}")
if better: print("progress: record it with mobile/layout_conformance/run.sh --update")
sys.exit(1 if worse else 0)
PY
