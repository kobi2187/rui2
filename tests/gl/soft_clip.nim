## A Clip edge between two pixels moves visibly: the row it cuts through is
## drawn in part, in proportion to how much of it is inside -- what lets a
## wipe or a reader's line glide by fractions of a pixel (Clip, softClip).
## And a `.subpixel()` widget lands between pixels, not snapped to them.

import rui
from raylib import loadImageFromScreen, getImageColor

let app = newApp("soft clip", 200, 120)
let solid = newRectangle(color = Color(r: 0, g: 0, b: 0, a: 255)).frame(width = 200, height = 120)
let clip = newClip(cut = EdgeInsets(top: 40.5))     # the top edge halfway through row 40
clip.addChild(solid)
let bar = newPositioned(left = 0, right = 0, top = 80.5, height = 1).subpixel()
bar.addChild(newRectangle(color = Color(r: 255, g: 0, b: 0, a: 255)))
let root = newStack(fit = StackFit.expand)
root.addChild(clip.frame(width = 200, height = 120))
root.addChild(bar)
app.setRootWidget(root)

var problems: seq[string]
var frames = 0
app.onFrame = proc() =
  inc frames
  if frames == 4:
    let shot = loadImageFromScreen()
    let canvas = getImageColor(shot, 100, 10)       # above the cut: the window
    let half = getImageColor(shot, 100, 40)         # the cut row: between the two
    let full = getImageColor(shot, 100, 60)         # below it: the black rectangle
    proc lum(c: Color): int = c.r.int + c.g.int + c.b.int
    if not (lum(full) < lum(half) and lum(half) < lum(canvas)):
      problems.add "the cut row is not drawn in part: " & $lum(canvas) & " / " &
                   $lum(half) & " / " & $lum(full)
    # The 1 px red bar at y = 80.5 shares itself between rows 80 and 81:
    # each partly red over the black below it, neither fully.
    let a = getImageColor(shot, 100, 80)
    let b = getImageColor(shot, 100, 81)
    if not (a.r in 60'u8 .. 200'u8 and b.r in 60'u8 .. 200'u8):
      problems.add "the sub-pixel bar is not shared between two rows: " & $a & " " & $b
app.run(maxFrames = 6)
for p in problems: echo p
if problems.len > 0: quit 1
echo "soft clip ok"
