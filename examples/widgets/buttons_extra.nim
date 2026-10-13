## Icon buttons, tool buttons, tooltips and separators
##
## IconButton and ToolButton (including toggle mode), a Tooltip wrapping its
## target button, and Separator as a divider.
##
##   nim c -r -d:useGraphics examples/widgets/buttons_extra.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]

let app = newApp("RUI2 - Icon and tool buttons", 520, 400)

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")
let summary = newLabel(text = "no action yet", fontSize = 15.0).named("summary")
root.addChild(summary)

proc report(text: string) =
  summary.text = text
  summary.isDirty = true
  summary.layoutDirty = true

root.addChild(newLabel(text = "IconButtons:", fontSize = 14.0).named("t1"))
let iconRow = newHStack(spacing = 8.0).named("iconRow")
# A proc per widget: closures made in a module-level loop share its variables.
proc addIconButton(glyph, id: string) =
  let btn = newIconButton(iconText = glyph, size = 32.0).named(id)
  btn.onClick = proc() = report("icon button " & glyph)
  iconRow.addChild(btn)

for (glyph, id) in [("+", "iconAdd"), ("-", "iconDel"), ("?", "iconHelp")]:
  addIconButton(glyph, id)
root.addChild(iconRow)

# A separator only claims its cross axis; the stack decides how long it is.
root.addChild(newSeparator(vertical = false, thickness = 1.0).named("sep"))

root.addChild(newLabel(text = "ToolBar with toggles:", fontSize = 14.0).named("t2"))
let bar = newToolBar(barHeight = 40.0, spacing = 4.0, padding = 4.0).named("bar")
proc addToolButton(glyph, caption, id: string) =
  let btn = newToolButton(iconText = glyph, text = caption, size = 28.0,
                          showText = true, toggleable = true).named(id)
  btn.onToggle = proc(state: bool) =
    report(caption & (if state: " on" else: " off"))
  bar.addChild(btn)

for (glyph, caption, id) in [("B", "Bold", "tbBold"),
                             ("I", "Italic", "tbItalic"),
                             ("U", "Under", "tbUnder")]:
  addToolButton(glyph, caption, id)
root.addChild(bar)

# A Tooltip wraps the widget it describes. The tip floats on the overlay
# layer, so it is not clipped by the button's own bounds.
root.addChild(newLabel(text = "Rest the pointer on the button for a tooltip:",
                       fontSize = 14.0).named("t3"))
let tipped = newTooltip(text = "This is a tooltip", delay = 0.4).named("tip")
tipped.addChild(newButton(text = "Hover me").named("hoverTarget"))
let tipRow = newHStack().named("tipRow")   # keeps the button its natural width
tipRow.addChild(tipped)
root.addChild(tipRow)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
