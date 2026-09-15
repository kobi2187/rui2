## Checkbox and RadioButton
##
## Toggling, initial state, and exclusive selection across a radio group.
##
##   nim c -r -d:useGraphics examples/widgets/checkbox.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]

let app = newApp("RUI2 - Checkbox and RadioButton", 460, 340)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")

let summary = newLabel(text = "", fontSize = 16.0).named("summary")

let optA = newCheckbox(text = "Enabled by default",
                       initialChecked = true).named("optA")
let optB = newCheckbox(text = "Off by default",
                       initialChecked = false).named("optB")
let optC = newCheckbox(text = "Disabled", disabled = true).named("optC")

proc refresh() =
  summary.text = "A=" & $optA.checked & "  B=" & $optB.checked
  summary.isDirty = true
  summary.layoutDirty = true

optA.onToggle = some(proc(v: bool) {.closure.} = refresh())
optB.onToggle = some(proc(v: bool) {.closure.} = refresh())

root.addChild(summary)
for w in [Widget(optA), Widget(optB), Widget(optC)]:
  root.addChild(w)

root.addChild(newLabel(text = "Pick one:", fontSize = 14.0).named("radioTitle"))
var selected = "red"
for (caption, value, id) in [("Red", "red", "rRed"),
                             ("Green", "green", "rGreen"),
                             ("Blue", "blue", "rBlue")]:
  let r = newRadioButton(text = caption, value = value,
                         selectedValue = selected).named(id)
  root.addChild(r)

refresh()

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
