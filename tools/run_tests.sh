#!/bin/bash
# run_tests.sh — the whole regression suite.
#
#   ./tools/run_tests.sh            unit tests (one binary) + GL checks (under a minute)
#   ./tools/run_tests.sh isolated   the same, but every test file its own program
#   ./tools/run_tests.sh full       also builds every example and runs the scripted UI
#                                   tests (for CI; several minutes)
#   RUI_TEST_JOBS=2 ...             how many builds at once (default: the core count)
#
# Unit tests need no GL context: they exercise layout, binding, theming,
# hit-testing and text metrics, all of which are CPU-side. The scripted UI
# tests drive a real window, so they need Xvfb.
set -uo pipefail
shopt -s lastpipe    # so the verdict counters survive the `| tally` pipeline
cd "$(dirname "$(readlink -f "$0")")/.."

MODE="${1:-quick}"   # quick | isolated | full

# Nim may live in a choosenim prefix that is not on a non-login shell's PATH.
export PATH="$HOME/.nimble/bin:/root/.nimble/bin:$PATH"
if ! command -v nim >/dev/null 2>&1; then
  echo "nim not found on PATH" >&2; exit 127
fi

# config.nims resolves the in-repo packages; the two external deps still need
# explicit --path when they are not installed where nim looks by default.
DEP_PATHS=""
for pkg in naylib yaml; do
  p="$(nimble path "$pkg" 2>/dev/null | tail -1)"
  [ -n "${p:-}" ] && [ -d "$p" ] && DEP_PATHS="$DEP_PATHS --path:$p"
done

NIMFLAGS="--hints:off --warnings:off -d:useGraphics $DEP_PATHS"
PASS=0; FAIL=0; FAILED_NAMES=()

step() {  # step <name> <command...>
  local name="$1"; shift
  if "$@" >/tmp/rt_out.log 2>&1; then
    echo "  PASS  $name"; PASS=$((PASS+1))
  else
    echo "  FAIL  $name"; sed 's/^/        /' /tmp/rt_out.log | tail -15
    FAIL=$((FAIL+1)); FAILED_NAMES+=("$name")
  fi
}

# Hermetic: a developer's own ~/.config/rui/preferences.yaml must not change a result.
export RUI_PREFERENCES=/nonexistent/rui-preferences.yaml

JOBS="${RUI_TEST_JOBS:-$(nproc 2>/dev/null || echo 2)}"
LOGS=/tmp/rui2_tests/logs
mkdir -p /tmp/rui2_tests "$LOGS"

# One test, built and run: its own nimcache, so a warm run recompiles only what
# changed. Called in parallel by xargs, hence the exported function; it prints
# one verdict line and keeps the full output in $LOGS for a failure.
unit_test() {
  local t="$1" n; n="$(basename "$t" .nim)"
  if ! nim c $NIMFLAGS --nimcache:"/tmp/rui2_tests/nc_$n" \
        -o:"/tmp/rui2_tests/$n" "$t" >"$LOGS/$n.build" 2>&1; then
    echo "FAIL $n (did not compile)"; return
  fi
  if "/tmp/rui2_tests/$n" >"$LOGS/$n.out" 2>&1; then echo "PASS $n"
  else echo "FAIL $n"; fi
}

# A GL-backed check (tests/gl/), on its own display number so they can overlap.
gl_test() {
  local g="$1" n; n="$(basename "$g" .nim)"
  if ./tools/gl_test.sh "$g" >"$LOGS/gl_$n.out" 2>&1; then echo "PASS gl $n"
  else echo "FAIL gl $n"; fi
}

example_compile() {
  local f="$1" n; n="$(basename "$f" .nim)"
  if nim c $NIMFLAGS --nimcache:"/tmp/rui2_tests/ncx_$n" -o:"/tmp/rui2_tests/x_$n" "$f" \
        >"$LOGS/x_$n.build" 2>&1; then echo "PASS compile $n"
  else echo "FAIL compile $n"; fi
}
export -f unit_test gl_test example_compile
export NIMFLAGS LOGS

# Collect verdicts from a parallel stage, then show the log of any failure.
tally() {  # tally <title> <log-prefix...>  (reads verdict lines on stdin)
  echo "== $1 =="
  local line
  while read -r line; do
    echo "  $line"
    case "$line" in
      PASS*) PASS=$((PASS+1)) ;;
      FAIL*) FAIL=$((FAIL+1)); FAILED_NAMES+=("${line#FAIL }") ;;
    esac
  done
}

