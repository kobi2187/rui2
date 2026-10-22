## A real window with a modal open: the page behind it is pictured once and
## stands still (a page widget marked dirty is not repainted), the screen
## behind the dialog is the theme's darker backdrop, and the app exits with
## the modal still open without crashing -- the picture is a GPU texture, and
## one freed after the window closes takes the process down.

import rui
from raylib import loadImageFromScreen, getImageColor

let app = newApp("modal freeze", 320, 240)
let label = newLabel(text = "the page")
let box = newMessageBox(title = "Sure?", message = "Discard changes?")
let root = newVStack()
root.addChild(label)
root.addChild(box)
app.setRootWidget(root)
var painted = 0
let counting: BackdropPainter = proc(area: Rect) = inc painted
setBackdropPainter(counting)                 # runs when the page is pictured

proc brightness(): int =
  let shot = loadImageFromScreen()
  let c = getImageColor(shot, 4, 230)        # page, outside the dialog
  c.r.int + c.g.int + c.b.int

var frames = 0
var before, behind = -1
var paintedWhileOpen = -1
var problems: seq[string]
app.onFrame = proc() =
  inc frames
  case frames
  of 3:
    before = brightness()
    box.show()
  of 6:
    if backdropOf(box) == nil: problems.add "no picture of the page was taken"
    behind = brightness()
    paintedWhileOpen = label.paintPass
    label.isDirty = true                       # the page changes underneath
    label.markDirtyToRoot()
  of 9:
    if label.paintPass != paintedWhileOpen:
      problems.add "the frozen page was repainted"
  else: discard
app.run(maxFrames = 10)                        # ends with the modal open
if behind >= before:
  problems.add "the page behind the dialog is not darker (" & $before & " -> " & $behind & ")"
if painted != 1:
  problems.add "the backdrop painter ran " & $painted & " times, not once"
for p in problems: echo p
if problems.len > 0: quit 1
echo "exited cleanly"
