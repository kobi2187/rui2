## The RUI side of the mobile mockup ladder (mobile/README.md): one program,
## every screen, phone-sized.
##
##   mockups <screen> [theme]       e.g. mockups 02_counter material
##
## On Android the same program is libmain.so inside RuiActivity, and the
## screen comes from the Intent's "screen" extra (mobile/android/build_rui.sh).
##
## Each screen has a Flutter twin of the same name under
## mobile/mockups/flutter/lib/screens/, and mobile/compare/compare.sh renders
## both and diffs them.
import std/[os, tables]
import rui
import screens/[s01_hello, s02_counter, s03_login, s04_inbox]

const
  PhoneWidth* = 360    ## logical pixels (dp): a common Android width
  PhoneHeight* = 800

let screens* = {
  "01_hello": helloScreen,
  "02_counter": counterScreen,
  "03_login": loginScreen,
  "04_inbox": inboxScreen,
}.toOrderedTable

proc showScreen(name, theme: string) =
  let app = newApp("RUI " & name, PhoneWidth, PhoneHeight, resizable = false)
  app.setTheme(theme)
  app.setRootWidget(screens[name]())
  app.run()

when isMainModule:
  ruiAndroidMain:
    # The desktop takes the screen from the command line, Android from the
    # Intent that started RuiActivity (mobile/android/rui/).
    var name = if paramCount() >= 1: paramStr(1) else: intentExtra("screen", "01_hello")
    let theme = if paramCount() >= 2: paramStr(2) else: intentExtra("theme", "material")
    if name notin screens:
      stderr.writeLine "unknown screen " & name & "; one of:"
      for k in screens.keys: stderr.writeLine "  " & k
      when defined(android): name = "01_hello"
      else: quit 2
    showScreen(name, theme)
