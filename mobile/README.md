# RUI on mobile

The goal: RUI apps on phones that a Flutter developer would accept -- they look
and behave like the Material screens people already know -- and an RUI screen
can be dropped into an existing Android app, whether that app is written in
Kotlin or in Flutter.

This folder is the project: the toolchain, the mockup ladder (the same screens
written in RUI and in Flutter), the tools that put the two side by side, and
the Android integration. Nothing here has backing functionality: the screens
are working mockups, and the yardstick is how close they look to Flutter.

```
mobile/
  env/          setup.sh (installs everything), env.sh (PATH), doctor.sh (checks it)
  mockups/
    rui/        mockups.nim + screens/sNN_name.nim   -- the RUI side
    flutter/    a Flutter app, lib/screens/sNN_name.dart -- the Flutter twins
  compare/      render both on the host, score, side-by-side pictures
  android/      Gradle project: `rui` library (RuiActivity + libmain.so),
                `kotlin-host` app, Robolectric tests; build_rui.sh, device_check.sh
```

## Quick start

```bash
mobile/env/setup.sh
```

```bash
source mobile/env/env.sh && mobile/env/doctor.sh
```

```bash
mobile/compare/compare.sh
```

```bash
mobile/android/build_rui.sh && (cd mobile/android && ./gradlew :kotlin-host:testDebugUnitTest :kotlin-host:assembleDebug)
```

`setup.sh` installs Nim (2.2.x, as CI), naylib, the Android command-line tools,
SDK platform 36, NDK r28c, CMake and Flutter into `~/rui-mobile-tools`; versions
are pinned at its top. `compare.sh` writes to `/tmp/rui_mobile_compare`:
`side/<screen>.png` (RUI | Flutter | difference) and `report.md`.

## How we get feedback

There is no emulator in the cloud sessions (no KVM), and an emulator is slow to
read anyway. So the loop is built from things that run on a plain Linux box:

| What is checked | How | Speed |
|---|---|---|
| Does the RUI screen look like the Flutter one? | `compare/compare.sh`: RUI on Xvfb at 360x800, Flutter through `flutter test` (the real engine, real Roboto and Material icon fonts, shadows on), scored by `compare/score.py` (diff %, blurred diff %, SSIM) | ~30 s for all screens |
| What will the *phone* draw? | `RUI_TEXT_ENGINE=stb compare/render_rui.sh`: the same render with the text engine Android uses (`rui_drawing/text_engine_stb.nim`) | same |
| Does RUI build for Android? | `android/build_rui.sh`: NDK clang, raylib for `PLATFORM_ANDROID`/GLES2, `libmain.so` per ABI | ~1 min per ABI |
| Does a Kotlin app integrate it? | Robolectric (`kotlin-host/src/test`): the host lists the screens, a tap starts `RuiActivity` with the right extras, the manifest runs `libmain` | ~20 s warm |
| Does a Flutter app integrate it? | `flutter build apk` of `mockups/flutter` (its Android side includes `:rui`; Dart calls a method channel) | ~2 min |
| Does it really run? | `android/device_check.sh` with a phone (or an emulator elsewhere) on adb: installs, opens each screen by Intent, screencaps it beside the Flutter render | needs a device |

Robolectric runs no native code, so it checks the Kotlin/Java seam, not the
pixels; the pixels are checked on the host. The gap between the two -- EGL,
the Android input queue, lifecycle -- is what `device_check.sh` is for.

## The ladder

Each rung is one screen, in both toolkits, named the same
(`mockups/rui/screens/s03_login.nim` and `mockups/flutter/lib/screens/s03_login.dart`).
Each adds what the previous ones did not need. A rung is done when its
side-by-side would pass for the same app and its scores stop improving.

| # | Screen | Exercises | Status | SSIM (first run) |
|---|---|---|---|---|
| 01 | hello | text, one filled button, centring | written | 0.969 |
| 02 | counter | AppBar, FAB, state | written | 0.942 |
| 03 | login | text fields, password, checkbox, full-width button, text button | written | 0.800 |
| 04 | inbox | list tiles with avatars, scrolling, bottom navigation, badge | written | 0.682 |
| 05 | settings | sections, switches, sliders, dividers, list subtitles | next | |
| 06 | detail | hero image, chips, cards, elevated surfaces | | |
| 07 | dashboard | grid of cards, progress, charts (sparkline/plot) | | |
| 08 | sheet & dialog | bottom sheet, modal dialog, snackbar, scrim | | |
| 09 | tabs & drawer | tab bar with pages, navigation drawer | | |
| 10 | chat | long list, input bar above the keyboard, bubbles | | |

## What the comparison found (first run)

From `side/*.png`; each is a task for RUI, not for the comparison:

