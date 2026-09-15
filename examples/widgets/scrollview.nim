## ScrollView
##
## A scrollable region holding more content than fits.
##
##   nim c -r -d:useGraphics examples/widgets/scrollview.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]

let app = newApp("RUI2 - ScrollView", 460, 380)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")

root.addChild(newLabel(text = "Scrollable list below:", fontSize = 16.0).named("title"))

let sv = newScrollView().named("scroll")
sv.bounds = Rect(x: 0, y: 0, width: 400, height: 260)

let inner = newVStack(spacing = 6.0, padding = 6.0).named("inner")
for i in 1 .. 30:
  inner.addChild(newLabel(text = "Row " & $i, fontSize = 14.0).named("row" & $i))
sv.addChild(inner)
root.addChild(sv)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