# The unit tests are compiled into ONE binary (tests/all_unit.nim, generated
# here from tests/test_*.nim) and run once: the toolkit is compiled a single
# time instead of 27, which is what takes this from ten minutes to under one.
# The GL checks build alongside it. `isolated` builds every test file as its own
# program instead, in parallel -- slower, but a failure then cannot be blamed on
# another test's leftover global state.
unit_single() {
  { for t in tests/test_*.nim; do echo "import $(basename "${t%.nim}")"; done; } > tests/all_unit.nim
  if ! nim c $NIMFLAGS --nimcache:/tmp/rui2_tests/nc_all -o:/tmp/rui2_tests/all \
        tests/all_unit.nim >"$LOGS/all.build" 2>&1; then
    echo "FAIL unit tests (did not compile)"; return
  fi
  if /tmp/rui2_tests/all >"$LOGS/all.out" 2>&1; then
    echo "PASS unit tests ($(grep -c '\[OK\]' "$LOGS/all.out") cases)"
  else
    echo "FAIL unit tests"
  fi
}
export -f unit_single

{
  if [ "$MODE" = "isolated" ]; then
    ls tests/test_*.nim | xargs -P "$JOBS" -I{} bash -c 'unit_test {}'
  else
    unit_single &
  fi
  if command -v Xvfb >/dev/null 2>&1; then
    ls tests/gl/*.nim 2>/dev/null | xargs -P "$JOBS" -I{} bash -c 'gl_test {}'
  fi
  wait
} | sort | tally "unit tests + GL checks"

if [ "$MODE" = "full" ]; then
  # The slow half, for CI: every example built for real (a `nim check` is not
  # enough: naylib's move-only GPU types only fail in the full build), and the
  # scripted UI run.
  ls examples/*.nim examples/widgets/*.nim examples/baby/*.nim 2>/dev/null \
    | xargs -P "$JOBS" -I{} bash -c 'example_compile {}' | sort | tally "examples compile"

  echo
  echo "== scripted UI tests =="
  if command -v Xvfb >/dev/null 2>&1; then
    # -d:ruiTestKeys compiles in the scripting `key` command; -d:ruiInspect
    # compiles in the read-only `inspect` verb. Both are test-only
    # on purpose: scripting is otherwise semantic (address a control, operate
    # it) rather than input emulation, and an ordinary build leaves it out.
    if nim c $NIMFLAGS -d:ruiTestKeys -d:ruiInspect examples/pango_showcase.nim >/tmp/rt_build.log 2>&1; then
      if ./tools/ui_test.sh ./examples/pango_showcase >/tmp/rt_ui.log 2>&1; then
        grep -E "PASS|FAIL" /tmp/rt_ui.log | sed 's/^/  /'
        PASS=$((PASS+1))
      else
        echo "  FAIL  scripted UI tests"; tail -25 /tmp/rt_ui.log | sed 's/^/        /'
        FAIL=$((FAIL+1)); FAILED_NAMES+=("ui_test")
      fi
    else
      echo "  FAIL  pango_showcase (did not compile)"
      FAIL=$((FAIL+1)); FAILED_NAMES+=("pango_showcase build")
    fi
  else
    echo "  SKIP  Xvfb not installed"
  fi
fi

if [ "$FAIL" -gt 0 ]; then
  echo
  echo "== failures (full logs in $LOGS) =="
  for name in "${FAILED_NAMES[@]}"; do
    base="${name%% *}"; base="${base#gl}"; base="${base# }"
    [ "$name" = "unit tests" ] && grep -B2 -E "FAILED|Check failed" "$LOGS/all.out" | head -30 | sed 's/^/    /'
    for f in "$LOGS/$base.build" "$LOGS/$base.out" "$LOGS/gl_$base.out"; do
      [ -s "$f" ] && { echo "--- $f"; tail -15 "$f" | sed 's/^/    /'; }
    done
  done
fi

echo
echo "================================"
echo "  $PASS passed, $FAIL failed"
for n in "${FAILED_NAMES[@]:-}"; do [ -n "$n" ] && echo "    - $n"; done
[ "$FAIL" -eq 0 ]
