## Button
##
## Click handling, theme intents, and the disabled state.
##
##   nim c -r -d:useGraphics examples/widgets/button.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]

let app = newApp("RUI2 - Button", 460, 400)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")

let status = newLabel(text = "No clicks yet", fontSize = 16.0).named("status")
var clicks = 0

proc bump(which: string) =
  inc clicks
  status.text = which & " clicked (" & $clicks & " total)"
  status.isDirty = true
  status.layoutDirty = true

root.addChild(status)

for (caption, intent, id) in [("Default", ThemeIntent.Default, "bDefault"),
                              ("Info", ThemeIntent.Info, "bInfo"),
                              ("Success", ThemeIntent.Success, "bSuccess"),
                              ("Warning", ThemeIntent.Warning, "bWarning"),
                              ("Danger", ThemeIntent.Danger, "bDanger")]:
  let b = newButton(text = caption, intent = intent).named(id)
  let name = caption
  b.onClick = proc() = bump(name)
  root.addChild(b)

let off = newButton(text = "Disabled", disabled = true).named("bDisabled")
root.addChild(off)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
