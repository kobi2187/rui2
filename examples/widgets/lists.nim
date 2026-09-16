## Lists and selection
##
## ListBox, ListView and ComboBox: virtual scrolling, single vs multi select,
## and keyboard navigation.
##
##   nim c -r -d:useGraphics examples/widgets/lists.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os, sets, strutils]

let app = newApp("RUI2 - Lists", 640, 520)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")
let summary = newLabel(text = "nothing selected", fontSize = 15.0).named("summary")
root.addChild(summary)

proc report(text: string) =
  summary.text = text
  summary.isDirty = true
  summary.layoutDirty = true

# ComboBox -----------------------------------------------------------------
root.addChild(newLabel(text = "ComboBox:", fontSize = 14.0).named("t1"))
let combo = newComboBox(items = @["Small", "Medium", "Large", "Extra large"],
                        initialSelectedIndex = 1).named("combo")
combo.onSelect = proc(index: int) =
  report("combo -> " & combo.items[index])
root.addChild(combo)

# ListBox: keyboard-driven, single select ----------------------------------
root.addChild(newLabel(text = "ListBox (arrows + Enter):",
                       fontSize = 14.0).named("t2"))
let box = newListBox(items = @["alpha", "beta", "gamma", "delta", "epsilon"],
                     itemHeight = 20.0, visibleRows = 4).named("box")
box.onItemActivate = proc(index: int) =
  report("listbox activated -> " & box.items[index])
root.addChild(box)

# ListView: ctrl-click multi select, ten thousand rows ----------------------
root.addChild(newLabel(text = "ListView (10k rows, ctrl-click to multi-select):",
                       fontSize = 14.0).named("t3"))
var manyRows: seq[string] = @[]
for i in 0 ..< 10_000:
  manyRows.add("row " & $i)

# Only the rows on screen are ever drawn, so the row count barely matters.
let view = newListView(items = manyRows, itemHeight = 24.0, visibleRows = 6,
                       multiSelect = true).named("view")
view.onSelect = proc(selection: HashSet[int]) =
  var picked: seq[string] = @[]
  for idx in selection:
    picked.add($idx)
  report("listview -> " & picked.join(", "))
root.addChild(view)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
