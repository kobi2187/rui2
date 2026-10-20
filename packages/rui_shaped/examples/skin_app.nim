## A shaped app: the skin PNG is the window. Drag it to move it; Escape quits.
## Prints which method this machine got.
##
##   nim c -r packages/rui_shaped/examples/skin_app.nim

import raylib, rui_shaped
import std/os

proc main() =
  var shaped = prepareShapedWindow()
  initWindow(420, 420, "rui_shaped skin")
  setTargetFPS(60)
  shaped.confirm()
  echo "shape method: ", shaped.describe()
  var skin = loadImage(currentSourcePath().parentDir / "skin.png")
  shaped.setShape(skin)
  imageAlphaPremultiply(skin)            # the compositor blends premultiplied colour
  let tex = loadTextureFromImage(skin)
  var drag: DragMove
  let hold = if paramCount() >= 1: paramStr(1) else: ""
  var frames = 0
  while not windowShouldClose():
    drag.update(shaped)
    beginDrawing()
    clearBackground(shaped.clearColor)
    beginBlendMode(BlendMode.AlphaPremultiply)
    drawTexture(tex, 0, 0, White)
    endBlendMode()
    drawText("drag me", 160, 190, 20, Color(r: 255, g: 255, b: 255, a: 230))
    endDrawing()
    inc frames
    if hold == "--once" and frames > 90: break

main()
closeWindow()
