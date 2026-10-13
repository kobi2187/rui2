#!/bin/bash
# resize_probe.sh -- screenshot every gallery tab at several window sizes, to see
# whether the layout follows the window. Shots land in /tmp/resize_probe/script/shots.
#   RESIZE_SIZES="700x500 1280x800" tools/resize_probe.sh
set -u
cd "$(dirname "$(readlink -f "$0")")/.."
export PATH="$HOME/.nimble/bin:/root/.nimble/bin:$PATH"
OUT=/tmp/resize_probe; DISP=:94; mkdir -p "$OUT"
DEP=""; for p in naylib yaml db_connector; do d="$(nimble path $p 2>/dev/null | tail -1)"; [ -n "$d" ] && DEP="$DEP --path:$d"; done
nim c --hints:off --warnings:off -d:useGraphics -d:ruiInspect -d:ruiTestKeys $DEP \
  --nimcache:/tmp/rui2_tests/nc_probe -o:$OUT/gallery examples/gallery/gallery.nim >$OUT/build.log 2>&1 || { tail $OUT/build.log; exit 2; }
SCRIPT=$OUT/script
Xvfb $DISP -screen 0 1920x1200x24 -nolisten tcp >/dev/null 2>&1 & XP=$!
DISPLAY=$DISP $OUT/gallery --script $SCRIPT >$OUT/app.log 2>&1 & AP=$!
trap 'kill $AP $XP 2>/dev/null' EXIT
for _ in $(seq 1 100); do [ -d $SCRIPT ] && break; sleep 0.1; done; sleep 2
send() { rm -f $SCRIPT/responses.txt; printf '%s\n' "$@" > $SCRIPT/c.tmp && mv $SCRIPT/c.tmp $SCRIPT/commands.txt
  for _ in $(seq 1 400); do [ -f $SCRIPT/responses.txt ] && [ ! -f $SCRIPT/commands.txt ] && { cat $SCRIPT/responses.txt; return; }; sleep 0.05; done; }
TABS=(Basics Input Pickers Layout Lists Graphics Menus Live)
for size in ${RESIZE_SIZES:-700x500 1280x800}; do
  w=${size%x*}; h=${size#*x}
  send "1 * visual resize $w $h" "2 * visual stable 250 4000" >/dev/null; sleep 1
  for i in "${!TABS[@]}"; do
    send "1 tabs write activeTab=$i" "2 * visual stable 250 4000" "3 * visual shot ${size}-${TABS[$i]}.png" >/dev/null
  done
done
ls $SCRIPT/shots
