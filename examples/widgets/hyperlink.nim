## Hyperlink
##
## Link text with visited state.
##
##   nim c -r -d:useGraphics examples/widgets/hyperlink.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]

let app = newApp("RUI2 - Hyperlink", 460, 260)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")

let note = newLabel(text = "Nothing opened yet", fontSize = 15.0).named("note")
root.addChild(note)

for (caption, url, id) in [("Nim language", "https://nim-lang.org", "l1"),
                           ("Raylib", "https://raylib.com", "l2")]:
  let link = newHyperlink(text = caption, url = url).named(id)
  root.addChild(link)

root.addChild(newLabel(
  text = "Visited links change colour once clicked.",
  fontSize = 13.0).named("hint"))

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
