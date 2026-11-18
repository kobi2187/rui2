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
# rui_widgets' data sources import db_connector/db_sqlite, whose functions Nim
# loads from libsqlite3.so when the program starts. Android gives apps no such
# library (SQLite is not a public NDK library), so every RUI program would
# print "could not load: libsqlite3.so" and exit before its first line. Link
# SQLite in instead: the amalgamation, built by the NDK, and --dynlibOverride.
SQLITE_VERSION=3500400; SQLITE_YEAR=2025
SQLITE_HOME="${RUI_MOBILE_HOME:-$HOME/rui-mobile-tools}/sqlite"
SQLITE_DIR="$SQLITE_HOME/sqlite-amalgamation-$SQLITE_VERSION"
if [ ! -f "$SQLITE_DIR/sqlite3.c" ]; then
  mkdir -p "$SQLITE_HOME"
  curl -fsSL --retry 4 -o "$SQLITE_HOME/sqlite.zip" \
    "https://www.sqlite.org/$SQLITE_YEAR/sqlite-amalgamation-$SQLITE_VERSION.zip"
  (cd "$SQLITE_HOME" && unzip -qo sqlite.zip)
fi
for abi in "${ABIS[@]}"; do
  case "$abi" in
    arm64-v8a)   cpu=arm64; triple=aarch64-linux-android ;;
    armeabi-v7a) cpu=arm;   triple=armv7a-linux-androideabi ;;
    x86_64)      cpu=amd64; triple=x86_64-linux-android ;;
    *) echo "unknown ABI $abi"; exit 2 ;;
  esac
  mkdir -p "$JNI/$abi" "$SQLITE_HOME/$abi"
  CC="$TC/$triple$API-clang"
  SQLITE_O="$SQLITE_HOME/$abi/sqlite3-$SQLITE_VERSION-meta.o"
  [ -f "$SQLITE_O" ] || "$CC" -c -O2 -fPIC -DSQLITE_THREADSAFE=1 -DSQLITE_OMIT_LOAD_EXTENSION \
    -DSQLITE_ENABLE_COLUMN_METADATA -o "$SQLITE_O" "$SQLITE_DIR/sqlite3.c"
  ( cd "$ROOT" && nim c --hints:off --warnings:off -d:release \
      --os:android --cpu:$cpu --app:lib --noMain -d:useGraphics \
      -d:AndroidNdk="$ANDROID_NDK_HOME" \
      --cc:clang --clang.exe:"$CC" --clang.linkerexe:"$CC" \
      --passL:"-Wl,-z,max-page-size=16384" \
      --dynlibOverride:sqlite3 --passL:"$SQLITE_O" \
      $DEP --nimcache:"/tmp/rui_android_nc_$abi" \
      -o:"$JNI/$abi/libmain.so" "$MAIN" )
  # Nothing may be left to dlopen at start-up but Android's public libraries.
  if strings "$JNI/$abi/libmain.so" | grep -q 'libsqlite3.so'; then
    echo "  $abi: libmain.so still loads libsqlite3.so at run time"; exit 1
  fi
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
