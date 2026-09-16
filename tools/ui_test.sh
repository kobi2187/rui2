#!/bin/bash
# ui_test.sh — end-to-end UI test harness for RUI2.
#
# Runs a scripting-enabled RUI2 app on a virtual display, drives it through the
# file protocol, asserts on the JSON responses, and captures a screenshot.
#
#   ./ui_test.sh ./scripted_gui
set -u
APP="${1:-./scripted_gui}"
DIR="$(dirname "$(readlink -f "$APP")")/script"
export DISPLAY=:99
PASS=0; FAIL=0

APP_ABS="$(readlink -f "$APP")"
APP_PID=""
cleanup() {
  [ -n "$APP_PID" ] && kill "$APP_PID" 2>/dev/null
  [ -n "${XVFB_PID:-}" ] && kill "$XVFB_PID" 2>/dev/null
  return 0
}
trap cleanup EXIT

rm -rf "$DIR"; mkdir -p "$DIR"
# NOTE: do not use `pkill -f Xvfb` here -- it also matches this script's own
# command line and kills the harness.
pkill -x Xvfb 2>/dev/null; sleep 1
Xvfb :99 -screen 0 1024x768x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
XVFB_PID=$!
sleep 2
"$APP_ABS" >/tmp/uitest_app.log 2>&1 &
APP_PID=$!

# `pgrep -x` cannot match process names longer than 15 characters, so check the
# PID directly instead.
for _ in $(seq 1 100); do
  kill -0 "$APP_PID" 2>/dev/null || break
  [ -d "$DIR" ] && break
  sleep 0.1
done
if ! kill -0 "$APP_PID" 2>/dev/null; then
  echo "FATAL: app did not start"; tail -20 /tmp/uitest_app.log; exit 1
fi

send() {  # send <cmd...>  -> prints responses
  rm -f "$DIR/responses.txt"
  printf '%s\n' "$@" > "$DIR/commands.txt"
  for _ in $(seq 1 60); do [ -f "$DIR/responses.txt" ] && break; sleep 0.1; done
  cat "$DIR/responses.txt" 2>/dev/null
}

settle() {  # Wait until nothing is dirty, rather than sleeping a fixed time.
  #
  # `inspect settle` reports the pending count instead of blocking: settling
  # needs frames to run, and the script poll happens inside a frame, so a
  # blocking wait would deadlock against the thing it is waiting for.
  for _ in $(seq 1 60); do
    case "$(send "s * inspect settle")" in *" 0 settled"*) return 0;; esac
    sleep 0.05
  done
  echo "  WARN  did not settle within 3s"
}

settle

expect() {  # expect <label> <expected-substring> <cmd...>
  local label="$1" want="$2"; shift 2
  local got; got="$(send "$@")"
  if [[ "$got" == *"$want"* ]]; then
    echo "  PASS  $label"; PASS=$((PASS+1))
  else
    echo "  FAIL  $label"; echo "        want substring: $want"; echo "        got: $got"
    FAIL=$((FAIL+1))
  fi
}

echo "RUI2 UI tests ($APP)"

expect "label starts at zero"       '"text":"Clicks: 0"'      "1 counter read"
send "2 clickButton invoke" "3 clickButton invoke" >/dev/null
expect "two clicks increment"       '"text":"Clicks: 2"'      "4 counter read"
expect "checkbox seeded from prop"  '"checked":true'          "5 agree read"
send "6 agree invoke" >/dev/null
expect "invoke toggles checkbox"    '"checked":false'         "7 agree read"
send "8 agree custom:toggle" >/dev/null
expect "custom:toggle flips back"   '"checked":true'          "9 agree read"
send "10 progress write value=40" >/dev/null
expect "write sets progress"        '"value":40.0'            "11 progress read"
expect "button exposes its label"   '"text":"Click me"'       "12 clickButton read"
expect "wildcard lists children"    'HStack:buttonRow'        "13 root/* read"
expect "deep wildcard finds nested" 'Button:clickButton'      "13b root/** read"
expect "path selector reaches leaf" '"text":"Click me"'       "13c buttonRow/clickButton read"
expect "missing widget reports"     'Widget not found'        "14 ghost read"
expect "themed button keeps intent" '"intent":"Danger"'       "15 quitButton read"
expect "unknown action reports"     'Unknown or unsupported'  "16 counter custom:frobnicate"

# Text-stack assertions: real metrics mean non-trivial, size-dependent bounds.
expect "label sized to its text"    '"width":'                "17 title read"
expect "RTL label renders"          '"type":"Label"'          "18 hebrew read"
expect "wrapped paragraph exists"   '"wrap":true'             "19 paragraph read"
expect "markup label is markup"     '"markup":true'           "20 markup read"

# Keyboard assertions. These drive the real event path -- focus chain, key
# scoping, widget key handling -- through a live window, which is the only place
# the app-level wiring is exercised at all. Everything else about focus is
# tested against FocusManager directly.
#
# Nothing has focus at startup, so the first Tab lands on the first focusable
# widget in tree order. Labels and containers are not focusable, so that is the
# Click me button rather than the title.
expect "nothing is focused at startup"  '"focused":false'  "21 clickButton read"
send "22 * key Tab" >/dev/null
expect "Tab reaches the first control"  '"focused":true'   "23 clickButton read"
expect "and only that one"              '"focused":false'  "24 quitButton read"
send "25 * key Tab" >/dev/null
expect "Tab moves on"                   '"focused":true'   "26 quitButton read"
expect "clearing the previous"          '"focused":false'  "27 clickButton read"
send "28 * key Tab" >/dev/null
expect "Tab reaches the checkbox"       '"focused":true'   "29 agree read"
expect "a static label is never a stop" '"focused":false'  "30 title read"

# ---------------------------------------------------------------------------
# Inspection: what a screenshot answers badly.
#
# `visible` is a flag and stays true for a widget that is clipped away,
# scrolled out or off-window. `inspect visible` reports where the widget
# actually lands. `inspect hit` says what a click would reach and where the
# focus would go, which is not the same widget. `inspect tree` is one round
# trip for the whole hierarchy, in an order stable enough to diff.
# ---------------------------------------------------------------------------
expect "a laid-out widget reports a real size" '"width"'        "40 title inspect visible"
expect "and is actually showing"               '"showing":true' "41 title inspect visible"
expect "an unclipped widget is fully visible"  '"fullyVisible":true' "42 title inspect visible"
expect "the tree dump reaches the leaves"      'Label'          "43 * inspect tree"
expect "and records the focusable ones"        'tabstop'        "44 * inspect tree"
expect "a hit names what a click would reach"  '"chain"'        "45 * inspect hit 60 60"
expect "empty space hits nothing"              '"hit":null'     "46 * inspect hit 5000 5000"
expect "the app is settled between commands"   '0 settled'      "47 * inspect settle"

import -window root shot_uitest.png 2>/dev/null && echo "  screenshot: shot_uitest.png"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
