#!/bin/bash
# bench.sh [bench args]   e.g. tools/bench.sh --sizes=1000 --gate
# Builds benchmarks/bench.nim in release mode and runs it on a private Xvfb
# display (the render rows paint into real GL textures). Defaults to 1k and
# 10k widgets; --gate fails the run if a row is over budget, --json prints a
# machine-readable line for recording.
set -eu
cd "$(dirname "$0")/.."
DEP_PATHS=""
for pkg in naylib yaml; do
  p="$(nimble path "$pkg" 2>/dev/null | tail -1)"
  [ -n "${p:-}" ] && [ -d "$p" ] && DEP_PATHS="$DEP_PATHS --path:$p"
done
OUT="${TMPDIR:-/tmp}/rui2_bench"
nim c -d:release -d:useGraphics --hints:off $DEP_PATHS -o:"$OUT" benchmarks/bench.nim

DISP=":98"
Xvfb "$DISP" -screen 0 1280x1024x24 -nolisten tcp >/dev/null 2>&1 &
XPID=$!
trap 'kill $XPID 2>/dev/null' EXIT
sleep 1
DISPLAY="$DISP" "$OUT" "$@"
