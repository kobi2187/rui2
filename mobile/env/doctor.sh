#!/bin/bash
# doctor.sh -- is everything the mobile track needs here, and does it run?
# Each line: ok / MISSING, with the version found. Exit 1 if anything is missing.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/mobile/env/env.sh"
bad=0
check() {   # check <name> <command...>
  local name="$1"; shift
  local out
  if out="$("$@" 2>/dev/null | head -1)" && [ -n "$out" ]; then
    printf '  ok       %-14s %s\n' "$name" "$out"
  else
    printf '  MISSING  %-14s (mobile/env/setup.sh)\n' "$name"; bad=1
  fi
}
check nim        sh -c 'nim -v | head -1'
check naylib     sh -c 'nimble path naylib | tail -1 | sed "s/.*naylib-\([0-9.]*\).*/\1/"'
check java       sh -c 'java -version 2>&1 | grep -v JAVA_TOOL | head -1'
check sdkmanager sh -c 'sdkmanager --version 2>/dev/null | grep -v JAVA_TOOL'
check ndk        sh -c '[ -d "$ANDROID_NDK_HOME" ] && basename "$ANDROID_NDK_HOME"'
check platform   sh -c 'ls "$ANDROID_HOME/platforms" | tr "\n" " "'
check adb        sh -c 'adb version | head -1'
check flutter    sh -c 'flutter --version 2>/dev/null | grep -m1 Flutter'
check Xvfb       sh -c 'command -v Xvfb'
check imagemagick sh -c 'convert -version | head -1 | cut -c1-40'
check python-pil python3 -c 'import PIL, numpy; print("Pillow", PIL.__version__, "numpy", numpy.__version__)'
check roboto     sh -c 'ls /usr/share/fonts/truetype/roboto/unhinted/RobotoTTF/Roboto-Regular.ttf'
# No emulator: it needs KVM. A phone over adb (or an emulator on another
# machine) is used by mobile/android/device_check.sh when one is attached.
if [ -e /dev/kvm ]; then echo "  ok       kvm            an Android emulator could run here"
else echo "  note     kvm            none: no emulator here; host renders + Robolectric instead"; fi
devices=$(adb devices 2>/dev/null | sed -n '2,$p' | grep -c device)
echo "  note     adb devices    ${devices:-0} attached"
exit $bad
