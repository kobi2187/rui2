## Stacks
##
## VStack, HStack and ZStack, including nesting and content-driven sizing.
##
##   nim c -r -d:useGraphics examples/widgets/stacks.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]

let app = newApp("RUI2 - Stacks", 560, 460)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")

root.addChild(newLabel(text = "HStack (row):", fontSize = 15.0).named("t1"))
let row = newHStack(spacing = 10.0).named("row")
for (caption, id) in [("one", "c1"), ("two", "c2"), ("three", "c3")]:
  row.addChild(newButton(text = caption).named(id))
root.addChild(row)

root.addChild(newLabel(text = "Nested VStack in HStack:", fontSize = 15.0).named("t2"))
let outer = newHStack(spacing = 16.0).named("outer")
for col in 0 .. 1:
  let column = newVStack(spacing = 4.0).named("col" & $col)
  for r in 0 .. 2:
    column.addChild(newLabel(text = "r" & $r & "c" & $col,
                             fontSize = 14.0).named("cell" & $col & $r))
  outer.addChild(column)
root.addChild(outer)

root.addChild(newLabel(text = "ZStack (layered):", fontSize = 15.0).named("t3"))
let z = newZStack().named("z")
z.bounds = Rect(x: 0, y: 0, width: 200, height: 60)
let back = newRectangle(color = Color(r: 90, g: 140, b: 220, a: 255),
                        cornerRadius = 8.0, filled = true).named("zBack")
back.zIndex = 0
let front = newLabel(text = "  on top", fontSize = 16.0,
                     color = WHITE).named("zFront")
front.zIndex = 1
z.addChild(back)
z.addChild(front)
root.addChild(z)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
