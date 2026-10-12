## A button shows its state: hover and press change what is drawn, without waiting
## for something else to lay it out. Colours are applied in `layout`, so the state
## handlers have to ask for one; before they did, repainting redrew the old colours.
## Read back from the GPU. Run under Xvfb by tools/run_tests.sh.

import rui
import raylib
import std/[options, unittest, monotimes]

initWindow(400, 200, "button states")
setTraceLogLevel(TraceLogLevel.Error)
setCurrentTheme(brandTheme(daylightSpec()))
animationsEnabled = false          # a state change snaps, so one frame shows it

proc scene(): tuple[root: Widget, b: Button] =
  let root = newVStack(padding = 8.0)
  let b = newButton(text = "Hover me")
  root.addChild b
  root.bounds = Rect(x: 0, y: 0, width: 400, height: 200)
  root.layoutPass(); root.renderPass()
  (root, b)

proc pixels(w: Widget): seq[Color] =
  let img = loadImageFromTexture(w.cachedTexture.get().texture)
  for y in 0 ..< img.height:
    for x in 0 ..< img.width: result.add getImageColor(img, x, y)

proc event(kind: EventKind, b: Button): GuiEvent =
  GuiEvent(kind: kind, mousePos: Point(x: b.bounds.x + 5, y: b.bounds.y + 5),
           timestamp: getMonoTime())

proc settle(root: Widget, b: Button) =
  b.children[0].markDirtyToRoot()       # what the router does after a pointer event
  root.layoutPass(); root.renderPass()

suite "button states":

  test "hovering changes what is drawn, and leaving restores it":
    let (root, b) = scene()
    let off = pixels(root)
    discard b.handleInput(event(evMouseMove, b))
    settle(root, b)
    check pixels(root) != off
    discard b.handleInput(GuiEvent(kind: evMouseMove, mousePos: Point(x: 390, y: 190),
                                   timestamp: getMonoTime()))
    settle(root, b)
    check pixels(root) == off

  test "pressing changes what is drawn":
    let (root, b) = scene()
    let off = pixels(root)
    discard b.handleInput(event(evMouseDown, b))
    settle(root, b)
    check pixels(root) != off
