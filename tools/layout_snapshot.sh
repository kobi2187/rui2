#!/bin/bash
# layout_snapshot.sh [check|update]
# Lays every example out once without a window and records each widget's
# type, id and rect (RUI_LAYOUT_DUMP). `update` rewrites tests/layout_snapshots/;
# `check` (the default) diffs against it. A layout change that moves something
# shows up as a line-level diff naming the widget.
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
MODE="${1:-check}"
export PATH="$HOME/.nimble/bin:/root/.nimble/bin:$PATH"
export RUI_PREFERENCES=/nonexistent/rui-preferences.yaml
DEP=""
for pkg in naylib yaml; do
  p="$(nimble path "$pkg" 2>/dev/null | tail -1)"; [ -n "$p" ] && DEP="$DEP --path:$p"
done
export NIMFLAGS="--hints:off --warnings:off -d:useGraphics $DEP"
OUT=/tmp/rui2_snap; mkdir -p "$OUT/new" tests/layout_snapshots
snap() {
  local f="$1" n; n="$(echo "${f#examples/}" | tr / _)"; n="${n%.nim}"
  grep -qE "\.start\(|\.run\(" "$f" || return 0
  if ! nim c $NIMFLAGS --nimcache:"$OUT/nc_$n" -o:"$OUT/bin_$n" "$f" >"$OUT/$n.build" 2>&1; then
    echo "BUILD FAIL $n"; return
  fi
  RUI_LAYOUT_DUMP="$OUT/new/$n.txt" timeout 20 "$OUT/bin_$n" >/dev/null 2>&1 \
    || echo "RUN FAIL $n"
}
export -f snap; export OUT
ls examples/*.nim examples/*/*.nim | xargs -P "$(nproc)" -I{} bash -c 'snap {}'
if [ "$MODE" = "update" ]; then
  rm -f tests/layout_snapshots/*.txt; cp "$OUT"/new/*.txt tests/layout_snapshots/
  echo "updated $(ls tests/layout_snapshots | wc -l) snapshots"
else
  diff -ru tests/layout_snapshots "$OUT/new" && echo "layout unchanged ($(ls "$OUT"/new | wc -l) snapshots)"
fi
