#!/bin/bash
# visual_compare.sh [ref] [example...] -- every runnable example, as it looks at
# `ref` (default origin/main) and as it looks now, side by side.
#
# For a change that should not change what users see -- or that should, and
# you want to see exactly where. Each example is built twice (at `ref`, in a
# temporary worktree, and from the working tree), run on its own Xvfb with
# the same fonts and default preferences, and its window captured after it
# settles. Output in $RUI_VISUAL_OUT (default /tmp/rui_visual_compare):
#
#   before/<ex>.png  after/<ex>.png     the two captures
#   side/<ex>.png                       before | after | difference (changed pixels red)
#   report.tsv                          ex, diff %, blurred diff %, SSIM, size before, size after
#
# Scores come from mobile/compare/score.py. Animated or clock-driven examples
# differ a little between any two runs; look at side/*.png before judging.
#
#   tools/visual_compare.sh                         everything, against origin/main
#   tools/visual_compare.sh HEAD~1 widgets/stacks   one example against the last commit
#   RUI_VISUAL_REUSE=1 tools/visual_compare.sh      keep the binaries of the last run (captures only)
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
ROOT="$PWD"
REF="${1:-origin/main}"; shift || true
ONLY=("$@")
OUT="${RUI_VISUAL_OUT:-/tmp/rui_visual_compare}"
WAIT="${RUI_VISUAL_WAIT:-3}"
JOBS="${RUI_TEST_JOBS:-$(nproc)}"
export PATH="$HOME/.nimble/bin:/root/.nimble/bin:$PATH"
[ -f mobile/env/env.sh ] && source mobile/env/env.sh
export RUI_PREFERENCES=/nonexistent/rui-preferences.yaml
export FONTCONFIG_FILE="$ROOT/tools/fontconfig/fonts.conf"
for t in Xvfb xdotool import compare; do
  command -v $t >/dev/null || { echo "$t is not installed"; exit 2; }
done
DEP=""
for pkg in naylib yaml db_connector; do
  p="$(nimble path "$pkg" 2>/dev/null | tail -1)"; [ -n "$p" ] && DEP="$DEP --path:$p"
