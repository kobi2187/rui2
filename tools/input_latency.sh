#!/bin/bash
# input_latency.sh -- how long real keyboard and mouse input takes to show up.
#
#   tools/input_latency.sh          report
#   REPS=15                         presses per scenario
#
# Real input: xdotool sends X events to the gallery under Xvfb (XTEST, the same
# path a keyboard takes), so the whole chain is measured -- X server, GLFW, the
# idle loop's wake-up, the event manager, the widget's handler, layout, paint,
# present. External latency is "xdotool started" -> "the frame that showed the
# change was read back" (both on the wall clock; xdotool's own start-up, a few ms,
# is inside it). The `in-app` column is the app's own view of the same events:
# from the moment it polled them to the frame that showed them, so the
# difference is time spent before the app even looked.
#
# Software GL; read the shape, not the milliseconds.
set -u
cd "$(dirname "$(readlink -f "$0")")/.."
REPS="${REPS:-15}"
OUT="${INPUT_OUT:-/tmp/input_latency}"
DISP=:92
export PATH="$HOME/.nimble/bin:/root/.nimble/bin:$PATH"
for t in Xvfb xdotool; do command -v $t >/dev/null || { echo "$t is not installed"; exit 2; }; done
DEP_PATHS=""
for pkg in naylib yaml db_connector; do
  p="$(nimble path "$pkg" 2>/dev/null | tail -1)"
  [ -n "${p:-}" ] && [ -d "$p" ] && DEP_PATHS="$DEP_PATHS --path:$p"
done
rm -rf "$OUT"; mkdir -p "$OUT"
nim c --hints:off --warnings:off -d:useGraphics -d:ruiInspect -d:ruiTestKeys -d:ruiPerf $DEP_PATHS \
    --nimcache:/tmp/rui2_tests/nc_inputlat -o:"$OUT/gallery" examples/gallery/gallery.nim \
    >"$OUT/build.log" 2>&1 || { echo "gallery did not build"; tail -20 "$OUT/build.log"; exit 2; }
SCRIPT="$OUT/script"
Xvfb "$DISP" -screen 0 1280x800x24 -nolisten tcp >"$OUT/xvfb.log" 2>&1 &
XPID=$!
export DISPLAY="$DISP"
"$OUT/gallery" --script "$SCRIPT" >"$OUT/app.log" 2>&1 &
APID=$!
trap 'kill $APID $XPID 2>/dev/null' EXIT
for _ in $(seq 1 100); do [ -d "$SCRIPT" ] && break; sleep 0.1; done
sleep 2
WID=$(xdotool search --name "RUI2 - Gallery" | head -1)
[ -n "$WID" ] || { echo "no gallery window"; exit 2; }
xdotool windowfocus "$WID" 2>/dev/null
eval "$(xdotool getwindowgeometry --shell "$WID")"      # X Y WIDTH HEIGHT

send() {
  rm -f "$SCRIPT/responses.txt"
  printf '%s\n' "$@" > "$SCRIPT/commands.tmp" && mv "$SCRIPT/commands.tmp" "$SCRIPT/commands.txt"
  for _ in $(seq 1 600); do
    [ -f "$SCRIPT/responses.txt" ] && [ ! -f "$SCRIPT/commands.txt" ] && { cat "$SCRIPT/responses.txt"; return 0; }
    sleep 0.02
  done
  echo TIMEOUT
}
field() { sed -n "s#.*[ ]$1=\([^ ]*\).*#\1#p" | head -1; }
center() {  # center SEL -> "x y" in root coordinates
  local r; r=$(send "1 $1 visual hash" | field rect)
  IFS=, read -r rx ry rw rh <<<"$r"
  echo "$((X + rx + rw / 2)) $((Y + ry + rh / 2))"
}
click() {  # click SEL: and check the widget took the focus (a click that did not would make
  local c; c=$(center "$1")          # every keyboard scenario below measure the caret blinking)
  xdotool mousemove $c click 1; sleep 0.3
  send "1 $1 read" | grep -q '"focused":true' || echo "  note: $1 did not take focus"
}

