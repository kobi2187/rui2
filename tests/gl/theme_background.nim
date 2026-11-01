## A theme's background picture is tiled behind the widget tree: an 8x8 tile
## of four 4-pixel squares repeats across the window, `scale` stretches it, and
## the widgets still draw over it (rui_drawing theme_background.nim).

import rui
import std/[options, os]
from raylib import loadImageFromScreen, getImageColor, genImageChecked, exportImage

let dir = getTempDir() / "rui_gl_bg"
createDir dir
let tilePath = dir / "tile.png"

let app = newApp("theme background", 200, 120)
var theme = currentTheme
theme.assets.backgroundPattern = some(tilePath)
let label = newRectangle(color = Color(r: 0, g: 200, b: 0, a: 255)).frame(width = 20, height = 20)
let root = newStack()
root.addChild(newPositioned(left = 150, top = 80, width = 20, height = 20))
root.children[0].addChild(label)
app.setRootWidget(root)

var problems: seq[string]
var frames = 0
app.onFrame = proc() =
  inc frames
  if frames == 1:
    # The tile needs a window to be made in: four 4 px squares, red and blue.
    let img = genImageChecked(8, 8, 4, 4, Color(r: 255, g: 0, b: 0, a: 255),
                              Color(r: 0, g: 0, b: 255, a: 255))
    discard exportImage(img, tilePath)
    currentTheme = theme
    root.isDirty = true
  if frames == 4:
    let shot = loadImageFromScreen()
    proc isRed(x, y: int32): bool = getImageColor(shot, x, y).r > 200 and getImageColor(shot, x, y).b < 60
    proc isBlue(x, y: int32): bool = getImageColor(shot, x, y).b > 200 and getImageColor(shot, x, y).r < 60
    # The tile and its repeats: the same square every 8 px, the other in between.
    if not (isRed(1, 1) and isBlue(5, 1) and isRed(9, 1) and isRed(81, 41) and isBlue(85, 41)):
      problems.add "the picture is not tiled: " & $getImageColor(shot, 1, 1) & " " &
                   $getImageColor(shot, 5, 1) & " " & $getImageColor(shot, 9, 1)
    let w = getImageColor(shot, 160, 90)
    if not (w.g > 150 and w.r < 60):
      problems.add "the widget is not drawn over the background: " & $w
  if frames == 5:
    theme.assets.backgroundScale = some(2'f32)
    currentTheme = theme
    root.isDirty = true
  if frames == 8:
    let shot = loadImageFromScreen()
    # Twice the size: 8 px squares now.
    let a = getImageColor(shot, 2, 2)
    let b = getImageColor(shot, 6, 2)
    let c = getImageColor(shot, 10, 2)
    if not (a.r > 200 and b.r > 200 and c.b > 200):
      problems.add "scale does not stretch the tile: " & $a & " " & $b & " " & $c
app.run(maxFrames = 10)
for p in problems: echo p
if problems.len > 0: quit 1
echo "theme background ok"
