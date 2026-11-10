#!/bin/bash
# build_rui.sh [abi...] -- cross-compile the RUI mockups into libmain.so for
# Android, into rui/src/main/jniLibs/<abi>/, where the `rui` library module
# packages it (and every app that depends on it).
#
#   mobile/android/build_rui.sh                 arm64-v8a and x86_64
#   mobile/android/build_rui.sh arm64-v8a       just one
#   RUI_ANDROID_MAIN=path/to/app.nim ...        another RUI program
#
# The NDK's clang does the C side; raylib is built for PLATFORM_ANDROID with
# GLES2 (naylib's `android` branch), text uses the stb engine
# (rui_drawing/text_engine_stb.nim), and Roboto comes along as an asset.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/mobile/env/env.sh"
[ -n "$ANDROID_NDK_HOME" ] || { echo "no NDK: run mobile/env/setup.sh android"; exit 2; }
MAIN="${RUI_ANDROID_MAIN:-mobile/mockups/rui/mockups.nim}"
API=24                                   # minSdk, as in rui/build.gradle.kts
TC="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
ABIS=("$@"); [ ${#ABIS[@]} -gt 0 ] || ABIS=(arm64-v8a x86_64)
DEP=""
for pkg in naylib yaml db_connector; do
  p="$(nimble path "$pkg" 2>/dev/null | tail -1)"; [ -n "$p" ] && DEP="$DEP --path:$p"
done
JNI="$ROOT/mobile/android/rui/src/main/jniLibs"
for abi in "${ABIS[@]}"; do
  case "$abi" in
    arm64-v8a)   cpu=arm64; triple=aarch64-linux-android ;;
    armeabi-v7a) cpu=arm;   triple=armv7a-linux-androideabi ;;
    x86_64)      cpu=amd64; triple=x86_64-linux-android ;;
    *) echo "unknown ABI $abi"; exit 2 ;;
  esac
  mkdir -p "$JNI/$abi"
  CC="$TC/$triple$API-clang"
  ( cd "$ROOT" && nim c --hints:off --warnings:off -d:release \
      --os:android --cpu:$cpu --app:lib --noMain -d:useGraphics \
      -d:AndroidNdk="$ANDROID_NDK_HOME" \
      --cc:clang --clang.exe:"$CC" --clang.linkerexe:"$CC" \
      --passL:"-Wl,-z,max-page-size=16384" \
      $DEP --nimcache:"/tmp/rui_android_nc_$abi" \
      -o:"$JNI/$abi/libmain.so" "$MAIN" )
  echo "  $abi: $JNI/$abi/libmain.so ($(du -h "$JNI/$abi/libmain.so" | cut -f1))"
done
# The stb engine looks for fonts in the APK's assets/fonts first.
FONTS="$ROOT/mobile/android/rui/src/main/assets/fonts"
mkdir -p "$FONTS"
ROBOTO="${RUI_ROBOTO_DIR:-/usr/share/fonts/truetype/roboto/unhinted/RobotoTTF}"
for w in Regular Bold Italic BoldItalic Medium; do
  [ -f "$ROBOTO/Roboto-$w.ttf" ] && cp "$ROBOTO/Roboto-$w.ttf" "$FONTS/"
done
# The screens on offer, for host apps to list (dev.rui.android.RuiScreens).
ls "$ROOT/mobile/mockups/rui/screens" | sed -n 's/^s\(.*\)\.nim$/\1/p' \
  > "$ROOT/mobile/android/rui/src/main/assets/rui_screens.txt"
