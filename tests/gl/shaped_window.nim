## A shaped App (-d:ruiShaped, see shaped_window.nims) on Xvfb, which runs no
## compositor: the method must be the OS shape (a see-through window would show
## black), and the app must open, draw and close cleanly.

import rui
import std/[unittest, os]

let app = newApp("shaped", 420, 420)
app.setWindowShape(currentSourcePath().parentDir.parentDir.parentDir /
                   "examples" / "shaped" / "skin.png")
let root = newVStack(padding = 120.0)
root.addChild(newButton(text = "Inside the skin"))
app.setRootWidget(root)
app.run(maxFrames = 3)

suite "shaped window":
  test "Xvfb has no compositor: the OS shape is chosen, from the skin's alpha":
    check app.shaped.caps.platform == spX11
    check not app.shaped.caps.compositor
    check app.shaped.meth == smOsShape
    check app.shaped.caps.windowDepth > 0
