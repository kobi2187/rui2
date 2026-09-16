## Canvas and drag-and-drop
##
## Canvas as an interactive drawing surface, and DragDropArea as a file target.
##
## Drops are not GuiEvents, so the app polls them once per frame with
## pollFileDrops() rather than the widget checking raylib from inside render.
##
##   nim c -r -d:useGraphics examples/widgets/canvas.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os, strutils]

let app = newApp("RUI2 - Canvas and drag/drop", 640, 620)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 10.0, padding = 16.0).named("root")
let summary = newLabel(text = "drag on the canvas to draw",
                       fontSize = 15.0).named("summary")
root.addChild(summary)

proc report(text: string) =
  summary.text = text
  summary.isDirty = true
  summary.layoutDirty = true

let canvas = newCanvas(enableDrawing = true, drawingMode = dmFreehand,
                       defaultColor = Color(r: 30, g: 80, b: 160, a: 255),
                       defaultThickness = 2.0, showGrid = true,
                       gridSize = 20.0).named("canvas")
canvas.bounds = Rect(x: 0, y: 0, width: 580, height: 260)
canvas.onDrawComplete = proc(commands: seq[DrawCommand]) =
  report("canvas: " & $commands.len & " commands")

# Seed one shape from code. Coordinates are canvas-relative, so the shape stays
# put if the canvas is ever moved or re-laid-out.
canvas.addCommand(DrawCommand(kind: dcRectFilled,
                              rect: Rect(x: 20, y: 20, width: 80, height: 50),
                              rectColor: Color(r: 220, g: 140, b: 60, a: 255),
                              rectRounded: true, rectRoundness: 6.0))
root.addChild(canvas)

let modeRow = newHStack(spacing = 6.0).named("modeRow")
for (caption, mode, id) in [("Freehand", dmFreehand, "mFree"),
                            ("Line", dmLine, "mLine"),
                            ("Rect", dmRect, "mRect"),
                            ("Circle", dmCircle, "mCircle")]:
  let btn = newButton(text = caption).named(id)
  let captured = mode
  let capturedName = caption
  btn.onClick = proc() =
    canvas.drawingMode = captured
    report("mode: " & capturedName)
  modeRow.addChild(btn)

let clearBtn = newButton(text = "Clear").named("clearBtn")
clearBtn.onClick = proc() =
  canvas.clearCanvas()
  report("canvas cleared")
modeRow.addChild(clearBtn)
root.addChild(modeRow)

# DragDropArea -------------------------------------------------------------
root.addChild(newLabel(text = "Drop .nim files below:",
                       fontSize = 14.0).named("t1"))
let drop = newDragDropArea(mode = dmFiles, acceptedExtensions = @[".nim"],
                           promptText = "Drag .nim files here",
                           hoverText = "Release to drop",
                           multiple = true).named("drop")
drop.bounds = Rect(x: 0, y: 0, width: 580, height: 110)
drop.onFilesDropped = proc(files: seq[DroppedItem]) =
  var names: seq[string] = @[]
  for f in files:
    names.add(extractFilename(f.path))
  report("dropped: " & names.join(", "))
drop.onFilesRejected = proc(files: seq[string], reason: string) =
  report("rejected " & $files.len & ": " & reason)
root.addChild(drop)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)

# Drops arrive outside the event stream, so the app asks for them each frame.
app.onFrame = proc() = drop.pollFileDrops()

app.start()
