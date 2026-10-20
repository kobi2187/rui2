## A shaped App (-d:ruiShaped, see shaped_window.nims) on Xvfb, which runs no
## compositor: the method must be the OS shape (a see-through window would show
## black), the window must take the skin's size, placing the shape must put its
## visible corner -- not the window's -- where asked, and the app must open,
## draw and close cleanly.

import rui
import std/[unittest, os]
from raylib import getWindowPosition, getScreenWidth, getScreenHeight, Vector2

let app = newApp("shaped", 300, 300)          # the skin is 420x420: it wins
app.setWindowShape(currentSourcePath().parentDir.parentDir.parentDir /
                   "examples" / "shaped" / "skin.png")
app.placeShape(100, 80)
let root = newVStack(padding = 120.0)
root.addChild(newButton(text = "Inside the skin"))
app.setRootWidget(root)

var frames = 0
var seenWindow: Vector2
var seenSize: (int32, int32)
var seenShape: Rect
app.onFrame = proc() =
  inc frames
  if frames == 4:                              # the window has moved by now
    seenWindow = getWindowPosition()
    seenSize = (getScreenWidth(), getScreenHeight())
    seenShape = app.shapeBounds
app.run(maxFrames = 5)

suite "shaped window":
  test "Xvfb has no compositor: the OS shape is chosen, from the skin's alpha":
    check app.shaped.caps.platform == spX11
    check not app.shaped.caps.compositor
    check app.shaped.meth == smOsShape
    check app.shaped.caps.windowDepth > 0

  test "the window takes the skin's size":
    check seenSize == (420'i32, 420'i32)

  test "the skin stops short of the window's corner, so the widgets are laid out in its box":
    let box = app.shaped.shapeBox
    let content = app.contentBounds
    check content == Rect(x: box.x.float32, y: box.y.float32,
                          width: box.w.float32, height: box.h.float32)
    check root.bounds.x == content.x and root.bounds.width == content.width

  test "a BeOS-style shape (a tab over a full body) keeps the whole window":
    let tabbed = newApp("tabbed", 400, 300)
    tabbed.setWindowShape(proc(x, y: float32): float32 =
      if y < 24: (if x < 150: 1 else: 0) else: 1)
    check tabbed.contentBounds == Rect(x: 0, y: 0, width: 400, height: 300)

  test "placeShape puts the visible shape's corner where asked, not the window's":
    let box = app.shaped.shapeBox
    check box.x > 0 and box.y > 0              # the skin has a transparent margin
    check seenShape.x == 100 and seenShape.y == 80
    check seenWindow.x == float32(100 - box.x) and seenWindow.y == float32(80 - box.y)
    check seenShape.width == box.w.float32 and seenShape.height == box.h.float32
