## rui_shaped -- non-rectangular app windows, by the best method this machine has.
##
## Optional (not part of the `rui` barrel). The method is chosen at start from
## what the system can do (detect.nim): a see-through window with soft edges
## and click-through where there is a compositor, an OS-clipped window where
## there is not, a plain rectangle where neither works. The app draws the same
## way in every case and gives the shape once, as an alpha mask (a PNG's
## alpha, or a coverage function for a procedural or animated shape).
##
## ```nim
## import raylib, rui_shaped
##
## var shaped = prepareShapedWindow()     # before initWindow: detects, sets flags
## initWindow(420, 420, "skin")
## shaped.confirm()                       # after: checks what the window got
## echo shaped.describe()
## let skin = loadImage("skin.png")
## shaped.setShape(skin)                  # the PNG's alpha is the shape
## while not windowShouldClose():
##   beginDrawing()
##   clearBackground(shaped.clearColor)   # see-through, or the backdrop
##   ...                                  # draw the skin with premultiplied alpha
##   endDrawing()
## ```
##
## In a RUI app this is all done by the App: build with `-d:ruiShaped` (a
## `<app>.nims` with `switch("define", "ruiShaped")` does it) and call
## `app.setWindowShape("skin.png")` before `app.run()`; dragging the background
## moves the window (examples/shaped/skin_app.nim). Without the flag rui does
## not import this package, and calling setWindowShape is a compile error that
## says so.
##
## Measured trade-offs and platform notes: spikes/REPORT.md.

import raylib
import std/os
import rui_shaped/[detect, mask, x11]
when defined(windows):
  import rui_shaped/win32

export detect, mask

type ShapedWindow* = object
  caps*: ShapeCaps
  meth*: ShapeMethod
  backdrop*: Color         ## what the rectangle method shows outside the shape
  lastRects: seq[ShapeRect]
  dpy: ptr Display
  win: XWindow

proc detectPlatform(): ShapePlatform =
  when defined(windows): spWindows
  elif defined(macosx): spMacOS
  elif defined(linux) or defined(bsd):
    when defined(wayland):
      if getEnv("WAYLAND_DISPLAY").len > 0: return spWayland
    if getEnv("DISPLAY").len > 0: spX11 else: spOther
  else: spOther

proc detectCaps*(): ShapeCaps =
  ## What the system offers, before any window exists: the platform, and on
  ## X11 the SHAPE extension, a running compositor and a 32-bit visual.
  result.platform = detectPlatform()
  if result.platform != spX11: return
  let x = x11()
  if not x.ok: return
  let d = x.openDisplay(nil)
  if d == nil: return
  result.x11 = true
  if x.shapeOk:
    var ev, er: cint
    result.shapeExt = x.shapeQuery(d, ev.addr, er.addr) != 0
  result.compositor = x.compositorRunning(d)
  result.argbVisual = x.hasArgbVisual(d)
  discard x.closeDisplay(d)

proc prepareShapedWindow*(softEdges = true, clickThrough = true,
                          backdrop = Color(r: 32, g: 32, b: 36, a: 255)): ShapedWindow =
  ## Call before initWindow: finds what the system can do, picks the method
  ## and sets the window flags it needs (undecorated, and a transparent
  ## framebuffer for the see-through methods).
  result.caps = detectCaps()
  result.meth = chooseMethod(result.caps, softEdges, clickThrough)
  result.backdrop = backdrop
  if result.meth.needsTransparentFramebuffer:
    setConfigFlags(flags(WindowUndecorated, WindowTransparent))
  else:
    setConfigFlags(flags(WindowUndecorated))

proc confirm*(sw: var ShapedWindow) =
  ## Call after initWindow: learns what the window really got (on X11, its
  ## depth -- 32 when the framebuffer has alpha) and steps down if a
  ## see-through method was not granted.
  if sw.caps.platform == spX11 and sw.caps.x11:
    let x = x11()
    sw.dpy = x.openDisplay(nil)
    if sw.dpy != nil:
      sw.win = cast[ptr XWindow](getWindowHandle())[]
      sw.caps.windowDepth = x.windowDepth(sw.dpy, sw.win)
  sw.meth = confirmMethod(sw.caps, sw.meth)

proc clearColor*(sw: ShapedWindow): Color =
  ## Clear each frame with this: fully transparent for the see-through
  ## methods, the backdrop otherwise (outside an OS shape it is never seen).
  if sw.meth.needsTransparentFramebuffer: Color(r: 0, g: 0, b: 0, a: 0)
  else: sw.backdrop

