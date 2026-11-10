#!/bin/bash
# render_flutter.sh <out-dir> -- each Flutter mockup screen to <out-dir>/<screen>.png
#
# No device and no display: `flutter test` lays the screens out and paints them
# with the real engine (Skia/Impeller software path), at 360x800, DPR 1.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/mobile/env/env.sh"
OUT="$(mkdir -p "$1" && cd "$1" && pwd)"
ROBOTO="${RUI_ROBOTO_DIR:-/usr/share/fonts/truetype/roboto/unhinted/RobotoTTF}"
ICONS="$FLUTTER_HOME/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf"
cd "$ROOT/mobile/mockups/flutter"
flutter pub get >/dev/null
RUI_FLUTTER_OUT="$OUT" RUI_ROBOTO_DIR="$ROBOTO" RUI_MATERIAL_ICONS="$ICONS" \
  flutter test test/render_test.dart >"$OUT/.flutter_test.log" 2>&1 \
  || { echo "FLUTTER RENDER FAIL"; tail -30 "$OUT/.flutter_test.log"; exit 1; }
for f in "$OUT"/*.png; do echo "  flutter $(basename "$f" .png) -> $f"; done
