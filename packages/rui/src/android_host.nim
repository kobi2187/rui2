## What an RUI app on Android can ask of the Activity it runs in.
##
## raylib runs the app inside a NativeActivity (android_native_app_glue): its
## `android_main` calls the C `main`, which `ruiAndroidMain` defines. A host
## app -- Kotlin, or Flutter's Android side -- starts that Activity with an
## Intent, and passes what the RUI side needs as String extras:
##
## ```nim
## ruiAndroidMain:
##   let screen = intentExtra("screen", "home")
##   let app = newApp("Demo", 360, 800)
##   app.setRootWidget(buildScreen(screen))
##   app.run()
## ```
##
## On the desktop the same calls answer as if nothing was passed, so one
## program builds for both.

when defined(android):
  {.compile: "android_glue.c".}
  proc ruiIntentExtra(key: cstring, buf: cstring, bufLen: cint): cint {.importc: "rui_intent_extra".}
  proc ruiDisplayDpi(): cint {.importc: "rui_display_dpi".}
  proc ruiNightMode(): cint {.importc: "rui_night_mode".}

proc intentExtra*(key: string, default = ""): string =
  ## The String extra `key` of the Intent that started the Activity; `default`
  ## when there is none (always, on the desktop).
  when defined(android):
    var buf = newString(4096)
    let n = ruiIntentExtra(key.cstring, buf.cstring, buf.len.cint)
    if n < 0: return default
    buf.setLen(n)
    buf
  else:
    default

proc displayDpi*(): int =
  ## The display's density in dots per inch: Android's own figure (160 is its
  ## 1x), 96 on the desktop.
  when defined(android): int(ruiDisplayDpi())
  else: 96

proc systemNightMode*(): bool =
  ## Whether Android is in dark mode (system_scheme.nim asks); false elsewhere.
  when defined(android): ruiNightMode() != 0
  else: false

template ruiAndroidMain*(body: untyped) =
  ## The program's entry point on Android, and an ordinary top-level block
  ## everywhere else. Build the Android library with `--app:lib --noMain`.
  when defined(android):
    proc NimMain() {.importc.}
    proc main(argc: cint, argv: cstringArray): cint {.exportc, cdecl.} =
      NimMain()       # module initialisation: --noMain leaves it to us
      body
      0
  else:
    body
