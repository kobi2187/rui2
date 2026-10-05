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
# Built in a few shards, each compiling its examples one after another into
# one shared nimcache: raylib and the toolkit compile once per shard instead
# of once per example, and the cache stays small enough for CI to keep.
snap() {
  local f="$1" shard="$2" n; n="$(echo "${f#examples/}" | tr / _)"; n="${n%.nim}"
  grep -qE "^[^#]*\.(start|run)\(" "$f" || return 0
  if ! nim c $NIMFLAGS --nimcache:"$OUT/nc_shard$shard" -o:"$OUT/bin_$n" "$f" >"$OUT/$n.build" 2>&1; then
    echo "BUILD FAIL $n"; return
  fi
  RUI_LAYOUT_DUMP="$OUT/new/$n.txt" timeout 20 "$OUT/bin_$n" >/dev/null 2>&1 \
    || echo "RUN FAIL $n"
  rm -f "$OUT/bin_$n"
}
shard() {
  local k="$1" i=0 f
  for f in $(ls examples/*.nim examples/*/*.nim); do
    [ $((i % SHARDS)) -eq "$k" ] && snap "$f" "$k"
    i=$((i + 1))
  done
}
export -f snap shard; export OUT
SHARDS="${RUI_TEST_JOBS:-$(nproc)}"; export SHARDS
rm -f "$OUT"/new/*.txt
seq 0 $((SHARDS - 1)) | xargs -P "$SHARDS" -I{} bash -c 'shard {}'
if [ "$MODE" = "update" ]; then
  rm -f tests/layout_snapshots/*.txt; cp "$OUT"/new/*.txt tests/layout_snapshots/
  echo "updated $(ls tests/layout_snapshots | wc -l) snapshots"
else
  diff -ru tests/layout_snapshots "$OUT/new" && echo "layout unchanged ($(ls "$OUT"/new | wc -l) snapshots)"
fi