proc describe*(sw: ShapedWindow): string = $sw.meth & ": " & describe(sw.meth)

proc setShapeRects*(sw: var ShapedWindow, rects: seq[ShapeRect]) =
  ## Give the window this shape (the see-through methods draw it themselves;
  ## this sets the regions the OS clips to or passes clicks by). Skipped when
  ## the shape has not changed: reshaping is a round trip to the window system.
  if rects == sw.lastRects: return
  sw.lastRects = rects
  if not (sw.meth.setsBoundingRegion or sw.meth.setsInputRegion): return
  case sw.caps.platform
  of spX11:
    if sw.dpy == nil: return
    let x = x11()
    var xr = newSeq[XRectangle](rects.len)
    for k, r in rects:
      xr[k] = XRectangle(x: r.x.cshort, y: r.y.cshort, width: r.w.cushort, height: r.h.cushort)
    let p = if xr.len > 0: xr[0].addr else: nil
    if sw.meth.setsBoundingRegion:
      x.shapeRects(sw.dpy, sw.win, ShapeBounding, 0, 0, p, xr.len.cint, ShapeSet, Unsorted)
    if sw.meth.setsInputRegion:
      x.shapeRects(sw.dpy, sw.win, ShapeInput, 0, 0, p, xr.len.cint, ShapeSet, Unsorted)
    discard x.flush(sw.dpy)
  of spWindows:
    when defined(windows):
      discard applyWindowRegion(getWindowHandle(), rects)
  else: discard

proc setShape*(sw: var ShapedWindow, mask: AlphaMask, threshold: uint8 = 128) =
  ## The shape from an alpha mask: the opaque part (alpha >= `threshold`).
  sw.setShapeRects(mask.toRects(threshold))

proc setShape*(sw: var ShapedWindow, image: Image, threshold: uint8 = 128) =
  ## The shape from an image's alpha channel (a PNG skin).
  let colors = loadImageColors(image)
  var m = AlphaMask(width: image.width, height: image.height,
                    alpha: newSeq[uint8](image.width * image.height))
  for i in 0 ..< m.alpha.len: m.alpha[i] = colors[i].a
  sw.setShape(m, threshold)

proc setShape*(sw: var ShapedWindow, width, height: int,
               inside: proc(x, y: float32): float32, step = 3) =
  ## The shape from a coverage function (0 outside .. 1 inside) -- the same
  ## one a shader draws -- sampled every `step` pixels: cheap enough to call
  ## each frame for an animated shape.
  sw.setShapeRects(rectsFromFunc(width, height, inside, step))

type DragMove* = object
  ## Moving an undecorated window by dragging its body: it has no title bar.
  active: bool
  startWin: Vector2       ## the window's position when the drag began
  startPointer: Vector2   ## the pointer's screen position then

proc screenPointer(sw: ShapedWindow): (bool, Vector2) =
  ## The pointer on the screen, from the OS. The window-relative position
  ## raylib reports changes as the window moves -- a frame or more after it
  ## is asked to -- and a drag built on it runs away.
  case sw.caps.platform
  of spX11:
    if sw.dpy != nil:
      let (ok, x, y) = x11().pointerOnScreen(sw.dpy, sw.win)
      return (ok, Vector2(x: x.float32, y: y.float32))
  of spWindows:
    when defined(windows):
      let (ok, x, y) = cursorOnScreen()
      return (ok, Vector2(x: x.float32, y: y.float32))
  else: discard
  (false, Vector2())

proc update*(d: var DragMove, sw: ShapedWindow, allowStart = true) =
  ## Call once a frame. A press that reaches the window (only the shape, for
  ## the click-through methods) and a drag moves the window with the pointer.
  ## `allowStart` false: this press belongs to something else (a button, a
  ## field) and must not start a drag.
  if isMouseButtonPressed(MouseButton.Left) and allowStart:
    let (ok, p) = sw.screenPointer()
    let win = getWindowPosition()
    d.active = true
    d.startWin = win
    # Without the OS's answer, the screen position is the window's plus the
    # window-relative one -- right at the moment of the press, which is all
    # the start needs.
    d.startPointer = if ok: p else: Vector2(x: win.x + getMousePosition().x,
                                            y: win.y + getMousePosition().y)
  elif not isMouseButtonDown(MouseButton.Left):
    d.active = false
  if d.active:
    let (ok, p) = sw.screenPointer()
    if not ok: return               # no stable screen position: do not drift
    setWindowPosition(int32(d.startWin.x + p.x - d.startPointer.x),
                      int32(d.startWin.y + p.y - d.startPointer.y))
