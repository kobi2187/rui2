## The RUI side of the mobile mockup ladder (mobile/README.md): one program,
## every screen, phone-sized.
##
##   mockups <screen> [theme]       e.g. mockups 02_counter material
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

when isMainModule:
  let name = if paramCount() >= 1: paramStr(1) else: "01_hello"
  let theme = if paramCount() >= 2: paramStr(2) else: "material"
  if name notin screens:
    stderr.writeLine "unknown screen " & name & "; one of:"
    for k in screens.keys: stderr.writeLine "  " & k
    quit 2
  let app = newApp("RUI " & name, PhoneWidth, PhoneHeight, resizable = false)
  app.setTheme(theme)
  app.setRootWidget(screens[name]())
  app.run()
