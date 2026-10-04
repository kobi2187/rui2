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
# A free display number, claimed atomically (mkdir) so two tests starting
# together cannot pick the same one; then wait for the X socket instead of
# hoping a fixed sleep was long enough.
N=""
for n in $(seq "${2:-90}" 120); do
  if [ ! -e "/tmp/.X11-unix/X$n" ] && [ ! -e "/tmp/.X$n-lock" ] && mkdir "/tmp/rui_xdisp_$n" 2>/dev/null; then
    N="$n"; break
  fi
done
[ -n "$N" ] || { echo "no free display number" >&2; exit 1; }
DISP=":$N"
Xvfb "$DISP" -screen 0 1024x768x24 -nolisten tcp >/dev/null 2>&1 &
XPID=$!
trap 'kill $XPID 2>/dev/null; rmdir "/tmp/rui_xdisp_$N" 2>/dev/null' EXIT
for _ in $(seq 1 50); do
  [ -e "/tmp/.X11-unix/X$N" ] && break
  sleep 0.1
done
DISPLAY="$DISP" "$OUT"
