#!/bin/bash
# perf_scenarios.sh -- per-phase cost of the frame in several kinds of work.
#
#   tools/perf_scenarios.sh            table: one row per scenario
#   tools/perf_scenarios.sh check      the same, and exit 1 when a scenario paints far
#                                      more than it should (pixels painted per frame)
#   PERF_STEPS=60                      steps per scripted scenario
#
# Builds the gallery with -d:ruiPerf -d:ruiInspect and drives it through the
# scripting protocol. Every scripted step ends in `visual hash fresh`, which makes
# the app present a frame, so a step is one frame of that work. Numbers are
# microseconds per presented frame (average); software GL, so read the
# proportions, not the milliseconds. Readback (the probe's own cost) is left out.
set -u
cd "$(dirname "$(readlink -f "$0")")/.."
MODE="${1:-report}"
STEPS="${PERF_STEPS:-60}"
FAILS=0
LIM=()
OUT="${PERF_OUT:-/tmp/perf_scenarios}"
DISP=:93
export PATH="$HOME/.nimble/bin:/root/.nimble/bin:$PATH"
command -v Xvfb >/dev/null || { echo "Xvfb is not installed"; exit 2; }
DEP_PATHS=""
for pkg in naylib yaml db_connector; do
  p="$(nimble path "$pkg" 2>/dev/null | tail -1)"
  [ -n "${p:-}" ] && [ -d "$p" ] && DEP_PATHS="$DEP_PATHS --path:$p"
done
rm -rf "$OUT"; mkdir -p "$OUT"
nim c --hints:off --warnings:off -d:useGraphics -d:ruiInspect -d:ruiTestKeys -d:ruiPerf $DEP_PATHS \
    --nimcache:/tmp/rui2_tests/nc_perfsc -o:"$OUT/gallery" examples/gallery/gallery.nim \
    >"$OUT/build.log" 2>&1 || { echo "gallery did not build"; tail -20 "$OUT/build.log"; exit 2; }
SCRIPT="$OUT/script"
Xvfb "$DISP" -screen 0 1280x800x24 -nolisten tcp >"$OUT/xvfb.log" 2>&1 &
XPID=$!
DISPLAY="$DISP" "$OUT/gallery" --script "$SCRIPT" >"$OUT/app.log" 2>&1 &
APID=$!
trap 'kill $APID $XPID 2>/dev/null' EXIT
for _ in $(seq 1 100); do [ -d "$SCRIPT" ] && break; sleep 0.1; done
sleep 2

send() {
  rm -f "$SCRIPT/responses.txt"
  printf '%s\n' "$@" > "$SCRIPT/commands.tmp" && mv "$SCRIPT/commands.tmp" "$SCRIPT/commands.txt"
  for _ in $(seq 1 1200); do
    [ -f "$SCRIPT/responses.txt" ] && [ ! -f "$SCRIPT/commands.txt" ] && { cat "$SCRIPT/responses.txt"; return 0; }
    kill -0 "$APID" 2>/dev/null || { echo "APP EXITED"; return 1; }
    sleep 0.05
  done
  echo TIMEOUT
}
val() { sed -n "s#.*[ ]$1=\([0-9.]*\).*#\1#p" | head -1; }     # val NAME < line  (first number)
avg() { sed -n "s#.*[ ]$1=\([0-9]*\)/.*#\1#p" | head -1; }      # avg NAME < line  (avg of avg/p95/max)

printf '%-18s %6s %6s %7s %7s | %6s %6s %6s %6s %6s %6s | %5s\n' \
  scenario frames paint kpix/fr blitK/fr layout texal render compose screen swap txtMiss
