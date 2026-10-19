## Theme popups
##
## The popups a theme has to draw, each opened on screen: a combo box's list, a
## menu bar's dropdown and a context menu, all over the same page:
##
##   nim c -r -d:useGraphics examples/widgets/theme_popups.nim [theme]
##
## A screenshot cannot click, so each popup is opened from code at startup.

import rui
import input/popup_field
import std/os

let app = newApp("RUI2 - Theme popups", 1000, 620)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "beos")

let combo = newComboBox(items = @["Starter", "Team", "Enterprise"], initialSelectedIndex = 1)
let bar = newMenuBar(barHeight = 28.0)
let file = newMenu(title = "File", minWidth = 180.0)
file.addChild(newMenuItem(text = "New", shortcut = "Ctrl+N"))
file.addChild(newMenuItem(text = "Open...", shortcut = "Ctrl+O"))
file.addChild(newMenuItem(separator = true))
file.addChild(newMenuItem(text = "Quit", shortcut = "Ctrl+Q"))
bar.addChild(file)
let edit = newMenu(title = "Edit", minWidth = 180.0)
edit.addChild(newMenuItem(text = "Cut"))
edit.addChild(newMenuItem(text = "Copy"))
edit.addChild(newMenuItem(text = "Paste"))
bar.addChild(edit)

let ctx = newContextMenu(minWidth = 180.0)
ctx.addChild(newMenuItem(text = "Cut"))
ctx.addChild(newMenuItem(text = "Copy"))
ctx.addChild(newMenuItem(text = "Paste", checkable = true))

let root = newVStack(spacing = 14.0, padding = 16.0)
root.addChild(bar)
root.addChild(newLabel(text = "The page behind the popups"))
root.addChild(combo)
root.addChild(newButton(text = "Below the menu"))
root.addChild(ctx)
let tipped = newTooltip(text = "Saves the document")
tipped.addChild(newButton(text = "Save"))
root.addChild(tipped)

app.setRootWidget(root)
root.bounds = Rect(x: 0, y: 0, width: 1000, height: 620)
root.layout()
combo.setFieldOpen(combo.list, true)
# A press on the File title, as a click would send it.
discard bar.handleInput(GuiEvent(kind: evMouseDown,
                                 mousePos: Point(x: bar.bounds.x + 16, y: bar.bounds.y + 12)))
ctx.openAt(420, 150)
# A tooltip shows when the pointer rests on it, which a screenshot cannot do:
# show its tip the way it would.
tipped.tip.text = tipped.text
tipped.tip.bounds.x = 520
tipped.tip.bounds.y = 350
showOverlay(tipped.tip)
app.run()
