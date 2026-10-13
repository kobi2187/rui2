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
    let tracker = newHoverTracker()
    discard tracker.setHover(b.children[0])      # what the router does on a move
    settle(root, b)
    check pixels(root) != off
    discard tracker.setHover(nil)
    settle(root, b)
    check pixels(root) == off

  test "pressing changes what is drawn":
    let (root, b) = scene()
    let off = pixels(root)
    discard b.handleInput(event(evMouseDown, b))
    settle(root, b)
    check pixels(root) != off

  test "the pointer leaving the button clears hover; the button never stays lit":
    let (root, b) = scene()
    let off = pixels(root)
    let tracker = newHoverTracker()
    discard tracker.setHover(b.children[0]); settle(root, b)
    check pixels(root) != off
    discard tracker.setHover(nil); settle(root, b)
    check pixels(root) == off

  test "a press released outside the button is not a click and does not stay pressed":
    let (root, b) = scene()
    var clicks = 0
    b.onClick = proc() = inc clicks
    discard b.handleInput(event(evMouseDown, b))
    check b.isPressed
    discard b.handleInput(GuiEvent(kind: evMouseUp, mousePos: Point(x: 390, y: 190),
                                   timestamp: getMonoTime()))
    check not b.isPressed
    check clicks == 0
    releasePointer()
    discard b.handleInput(event(evMouseDown, b))
    discard b.handleInput(event(evMouseUp, b))
    check clicks == 1
    releasePointer()

suite "BeOS bevels, read back from the GPU":
  ## Measured from real R5.0.1 screenshots: a raised button is dark (96) outside,
  ## then its own face colour, then two white lines above-left; below-right dark,
  ## grey (152), then a slightly darker face (216). Pressed swaps the two sides.

  setup:
    setCurrentTheme(createBeosTheme())

  teardown:
    setCurrentTheme(brandTheme(daylightSpec()))

  proc px(root: Widget, w: Widget, dx, dy: int): Color =
    let img = loadImageFromTexture(root.cachedTexture.get().texture)
    # A render texture reads back upside down.
    getImageColor(img, int32(w.bounds.x) + int32(dx), img.height - 1 - (int32(w.bounds.y) + int32(dy)))

  test "a raised button: dark frame, light face, white above-left, grey below-right":
    let (root, b) = scene()
    let w = int(b.bounds.width); let h = int(b.bounds.height)
    check px(root, b, w div 2, 0).r == 96                     # outer frame, top
    check px(root, b, w div 2, 2).r == 255                    # white line inside it
    check px(root, b, w div 2, h - 1).r == 96                 # outer frame, bottom
    check px(root, b, w div 2, h - 2).r == 152                # grey inside it
    check px(root, b, 6, h div 2).r in 225'u8 .. 235'u8       # the 232 face

  test "pressed: the sides swap and the face darkens":
    let (root, b) = scene()
    let w = int(b.bounds.width); let h = int(b.bounds.height)
    discard b.handleInput(event(evMouseDown, b))
    settle(root, b)
    check px(root, b, w div 2, 1).r == 152                    # grey now above-left
    check px(root, b, w div 2, h - 3).r == 255                # white now below-right
    check px(root, b, 6, h div 2).r in 205'u8 .. 225'u8       # the 216 face
    releasePointer()

  test "hovering shows nothing: Be has no hover effect":
    let (root, b) = scene()
    let off = pixels(root)
    discard newHoverTracker().setHover(b.children[0])
    settle(root, b)
    check pixels(root) == off
