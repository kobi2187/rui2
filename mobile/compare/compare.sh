#!/bin/bash
# compare.sh [screen...] -- render each mockup in RUI and in Flutter, and compare.
#
# Writes to $RUI_COMPARE_OUT (default /tmp/rui_mobile_compare):
#   rui/<s>.png  flutter/<s>.png    the two renders, 360x800 at DPR 1
#   side/<s>.png                     RUI | Flutter | difference, labelled
#   report.md / report.tsv           a score per screen
#
# Scores: `diff%` is the share of pixels differing by more than 8% (a strict
# count: a 1px shift of text already counts), `blur-diff%` the same after a
# 3px blur (forgives antialiasing and small shifts, catches missing or moved
# things), `ssim` the mean structural similarity (score.py). Lower diff and higher
# ssim mean closer. The numbers are for tracking a screen over time, not a
# pass mark: the ladder's goal is "a Flutter developer would accept it", which
# a person (or Claude) judges on side/<s>.png.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${RUI_COMPARE_OUT:-/tmp/rui_mobile_compare}"
mkdir -p "$OUT/rui" "$OUT/flutter" "$OUT/side"
"$ROOT/mobile/compare/render_rui.sh" "$OUT/rui" "$@"
"$ROOT/mobile/compare/render_flutter.sh" "$OUT/flutter" 2>&1 | grep -v -i "woah\|as root\|superuser\|^ *[/📎]" || true

{ echo "| screen | diff% | blur-diff% | ssim |"; echo "|---|---|---|---|"; } >"$OUT/report.md"
: >"$OUT/report.tsv"
for r in "$OUT"/rui/*.png; do
  s="$(basename "$r" .png)"; f="$OUT/flutter/$s.png"
  [ -f "$f" ] || { echo "  no flutter render for $s"; continue; }
  compare -fuzz 8% "$r" "$f" "$OUT/side/.$s.diff.png" 2>/dev/null || true
  IFS=$'\t' read -r dp bp ssim < <(python3 "$ROOT/mobile/compare/score.py" "$r" "$f")
  montage -label RUI "$r" -label Flutter "$f" -label difference "$OUT/side/.$s.diff.png" \
          -tile 3x1 -geometry +6+0 -pointsize 16 "$OUT/side/$s.png"
  echo "| $s | $dp | $bp | $ssim |" >>"$OUT/report.md"
  printf '%s\t%s\t%s\t%s\n' "$s" "$dp" "$bp" "$ssim" >>"$OUT/report.tsv"
  echo "  compare $s: diff ${dp}%  blur-diff ${bp}%  ssim $ssim -> $OUT/side/$s.png"
done