stat_row() {  # stat_row NAME values...  (ms)
  local name="$1"; shift
  [ $# -gt 0 ] || { printf '%-28s %s\n' "$name" "no change seen"; return; }
  printf '%-28s %s\n' "$name" "$(printf '%s\n' "$@" | sort -g | awk '{a[NR]=$1; s+=$1} END{printf "min %5.1f  med %5.1f  avg %5.1f  max %5.1f   (n=%d)", a[1], a[int((NR+1)/2)], s/NR, a[NR], NR}')"
}
inapp() {  # the app's own poll->present figure for what just happened
  send "1 * visual perf" | sed -n 's#.*input{n=\([0-9]*\) us=\([0-9]*\)/\([0-9]*\)/\([0-9]*\) nopaint=\([0-9]*\)}.*#n=\1 avg=\2us p95=\3us max=\4us nopaint=\5#p'
}
# measure NAME TARGET PREPARE_CMD ACTION_CMD... : arm, act, change
measure() {
  local name="$1" target="$2" action="$3" vals=() i t0 r at
  send "1 * visual perf reset" >/dev/null
  for i in $(seq 1 "$REPS"); do
    send "1 $target visual arm" >/dev/null
    t0=$(date +%s.%N)
    eval "$action"
    r=$(send "1 $target visual change 1500")
    at=$(echo "$r" | field at)
    [ -n "$at" ] && vals+=("$(awk -v a="$at" -v b="$t0" 'BEGIN{printf "%.1f", (a-b)*1000}')")
    sleep 0.15
  done
  stat_row "$name" "${vals[@]}"
  echo "    in-app: $(inapp)"
}

send "1 tabs write activeTab=7" "2 * visual stable 300 4000" >/dev/null
echo "== keyboard =="
click live.input
measure "type in TextInput" live.input 'xdotool key a'
click live.doc; xdotool key ctrl+End; sleep 0.5
measure "type at end of 3000 lines" live.doc 'xdotool key a'
measure "Enter in 3000 lines" live.doc 'xdotool key Return'
measure "arrow Up in 3000 lines" live.doc 'xdotool key Up'
measure "PageUp in 3000 lines" live.doc 'xdotool key Prior'
echo
echo "== mouse =="
measure "click button -> label" live.bumped 'c=$(center live.bump); xdotool mousemove $c click 1'
send "1 tabs write activeTab=0" "2 * visual stable 300 4000" >/dev/null
BC=$(center basics.save); HC=$(center basics.hover)
measure "hover a button (enter)" basics.save 'xdotool mousemove $HC; xdotool mousemove $BC'
send "1 tabs write activeTab=4" "2 * visual stable 300 4000" >/dev/null
VC=$(center data.view)
xdotool mousemove $VC; sleep 0.3
measure "mouse wheel on ListView" data.view 'xdotool click 5'
echo
echo "== a stream of events =="
send "1 tabs write activeTab=7" "2 * visual stable 300 4000" >/dev/null
click live.doc; xdotool key ctrl+End; sleep 0.5
send "1 * visual perf reset" >/dev/null
xdotool type --delay 30 "the quick brown fox jumps over the lazy dog, again and again and again"
sleep 0.5
echo "typed 70 chars at 30 ms in the 3000-line document"
echo "    in-app: $(inapp)"
send "1 * visual perf" | sed 's/^1 //' | tr ' ' '\n' | grep -E "^ph(Events|Layout|Render|Compose|Screen|Swap)=|^pcPainted" | sed 's/^/    /'
echo
echo "== selecting text in the 3000-line document =="
send "1 tabs write activeTab=7" "2 * visual stable 300 4000" >/dev/null
click live.doc; xdotool key ctrl+Home; sleep 0.4
DC=$(center live.doc); IFS=' ' read -r dcx dcy <<<"$DC"
sel_state() { send "1 live.doc read" | sed -n 's#.*"selectionStart":\(-*[0-9]*\),"selectionEnd":\(-*[0-9]*\).*#sel=\1..\2#p'; }
send "1 * visual perf reset" >/dev/null
xdotool mousemove $((dcx - 150)) $((dcy - 80)) mousedown 1
for i in $(seq 1 25); do xdotool mousemove $((dcx - 150 + i * 12)) $((dcy - 80 + i * 6)); sleep 0.02; done
sleep 0.4
echo "drag over ~8 lines (25 moves, 20 ms apart): $(sel_state)"
echo "    in-app: $(inapp)"
send "1 * visual perf" | sed 's/^1 //' | tr ' ' '\n' | grep -E "^ph(Events|Layout|Render|Compose)=" | sed 's/^/    /'
xdotool mouseup 1; sleep 0.3
send "1 * visual perf reset" >/dev/null
measure "extend selection Shift+Down" live.doc 'xdotool key shift+Down'
measure "select all (Ctrl+A)" live.doc 'xdotool key ctrl+a'
measure "arrow with all selected" live.doc 'xdotool key Down; sleep 0.2; xdotool key ctrl+a'
