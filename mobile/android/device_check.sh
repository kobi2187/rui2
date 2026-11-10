#!/bin/bash
# device_check.sh [out-dir] -- the mockups on a real Android device (or an
# emulator), next to their Flutter twins.
#
# Needs one device on adb. Installs the Kotlin host APK, opens each RUI screen
# in RuiActivity through an Intent (`am start -e screen <name>`), takes a
# screenshot with `screencap`, and puts it beside the host renders that
# mobile/compare/compare.sh made (run that first for the Flutter side).
# This is the one check that runs libmain.so for real: raylib on EGL/GLES2,
# the stb text engine, touch input, the display's density.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/mobile/env/env.sh"
OUT="${1:-/tmp/rui_mobile_device}"
CMP="${RUI_COMPARE_OUT:-/tmp/rui_mobile_compare}"
mkdir -p "$OUT"
[ "$(adb devices | sed -n '2,$p' | grep -c 'device$')" -ge 1 ] || { echo "no device on adb"; exit 2; }
abi=$(adb shell getprop ro.product.cpu.abi | tr -d '\r')
echo "device: $(adb shell getprop ro.product.model | tr -d '\r'), $abi, $(adb shell wm density | tr -d '\r')"
"$ROOT/mobile/android/build_rui.sh" "$abi"
( cd "$ROOT/mobile/android" && ./gradlew -q :kotlin-host:assembleDebug )
adb install -r "$ROOT/mobile/android/kotlin-host/build/outputs/apk/debug/kotlin-host-debug.apk" >/dev/null
for s in $(cat "$ROOT/mobile/android/rui/src/main/assets/rui_screens.txt"); do
  adb shell am force-stop dev.rui.kotlinhost
  # RuiActivity is not exported; start it as the app's own launcher would.
  adb shell am start -W -n dev.rui.kotlinhost/dev.rui.android.RuiActivity -e screen "$s" >/dev/null
  sleep "${RUI_DEVICE_WAIT:-3}"
  adb exec-out screencap -p > "$OUT/$s.png"
  if [ -f "$CMP/flutter/$s.png" ]; then
    montage -label "RUI on device" "$OUT/$s.png" -label "Flutter (host)" \
      "$CMP/flutter/$s.png" -tile 2x1 -geometry 360x800+6+0 "$OUT/$s.side.png"
  fi
  echo "  $s -> $OUT/$s.png"
done
adb logcat -d -s raylib:* RUI:* | tail -40 > "$OUT/logcat.txt" || true