1. **Font size units.** RUI's `fontSize` is in points (Pango at 96 dpi), so 14
   draws 18.7 px; Flutter's is logical pixels. Every text is a third larger.
   Decide: dp everywhere (Flutter's meaning) or a conversion in the theme.
2. **No density independence.** On a phone, one RUI pixel is one physical
   pixel: a 420 dpi screen shows everything at about 40 % size. Needs a
   scale (Android: `displayDpi()/160`) applied to layout and to text/texture
   rasterisation (not a blur-up of a 1x picture).
3. **AppBar** draws a bold title and a divider on a white bar; Material 3:
   regular 22 px title, no divider, bar in the canvas colour.
4. **FAB** is a circle in the accent colour; Material 3: a 16 px rounded
   square in primary-container (#EADDFF) with a dark icon.
5. **TextInput** is a pill (the theme's radius 20); Material 3 outlined
   fields have 4 px corners and are 56 px tall.
6. **Hyperlink** is blue and underlined; a Flutter `TextButton` is primary-coloured
   text without underline -- RUI lacks a "text button" variant of Button.
7. **ScrollView** draws a frame and a horizontal scroll bar even when nothing
   overflows; a phone list has neither (scroll bars appear while scrolling).
8. **Avatar** picks saturated colours with black bold initials; Material 3:
   primary-container with on-primary-container text.
9. **Icons**: RUI draws Unicode symbols (☰ ✉ ⚙ ✎); Flutter uses the Material
   icon font. RUI needs an icon font path (Material Symbols is Apache-2.0).
10. **BottomNav** is already close (indicator pill, badge, labels); its bar is
    shorter (56 vs 80) and lacks the surface-container tint.

## Android integration, as built

- `packages/rui/src/android_host.nim`: `ruiAndroidMain:` (the program's entry
  point as a NativeActivity), `intentExtra(key)`, `displayDpi()`,
  `systemNightMode()`. On the desktop they answer as if nothing was passed, so
  one program builds for both.
- Text: `pango_text.nim` keeps its caches and draw calls; the layout engine
  under it is chosen in `text_engine.nim` -- Pango on the desktop, stb_truetype
  on Android (`text_engine_stb.nim`: fonts by family from assets and
  `/system/fonts`, kerning, fallback fonts, wrapping, carets; no complex-script
  shaping or bidi yet). Line metrics and glyph advances are rounded the way
  Pango's hinted metrics round them, so both engines lay out the same: same
  line heights and wrap points, widths within 2 px
  (`tests/test_text_engine_stb.nim`), SSIM 0.988-0.9999 between the two
  renders of each rung.
- No GLFW on Android: idle waiting uses the main thread's `ALooper`, mouse
  buttons use raylib's polling, system dark mode comes from the Activity
  configuration.
- `android/rui`: a Java library (so it builds inside any host, whatever its
  Kotlin setup): `RuiActivity` (NativeActivity, `lib_name=main`),
  `RuiActivity.intent(context, screen, theme)`, `RuiScreens.list(context)`.
- `android/kotlin-host`: a plain Kotlin Activity with a button per screen.
- `mockups/flutter/android`: includes `:rui`; `lib/rui_bridge.dart` calls the
  `dev.rui/rui` channel, `MainActivity.kt` starts `RuiActivity`. Each row of the
  Flutter app's screen list has an "RUI" button beside it (Android only).

## Roadmap

| Milestone | What | State |
|---|---|---|
| M0 | Toolchain, doctor | done |
| M1 | Host comparison loop, rungs 01-04 | done |
| M2 | RUI cross-compiles for Android; Kotlin + Flutter hosts build; Robolectric | done: both APKs build and carry libmain.so; 5 Robolectric tests pass; not yet run on a device |
| M3 | First device run: lifecycle (pause/resume, surface lost/recreated, GL context loss and texture re-upload), back button | |
| M4 | Density independence (finding 2) and text units (finding 1) | |
| M5 | Material 3 fidelity: findings 3-10, one widget at a time, ladder scores up | |
| M6 | Rungs 05-10 | |
| M7 | Soft keyboard and IME (`TextInput` on Android: show/hide, composing text, insets) | |
| M8 | Text engine: HarfBuzz shaping + bidi in the stb engine, or Android's own text stack through JNI | |
| M9 | Embedding as a View (SurfaceView / Flutter PlatformView) instead of a whole Activity | |
| M10 | Accessibility (TalkBack) and iOS | |

## Notes for whoever picks this up

- Run `mobile/compare/compare.sh` after any widget change that touches the
  ladder, and look at `side/*.png`, not only the numbers: a better SSIM can
  come from a worse screen (a blank area matches a blank area).
- Flutter's test harness draws a black outline instead of every shadow unless
  `debugDisableShadows = false` (`test/render_test.dart` sets it).
- nimble's own download of its package list fails behind a CONNECT-only proxy
  (405); `setup.sh` fetches it with curl.
- Robolectric would download its Android framework jar at test time, outside
  Gradle; `kotlin-host/build.gradle.kts` fetches it as a Gradle dependency and
  runs Robolectric offline (and opens the JDK internals it needs on JDK 17+).
- Maven Central sometimes answers 429 (rate limit) to busy shared networks;
  rerunning Gradle after a minute gets through, as its cache fills.
- `.github/workflows/mobile.yml` runs the Android build, Robolectric and the
  comparison on every change to `mobile/` or `packages/`, and uploads the
  side-by-side pictures.
- `flutter` warns about running as root in the containers; harmless.
