## Menus
##
## MenuBar with dropdown Menus of MenuItems (shortcuts, checkable items,
## separators), plus a ContextMenu popped up on demand.
##
##   nim c -r -d:useGraphics examples/widgets/menus.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]

let app = newApp("RUI2 - Menus", 560, 400)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 10.0, padding = 0.0).named("root")
let summary = newLabel(text = "no menu action yet", fontSize = 15.0).named("summary")

proc report(text: string) =
  summary.text = text
  summary.isDirty = true
  summary.layoutDirty = true

proc item(caption, shortcut, id: string, checkable = false): MenuItem =
  result = newMenuItem(text = caption, shortcut = shortcut,
                       checkable = checkable).named(id)
  let captured = caption
  result.onClick = proc() = report("clicked: " & captured)

# MenuBar draws each child Menu's title in the strip and hangs the dropdown
# underneath. It grows its own bounds to cover whichever dropdown is open --
# renderPass composites children into the parent's bounds-sized texture.
let bar = newMenuBar(barHeight = 28.0).named("bar")

let fileMenu = newMenu(title = "File", minWidth = 180.0).named("fileMenu")
fileMenu.addChild(item("New", "Ctrl+N", "miNew"))
fileMenu.addChild(item("Open", "Ctrl+O", "miOpen"))
fileMenu.addChild(newMenuItem(separator = true).named("miSep1"))
fileMenu.addChild(item("Quit", "Ctrl+Q", "miQuit"))
bar.addChild(fileMenu)

let viewMenu = newMenu(title = "View", minWidth = 180.0).named("viewMenu")
let wrapItem = item("Word wrap", "", "miWrap", checkable = true)
wrapItem.onToggle = proc(checked: bool) =
  report("word wrap " & (if checked: "on" else: "off"))
viewMenu.addChild(wrapItem)
viewMenu.addChild(item("Zoom in", "Ctrl++", "miZoomIn"))
bar.addChild(viewMenu)

root.addChild(bar)

let body = newVStack(spacing = 10.0, padding = 20.0).named("body")
body.addChild(summary)
body.addChild(newLabel(text = "Click a menu title above.",
                       fontSize = 14.0).named("hint"))

# ContextMenu takes no space until openAt() places it.
let ctx = newContextMenu(minWidth = 160.0).named("ctx")
ctx.addChild(item("Cut", "Ctrl+X", "ctxCut"))
ctx.addChild(item("Copy", "Ctrl+C", "ctxCopy"))
ctx.addChild(newMenuItem(separator = true).named("ctxSep"))
ctx.addChild(item("Paste", "Ctrl+V", "ctxPaste"))

let popBtn = newButton(text = "Show context menu").named("popBtn")
popBtn.onClick = proc() =
  ctx.openAt(200.0, 220.0)
body.addChild(popBtn)
body.addChild(ctx)

root.addChild(body)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
