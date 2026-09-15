#!/bin/bash
# shot.sh <binary> <output.png> [seconds-to-wait]
# Runs a RUI2 app on a private Xvfb display and captures the framebuffer.
set -u
BIN="$1"; OUT="$2"; WAIT="${3:-4}"
DISP=":99"
export DISPLAY="$DISP"

pkill -f "Xvfb $DISP" 2>/dev/null
sleep 0.5
Xvfb "$DISP" -screen 0 1024x768x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
XPID=$!
sleep 2

"$BIN" >/tmp/app.log 2>&1 &
APID=$!
sleep "$WAIT"

if ! kill -0 "$APID" 2>/dev/null; then
  echo "!! app exited early; last log lines:"
  tail -20 /tmp/app.log
fi

import -window root "$OUT" 2>/dev/null || xwd -root -silent | convert xwd:- "$OUT"
kill "$APID" 2>/dev/null; wait "$APID" 2>/dev/null
kill "$XPID" 2>/dev/null
echo "saved $OUT ($(stat -c%s "$OUT" 2>/dev/null) bytes)"
