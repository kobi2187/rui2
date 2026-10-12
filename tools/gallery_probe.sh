#!/bin/bash
# gallery_probe.sh -- drive the gallery through the scripting protocol and report
# what the screen actually did: screenshots of every tab, whether the window sits
# idle when nothing changes, and how long a widget takes to repaint after a
# change (click, typed text, a running ticker).
#
#   tools/gallery_probe.sh            report: tables and screenshots, always exits 0
#   tools/gallery_probe.sh check      the same, and exit 1 when a threshold is missed
#   PROBE_OUT=dir                     where shots and logs go (default /tmp/gallery_probe)
#   PROBE_LATENCY_MS=250              the slowest acceptable repaint (check mode)
#   PROBE_IDLE_FRAMES=20              most frames an idle tab may present in 1.5 s
#
# Timing is measured inside the app (see docs/visual-testing.md), so the numbers do
# not include this script's file polling. Needs Xvfb; builds the gallery with
# -d:ruiInspect -d:ruiTestKeys, which an ordinary build leaves out.
set -u
cd "$(dirname "$(readlink -f "$0")")/.."
MODE="${1:-report}"
OUT="${PROBE_OUT:-/tmp/gallery_probe}"
LAT_MAX="${PROBE_LATENCY_MS:-250}"
IDLE_MAX="${PROBE_IDLE_FRAMES:-20}"
DISP=:95
export PATH="$HOME/.nimble/bin:/root/.nimble/bin:$PATH"
command -v Xvfb >/dev/null || { echo "Xvfb is not installed"; exit 2; }

DEP_PATHS=""
for pkg in naylib yaml db_connector; do
  p="$(nimble path "$pkg" 2>/dev/null | tail -1)"
  [ -n "${p:-}" ] && [ -d "$p" ] && DEP_PATHS="$DEP_PATHS --path:$p"
done
rm -rf "$OUT"; mkdir -p "$OUT"
BIN="$OUT/gallery"
nim c --hints:off --warnings:off -d:useGraphics -d:ruiInspect -d:ruiTestKeys $DEP_PATHS \
    --nimcache:/tmp/rui2_tests/nc_probe -o:"$BIN" examples/gallery/gallery.nim \
    >"$OUT/build.log" 2>&1 || { echo "gallery did not build"; tail -20 "$OUT/build.log"; exit 2; }

SCRIPT="$OUT/script"
Xvfb "$DISP" -screen 0 1280x800x24 -nolisten tcp >"$OUT/xvfb.log" 2>&1 &
XPID=$!
DISPLAY="$DISP" "$BIN" --script "$SCRIPT" >"$OUT/app.log" 2>&1 &
APID=$!
trap 'kill $APID $XPID 2>/dev/null' EXIT
for _ in $(seq 1 100); do [ -d "$SCRIPT" ] && break; sleep 0.1; done
sleep 2

FAILS=0
fail() { echo "  FAIL  $*"; FAILS=$((FAILS+1)); }
pass() { echo "  ok    $*"; }

# send "line" ...  -> responses on stdout, one per line; numbered by the caller
send() {
  rm -f "$SCRIPT/responses.txt"
  printf '%s\n' "$@" > "$SCRIPT/commands.tmp" && mv "$SCRIPT/commands.tmp" "$SCRIPT/commands.txt"
  for _ in $(seq 1 400); do
    if [ -f "$SCRIPT/responses.txt" ] && [ ! -f "$SCRIPT/commands.txt" ]; then
      cat "$SCRIPT/responses.txt"; return 0
    fi
    kill -0 "$APID" 2>/dev/null || { echo "APP EXITED"; return 1; }
    sleep 0.05
  done
  echo "TIMEOUT"; return 1
}
field() { sed -n "s/.*[ ]$1=\([^ ]*\).*/\1/p" | head -1; }   # field NAME < response

TABS=(Basics Input Pickers Layout Lists Graphics Menus Live)

echo "== screenshots and idle =="
printf '%-10s %-8s %s\n' tab "idle" file
for i in "${!TABS[@]}"; do
  send "1 tabs write activeTab=$i" "2 * visual stable 250 4000" >/dev/null
  a=$(send "1 * visual clock" | field frame)
  sleep 1.5
  b=$(send "1 * visual clock" | field frame)
  idle=$((b - a))
  shot=$(send "1 * visual shot tab$i-${TABS[$i]}.png" | field file)
  printf '%-10s %-8s %s\n' "${TABS[$i]}" "$idle fr" "${shot##*/}"
  [ "$idle" -le "$IDLE_MAX" ] || fail "${TABS[$i]} presented $idle frames in 1.5s while nothing changed (max $IDLE_MAX)"
  if [ -f "$shot" ] && [ "$(head -c 4 "$shot" | tail -c 3)" = "PNG" ]; then :; else fail "${TABS[$i]}: no PNG at $shot"; fi
done

echo
echo "== repaint latency (ms from the change to the frame that showed it) =="
send "1 tabs write activeTab=7" "2 live.echo visual stable 200 4000" >/dev/null

measure() {  # measure NAME TARGET "command lines..." -> prints ms or FAIL
  local name="$1" target="$2"; shift 2
  local r
  r=$(send "1 $target visual arm" "$@" "9 $target visual change 1000" | tail -1)
  case "$r" in
    9\ ms=*) echo "$r" | field ms ;;
    *) echo "none" ;;
  esac
}
lat_row() {  # lat_row NAME N TARGET cmd...   runs N times, prints min/avg/max
  local name="$1" n="$2" target="$3"; shift 3
  local vals=() v
  for k in $(seq 1 "$n"); do
    local cmds=("${@//@N/$k}")      # @N is the iteration, so each run really changes something
    v=$(measure "$name" "$target" "${cmds[@]}")
    [ "$v" = none ] && { printf '%-26s %s\n' "$name" "NO VISUAL CHANGE"; fail "$name: the pane never repainted"; return; }
    vals+=("$v")
  done
  local stats; stats=$(printf '%s\n' "${vals[@]}" | awk 'NR==1{mn=mx=$1} {s+=$1; if($1<mn)mn=$1; if($1>mx)mx=$1} END{printf "min %.1f  avg %.1f  max %.1f", mn, s/NR, mx}')
  printf '%-26s %s\n' "$name" "$stats"
  local mx; mx=$(printf '%s\n' "${vals[@]}" | sort -g | tail -1)
  awk -v m="$mx" -v t="$LAT_MAX" 'BEGIN{exit !(m+0 > t+0)}' && fail "$name: slowest $mx ms > $LAT_MAX ms"
}
lat_row "button click -> label" 10 live.bumped "2 live.bump invoke"
lat_row "typed text -> echo label" 10 live.echo "2 live.input write typed-@N"
send "1 live.run custom:toggle" >/dev/null
lat_row "ticker -> tick label" 8 live.tick
send "1 live.run custom:toggle" >/dev/null

echo
echo "== does a pane that should not change stay unchanged? =="
r=$(send "1 live.bumped visual stable 200 3000" "2 live.bumped visual arm" "3 live.bumped visual change 300" | tail -1)
case "$r" in
  3\ no\ visual\ change*) pass "an unchanged label reports no repaint" ;;
  *) fail "an unchanged label claimed a change: $r" ;;
esac

echo
echo "== frame timings =="
send "1 * visual frames" | sed 's/^1 /   /'
echo
echo "screenshots and logs: $OUT"
if [ "$MODE" = "check" ]; then
  [ "$FAILS" -eq 0 ] && { echo "gallery probe: all thresholds met"; exit 0; }
  echo "gallery probe: $FAILS threshold(s) missed"; exit 1
fi
exit 0
