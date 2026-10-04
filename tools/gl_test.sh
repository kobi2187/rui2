#!/bin/bash
# gl_test.sh tests/gl/<name>.nim
# Builds one GL-backed test and runs it on a private Xvfb display (number $2,
# default 96, so several can run at once).
set -eu
cd "$(dirname "$0")/.."
SRC="$1"
DEP_PATHS=""
for pkg in naylib yaml; do
  p="$(nimble path "$pkg" 2>/dev/null | tail -1)"
  [ -n "${p:-}" ] && [ -d "$p" ] && DEP_PATHS="$DEP_PATHS --path:$p"
done
OUT="/tmp/rui2_tests/gl_$(basename "$SRC" .nim)"
mkdir -p /tmp/rui2_tests
nim c -d:useGraphics --hints:off --warnings:off $DEP_PATHS -o:"$OUT" "$SRC" >/tmp/rt_gl_build.log 2>&1 \
  || { tail -15 /tmp/rt_gl_build.log; exit 1; }
DISP=":${2:-96}"
Xvfb "$DISP" -screen 0 1024x768x24 -nolisten tcp >/dev/null 2>&1 &
XPID=$!
trap 'kill $XPID 2>/dev/null' EXIT
sleep 1
DISPLAY="$DISP" "$OUT"
