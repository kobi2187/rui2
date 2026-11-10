#!/bin/bash
# setup.sh -- install everything the mobile track needs, idempotently.
#
#   mobile/env/setup.sh            all of it
#   mobile/env/setup.sh nim        just one part: nim | android | flutter | apt
#
# Everything goes under $RUI_MOBILE_HOME (default ~/rui-mobile-tools), nothing
# system-wide except the apt packages. Afterwards: `source mobile/env/env.sh`.
#
# Versions are pinned here and only here; bump them deliberately.
set -euo pipefail

NIM_VERSION=2.2.14            # CI uses 2.2.x (.github/actions/setup)
CMDLINE_TOOLS=16111833        # Android command-line tools build
ANDROID_PLATFORM=36           # compileSdk / targetSdk
BUILD_TOOLS=36.0.0
NDK_VERSION=28.2.13676358     # NDK r28c (LTS line)
CMAKE_VERSION=3.31.6
FLUTTER_VERSION=3.47.9

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"
mkdir -p "$RUI_MOBILE_HOME"
dl() { curl -fL --retry 4 --retry-delay 2 -sS -o "$2" "$1"; }

do_apt() {
  local pkgs="xvfb imagemagick xdotool unzip zip libpango1.0-dev libcairo2-dev
    libasound2-dev libx11-dev libxrandr-dev libxi-dev libgl1-mesa-dev libglu1-mesa-dev
    libxcursor-dev libxinerama-dev libxkbcommon-dev libwayland-bin fonts-dejavu-core
    fonts-roboto clang cmake ninja-build pkg-config libgtk-3-dev mesa-utils"
  local missing=""
  for p in $pkgs; do dpkg -s "$p" >/dev/null 2>&1 || missing="$missing $p"; done
  [ -z "$missing" ] && { echo "apt: all present"; return; }
  echo "apt: installing$missing"
  local sudo=""; [ "$(id -u)" = 0 ] || sudo=sudo
  $sudo apt-get update -qq && $sudo apt-get install -y -qq --no-install-recommends $missing >/dev/null
}

do_nim() {
  if [ ! -x "$NIM_HOME/bin/nim" ] || ! "$NIM_HOME/bin/nim" -v | grep -q "$NIM_VERSION"; then
    echo "nim: installing $NIM_VERSION"
    local t; t="$(mktemp -d)"
    dl "https://nim-lang.org/download/nim-$NIM_VERSION-linux_x64.tar.xz" "$t/nim.tar.xz"
    rm -rf "$NIM_HOME"; mkdir -p "$NIM_HOME"
    tar -xJf "$t/nim.tar.xz" -C "$NIM_HOME" --strip-components=1
    rm -rf "$t"
  fi
  echo "nim: $("$NIM_HOME/bin/nim" -v | head -1)"
  # nimble's own download of the package list is refused by HTTPS proxies that
  # only speak CONNECT (it answers 405); curl fetches the same file.
  if [ ! -s "$HOME/.nimble/packages_official.json" ]; then
    mkdir -p "$HOME/.nimble"
    dl https://raw.githubusercontent.com/nim-lang/packages/master/packages.json \
      "$HOME/.nimble/packages_official.json"
  fi
  # The same bounds as packages/*/*.nimble and CI.
  nimble install -y "naylib@>=25.42.0" "yaml@>=2.2.0" db_connector >/dev/null
  echo "nim: naylib $(nimble path naylib | tail -1 | sed 's/.*naylib-//')"
}

do_android() {
  if [ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
    echo "android: installing command-line tools $CMDLINE_TOOLS"
    local t; t="$(mktemp -d)"
    dl "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS}_latest.zip" "$t/clt.zip"
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    unzip -q "$t/clt.zip" -d "$t" && rm -rf "$ANDROID_HOME/cmdline-tools/latest"
    mv "$t/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"; rm -rf "$t"
  fi
  # sdkmanager speaks HTTPS through the proxy via JAVA_TOOL_OPTIONS when one is set.
  yes | sdkmanager --licenses >/dev/null 2>&1 || true
  sdkmanager --install "platform-tools" "platforms;android-$ANDROID_PLATFORM" \
    "build-tools;$BUILD_TOOLS" "ndk;$NDK_VERSION" "cmake;$CMAKE_VERSION" >/dev/null
  echo "android: $(ls "$ANDROID_HOME/ndk")  platforms: $(ls "$ANDROID_HOME/platforms")"
}

do_flutter() {
  if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
    echo "flutter: installing $FLUTTER_VERSION"
    local t; t="$(mktemp -d)"
    dl "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" "$t/f.tar.xz"
    tar -xJf "$t/f.tar.xz" -C "$RUI_MOBILE_HOME"; rm -rf "$t"
    git config --global --add safe.directory "$FLUTTER_HOME" || true
  fi
  flutter config --no-analytics >/dev/null 2>&1 || true
  flutter --disable-analytics >/dev/null 2>&1 || true
  flutter config --enable-linux-desktop --android-sdk "$ANDROID_HOME" >/dev/null
  flutter precache --linux --android >/dev/null
  echo "flutter: $(flutter --version 2>/dev/null | head -1)"
}

parts="${*:-apt nim android flutter}"
for p in $parts; do "do_$p"; done
echo "done. source mobile/env/env.sh, then mobile/env/doctor.sh"
