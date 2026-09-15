## Rectangle and Circle
##
## The drawing primitives: fills, outlines and corner radii.
##
##   nim c -r -d:useGraphics examples/widgets/shapes.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]

let app = newApp("RUI2 - Rectangle and Circle", 460, 320)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")

root.addChild(newLabel(text = "Rectangles and circles", fontSize = 16.0).named("title"))

let row = newHStack(spacing = 14.0).named("row")
row.bounds = Rect(x: 0, y: 0, width: 400, height: 80)

let filled = newRectangle(color = Color(r: 70, g: 130, b: 200, a: 255),
                          filled = true).named("filled")
filled.bounds = Rect(x: 0, y: 0, width: 90, height: 60)

let rounded = newRectangle(color = Color(r: 90, g: 180, b: 120, a: 255),
                           cornerRadius = 14.0, filled = true).named("rounded")
rounded.bounds = Rect(x: 0, y: 0, width: 90, height: 60)

let outline = newRectangle(color = Color(r: 190, g: 80, b: 80, a: 255),
                           filled = false).named("outline")
outline.bounds = Rect(x: 0, y: 0, width: 90, height: 60)

let dot = newCircle(color = Color(r: 230, g: 170, b: 60, a: 255),
                    filled = true).named("dot")
dot.bounds = Rect(x: 0, y: 0, width: 60, height: 60)

for w in [Widget(filled), Widget(rounded), Widget(outline), Widget(dot)]:
  row.addChild(w)
root.addChild(row)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
