## Icon buttons, tool buttons, tooltips and separators
##
## IconButton and ToolButton (including toggle mode), Tooltip as a hover
## overlay, and Separator as a divider.
##
##   nim c -r -d:useGraphics examples/widgets/buttons_extra.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]

let app = newApp("RUI2 - Icon and tool buttons", 520, 400)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")
let summary = newLabel(text = "no action yet", fontSize = 15.0).named("summary")
root.addChild(summary)

proc report(text: string) =
  summary.text = text
  summary.isDirty = true
  summary.layoutDirty = true

root.addChild(newLabel(text = "IconButtons:", fontSize = 14.0).named("t1"))
let iconRow = newHStack(spacing = 8.0).named("iconRow")
for (glyph, id) in [("+", "iconAdd"), ("-", "iconDel"), ("?", "iconHelp")]:
  let btn = newIconButton(iconText = glyph, size = 32.0).named(id)
  let captured = glyph
  btn.onClick = some(proc() {.closure.} = report("icon button " & captured))
  iconRow.addChild(btn)
root.addChild(iconRow)

# A separator only claims its cross axis; the stack decides how long it is.
root.addChild(newSeparator(vertical = false, thickness = 1.0).named("sep"))

root.addChild(newLabel(text = "ToolBar with toggles:", fontSize = 14.0).named("t2"))
let bar = newToolBar(barHeight = 40.0, spacing = 4.0, padding = 4.0).named("bar")
for (glyph, caption, id) in [("B", "Bold", "tbBold"),
                             ("I", "Italic", "tbItalic"),
                             ("U", "Under", "tbUnder")]:
  let btn = newToolButton(iconText = glyph, text = caption, size = 28.0,
                          showText = true, toggleable = true).named(id)
  let captured = caption
  btn.onToggle = some(proc(state: bool) {.closure.} =
    report(captured & (if state: " on" else: " off")))
  bar.addChild(btn)
root.addChild(bar)

# A button cannot draw its own tooltip: renderPass clips every widget to its
# own bounds. The Tooltip is a sibling overlay that follows the pointer.
root.addChild(newLabel(text = "Hover the area below for a tooltip:",
                       fontSize = 14.0).named("t3"))
let hoverZone = newZStack().named("hoverZone")
hoverZone.bounds = Rect(x: 0, y: 0, width: 240, height: 60)
hoverZone.addChild(newRectangle(color = Color(r: 220, g: 230, b: 245, a: 255),
                                cornerRadius = 6.0, filled = true).named("hoverBg"))
hoverZone.addChild(newTooltip(text = "This is a tooltip", delay = 0.4).named("tip"))
root.addChild(hoverZone)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
