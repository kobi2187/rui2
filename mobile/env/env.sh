# env.sh -- `source mobile/env/env.sh` puts the mobile toolchain on PATH.
# Installed by mobile/env/setup.sh; override any of these before sourcing.
export RUI_MOBILE_HOME="${RUI_MOBILE_HOME:-$HOME/rui-mobile-tools}"
export NIM_HOME="${NIM_HOME:-$RUI_MOBILE_HOME/nim}"
export ANDROID_HOME="${ANDROID_HOME:-$RUI_MOBILE_HOME/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export FLUTTER_HOME="${FLUTTER_HOME:-$RUI_MOBILE_HOME/flutter}"
# Pick the one NDK setup.sh installed (or the newest present).
if [ -z "${ANDROID_NDK_HOME:-}" ] && [ -d "$ANDROID_HOME/ndk" ]; then
  ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$(ls "$ANDROID_HOME/ndk" | sort -V | tail -1)"
fi
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-}"
export PATH="$NIM_HOME/bin:$HOME/.nimble/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$FLUTTER_HOME/bin:$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true
