## An app that has drawn with the shaders (a Button's box, its shadow) closes
## without crashing. A GPU object held in a plain global was destroyed after
## closeWindow had torn the GL context down -- SIGSEGV on every exit -- and
## no check ever closed a window the way an app does.

import rui
from raylib import getWindowPosition

let app = newApp("clean exit", 300, 200)
let root = newVStack()
root.addChild(newButton(text = "Draws through the SDF shaders"))
root.addChild(newCheckbox(text = "and a smooth tick", initialChecked = true))
app.setRootWidget(root)
app.placeWindow(50, 40)               # before the window exists: applied when it opens
var frames = 0
var seen: (float32, float32)
app.onFrame = proc() =
  inc frames
  if frames == 4:
    let p = getWindowPosition()
    seen = (p.x, p.y)
app.run(maxFrames = 5)
if seen != (50'f32, 40'f32):
  echo "placeWindow: window at ", seen, ", wanted (50, 40)"
  quit 1
echo "exited cleanly"