limit() {  # limit NAME MAX_KPIX MAX_PAINTED : check mode -- generous, about twice what was measured
  local kpix="$1" painted="$2" name="$3" maxk="$4" maxp="$5"
  awk -v a="$kpix" -v b="$maxk" 'BEGIN{exit !(a+0 > b+0)}' && { echo "  FAIL  $name: ${kpix}k pixels painted per frame (max $maxk)"; FAILS=$((FAILS+1)); }
  awk -v a="$painted" -v b="$maxp" 'BEGIN{exit !(a+0 > b+0)}' && { echo "  FAIL  $name: $painted widgets repainted per frame (max $maxp)"; FAILS=$((FAILS+1)); }
}
row() {  # row NAME [MAX_KPIX MAX_PAINTED] : read the perf line and print one row
  local line; line=$(send "1 * visual perf" | sed 's/^1 //')
  [ $# -ge 3 ] && LIM+=("$1|$(echo "$line" | val 'pcPixels/frame')|$(echo "$line" | val 'pcPainted/frame')|$2|$3")
  local n; n=$(echo "$line" | val sampled)
  printf '%-18s %6s %6s %7.0f %7.0f | %6s %6s %6s %6s %6s %6s | %5s\n' "$1" "$n" \
    "$(echo "$line" | val 'pcPainted/frame')" \
    "$(awk -v p="$(echo "$line" | val 'pcPixels/frame')" 'BEGIN{print p/1000}')" \
    "$(awk -v p="$(echo "$line" | val 'pcBlitPixels/frame')" 'BEGIN{print p/1000}')" \
    "$(echo "$line" | avg phLayout)" "$(echo "$line" | avg phTexAlloc)" "$(echo "$line" | avg phRender)" \
    "$(echo "$line" | avg phCompose)" "$(echo "$line" | avg phScreen)" "$(echo "$line" | avg phSwap)" \
    "$(echo "$line" | val 'pcTextMiss/frame')"
}
drive() {  # drive TAB "command template with @N" : STEPS steps, each ends in a fresh frame
  local tab="$1" tmpl="$2" cmds=() n=0 i
  send "1 tabs write activeTab=$tab" "2 * visual stable 200 4000" >/dev/null
  send "1 * visual perf reset" >/dev/null
  for i in $(seq 1 "$STEPS"); do
    n=$((n+1)); cmds+=("$n ${tmpl//@N/$i}")
    n=$((n+1)); cmds+=("$n * visual hash fresh")
  done
  send "${cmds[@]}" >/dev/null
}

# idle: nothing happens
send "1 tabs write activeTab=7" "2 * visual stable 300 4000" >/dev/null
send "1 * visual perf reset" >/dev/null; sleep 3; row "idle (3 s)" 1 1

send "1 live.run custom:toggle" >/dev/null; send "1 * visual perf reset" >/dev/null; sleep 4
row "ticker 20/s" 1200 14; send "1 live.run custom:toggle" >/dev/null

drive 7 "live.input write typed-@N"           ; row "echo label" 300 10
drive 1 "input.area write line @N of typed text and a few more words to wrap"; row "type in TextArea" 800 10
drive 4 "data.view write scrollY=@N"          ; row "scroll 10k ListView" 600 10
drive 3 "layout.scroll write scrollOffsetY=@N"; row "scroll ScrollView"
drive 4 "data.table write scrollY=@N"        ; row "scroll DataTable"
drive 1 "tabs write activeTab=@N"             ; row "switch tabs (junk)"
send "1 tabs write activeTab=0" "2 * visual stable 200 3000" >/dev/null
send "1 * visual perf reset" >/dev/null
cmds=(); n=0
for i in $(seq 1 "$STEPS"); do
  w=$((1000 - (i % 6) * 40)); h=$((720 - (i % 5) * 30))
  n=$((n+1)); cmds+=("$n * visual resize $w $h"); n=$((n+1)); cmds+=("$n * visual hash fresh")
done
send "${cmds[@]}" >/dev/null; row "resize window"
echo
if [ "$MODE" = "check" ]; then
  for entry in "${LIM[@]}"; do
    IFS='|' read -r name kpix painted maxk maxp <<<"$entry"
    kpix=$(awk -v p="$kpix" 'BEGIN{print p/1000}')
    limit "$kpix" "$painted" "$name" "$maxk" "$maxp"
  done
  [ "$FAILS" -eq 0 ] && { echo "perf scenarios: within limits"; exit 0; }
  echo "perf scenarios: $FAILS limit(s) exceeded"; exit 1
fi
echo "paint = widgets repainted/frame, kpix = thousand pixels of texture painted/frame,"
echo "blitK = thousand pixels blitted into parents/frame; phases are avg us/frame."