done
mkdir -p "$OUT/before" "$OUT/after" "$OUT/side" "$OUT/bin" "$OUT/logs"
rm -f "$OUT"/before/*.png "$OUT"/after/*.png "$OUT"/side/*.png

WT="$OUT/ref-tree"
rm -rf "$WT"; git worktree prune
git worktree add -q --detach "$WT" "$REF" || { echo "cannot check out $REF"; exit 2; }
trap 'git worktree remove --force "$WT" 2>/dev/null' EXIT

# The runnable examples: those that start an app (as layout_snapshot.sh picks).
list() {
  local tree="$1"
  ( cd "$tree" && for f in examples/*.nim examples/*/*.nim; do
      grep -qE "^[^#]*\.(start|run)\(" "$f" && echo "$f"; done )
}
EXAMPLES=()
for f in $(list "$ROOT"); do
  n="${f#examples/}"; n="${n%.nim}"
  if [ ${#ONLY[@]} -gt 0 ]; then
    keep=0; for o in "${ONLY[@]}"; do [ "$n" = "$o" ] && keep=1; done
    [ $keep = 1 ] || continue
  fi
  EXAMPLES+=("$f")
done

# Build: per tree, a few shards each compiling its share into one nimcache.
build_shard() {   # build_shard <tree> <side> <k>
  local tree="$1" side="$2" k="$3" i=0 f n
  for f in "${EXAMPLES[@]}"; do
    if [ $((i % JOBS)) -eq "$k" ] && [ -f "$tree/$f" ]; then
      n="$(echo "${f#examples/}" | tr / _)"; n="${n%.nim}"
      ( cd "$tree" && nim c --hints:off --warnings:off -d:useGraphics $DEP \
          --nimcache:"$OUT/nc_${side}_$k" -o:"$OUT/bin/${side}_$n" "$f" ) \
        >"$OUT/logs/build_${side}_$n.log" 2>&1 || echo "  BUILD FAIL ($side) $n"
    fi
    i=$((i + 1))
  done
}
if [ "${RUI_VISUAL_REUSE:-0}" = 1 ]; then
  echo "reusing the binaries in $OUT/bin"
else
echo "building ${#EXAMPLES[@]} examples at $REF and now..."
for side in before after; do
  tree=$([ $side = before ] && echo "$WT" || echo "$ROOT")
  for k in $(seq 0 $((JOBS - 1))); do build_shard "$tree" $side $k & done
  wait
done
fi

# Run and capture: one Xvfb per job, the window grabbed by its id.
shoot() {   # shoot <display> <binary> <png>
  local d="$1" bin="$2" png="$3" w ap
  [ -x "$bin" ] || return
  ( cd "$(dirname "$bin")" && DISPLAY=":$d" timeout 30 "$bin" >"$png.log" 2>&1 ) & ap=$!
  for _ in $(seq 1 50); do
    w=$(DISPLAY=":$d" xdotool search --onlyvisible --name . 2>/dev/null | head -1)
    [ -n "$w" ] && break; sleep 0.1
  done
  sleep "$WAIT"
  [ -n "${w:-}" ] && DISPLAY=":$d" import -window "$w" "$png" 2>/dev/null
  kill $ap 2>/dev/null; pkill -P $ap 2>/dev/null; wait $ap 2>/dev/null
}
run_job() {   # run_job <k>: every JOBS-th example, both sides, on display 150+k
  local k="$1" d=$((150 + k)) i=0 f n xp
  Xvfb ":$d" -screen 0 1920x1200x24 -nolisten tcp >/dev/null 2>&1 & xp=$!
  for _ in $(seq 50); do [ -S "/tmp/.X11-unix/X$d" ] && break; sleep 0.1; done
  for f in "${EXAMPLES[@]}"; do
    if [ $((i % JOBS)) -eq "$k" ]; then
      n="$(echo "${f#examples/}" | tr / _)"; n="${n%.nim}"
      shoot $d "$OUT/bin/before_$n" "$OUT/before/$n.png"
      shoot $d "$OUT/bin/after_$n" "$OUT/after/$n.png"
    fi
    i=$((i + 1))
  done
  kill $xp 2>/dev/null
}
echo "capturing..."
for k in $(seq 0 $((JOBS - 1))); do run_job $k & done
wait

: >"$OUT/report.tsv"
for f in "${EXAMPLES[@]}"; do
  n="$(echo "${f#examples/}" | tr / _)"; n="${n%.nim}"
  b="$OUT/before/$n.png"; a="$OUT/after/$n.png"
  if [ ! -f "$b" ] || [ ! -f "$a" ]; then
    printf '%s\tmissing\t%s\t%s\n' "$n" "$([ -f "$b" ] && echo ok || echo none)" \
      "$([ -f "$a" ] && echo ok || echo none)" >>"$OUT/report.tsv"; continue
  fi
  sb=$(identify -format '%wx%h' "$b"); sa=$(identify -format '%wx%h' "$a")
  if [ "$sb" = "$sa" ]; then
    scores=$(python3 "$ROOT/mobile/compare/score.py" "$b" "$a")
    compare -fuzz 3% "$b" "$a" "$OUT/side/.$n.diff.png" 2>/dev/null || true
    montage -label before "$b" -label now "$a" -label difference "$OUT/side/.$n.diff.png" \
      -tile 3x1 -geometry +6+0 -pointsize 14 "$OUT/side/$n.png"
  else
    scores=$'size\t-\t-'
    montage -label "before $sb" "$b" -label "now $sa" "$a" -tile 2x1 -geometry +6+0 \
      -pointsize 14 "$OUT/side/$n.png"
  fi
  printf '%s\t%s\t%s\t%s\n' "$n" "$scores" "$sb" "$sa" >>"$OUT/report.tsv"
done
sort -t$'\t' -k2 -g -r "$OUT/report.tsv" | awk -F'\t' '
  { printf "  %-28s diff %6s%%  blur %6s%%  ssim %s  %s -> %s\n", $1, $2, $3, $4, $5, $6 }'
echo "pictures: $OUT/side/"
