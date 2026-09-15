#!/bin/bash
# run_tests.sh — the whole regression suite.
#
#   ./tools/run_tests.sh            unit tests + example compile + scripted UI tests
#   ./tools/run_tests.sh unit       unit tests only (no display needed)
#
# Unit tests need no GL context: they exercise layout, binding, theming,
# hit-testing and text metrics, all of which are CPU-side. The scripted UI
# tests drive a real window, so they need Xvfb.
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."

MODE="${1:-all}"

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

echo "== unit tests =="
mkdir -p /tmp/rui2_tests
for t in tests/test_*.nim; do
  n="$(basename "$t" .nim)"
  if nim c $NIMFLAGS --nimcache:"/tmp/rui2_tests/nc_$n" \
        -o:"/tmp/rui2_tests/$n" "$t" >/tmp/rt_build.log 2>&1; then
    step "$n" "/tmp/rui2_tests/$n"
  else
    echo "  FAIL  $n (did not compile)"; tail -15 /tmp/rt_build.log | sed 's/^/        /'
    FAIL=$((FAIL+1)); FAILED_NAMES+=("$n (build)")
  fi
done

if [ "$MODE" != "unit" ]; then
  echo
  echo "== examples compile =="
  # A real compile, not `nim check`: naylib's move-only GPU types only fail
  # during the full build.
  for f in examples/*.nim examples/widgets/*.nim examples/baby/*.nim; do
    n="$(basename "$f" .nim)"
    step "compile $n" nim c $NIMFLAGS \
      --nimcache:"/tmp/rui2_tests/ncx_$n" -o:"/tmp/rui2_tests/x_$n" "$f"
  done

  echo
  echo "== scripted UI tests =="
  if command -v Xvfb >/dev/null 2>&1; then
    if nim c $NIMFLAGS examples/pango_showcase.nim >/tmp/rt_build.log 2>&1; then
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

echo
echo "================================"
echo "  $PASS passed, $FAIL failed"
for n in "${FAILED_NAMES[@]:-}"; do [ -n "$n" ] && echo "    - $n"; done
[ "$FAIL" -eq 0 ]
