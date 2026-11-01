## A theme's focus glow is drawn round the control the keyboard has reached,
## outside its bounds (FocusRing's chrome), and goes with the focus.

import rui
from raylib import loadImageFromScreen, getImageColor

let app = newApp("focus glow", 240, 120)
app.setTheme(brandTheme(cyberpunkSpec()))         # cyan glow, dark canvas
let a = newButton(text = "Glow").frame(width = 80, height = 32)
let b = newButton(text = "Other").frame(width = 80, height = 32)
let root = newStack()
root.addChild(newPositioned(left = 40, top = 40, width = 80, height = 32))
root.children[0].addChild(a)
root.addChild(newPositioned(left = 150, top = 40, width = 80, height = 32))
root.children[1].addChild(b)
app.setRootWidget(root)

proc cyan(c: Color): int = int(c.g) + int(c.b) - 2 * int(c.r)   # how cyan, over the dark canvas

var problems: seq[string]
var frames = 0
var before = 0
app.onFrame = proc() =
  inc frames
  if frames == 2:
    let shot = loadImageFromScreen()
    before = cyan(getImageColor(shot, 80, 36))          # just above the button
    app.keyboardMode = true                            # the rings show while the keyboard drives
    app.focusManager.setFocus(a)
  if frames == 5:
    let shot = loadImageFromScreen()
    let lit = cyan(getImageColor(shot, 80, 36))
    if lit <= before + 20:
      problems.add "no glow above the focused button: " & $before & " -> " & $lit
    app.focusManager.setFocus(b)
  if frames == 8:
    let shot = loadImageFromScreen()
    let after = cyan(getImageColor(shot, 80, 36))
    if after > before + 10:
      problems.add "the glow stayed after focus left: " & $before & " -> " & $after
    if cyan(getImageColor(shot, 190, 36)) <= before + 20:
      problems.add "no glow round the newly focused button: " & $before & " -> " &
                   $cyan(getImageColor(shot, 190, 36))
app.run(maxFrames = 10)
for p in problems: echo p
if problems.len > 0: quit 1
echo "focus glow ok"
