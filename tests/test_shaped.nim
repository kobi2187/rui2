## rui_shaped without a display: masks to OS regions, and which method a
## machine gets. The windows themselves are exercised by the spikes
## (packages/rui_shaped/spikes) under Xvfb with and without a compositor.

import std/[unittest, monotimes, times]
import rui_shaped/[mask, detect]

proc disc(cx, cy, r: float32): proc(x, y: float32): float32 =
  result = proc(x, y: float32): float32 =
    if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r: 1 else: 0

suite "masks to regions":
  test "rows with the same runs merge into one band; a hole splits a row":
    # 6x4: rows 0-1 full, rows 2-3 with a hole at x 2..3
    var m = AlphaMask(width: 6, height: 4, alpha: newSeq[uint8](24))
    for y in 0 ..< 4:
      for x in 0 ..< 6:
        m.alpha[y * 6 + x] = (if y >= 2 and x in 2 .. 3: 0'u8 else: 255'u8)
    let rects = m.toRects
    check rects == @[ShapeRect(x: 0, y: 0, w: 6, h: 2),
                     ShapeRect(x: 0, y: 2, w: 2, h: 2), ShapeRect(x: 4, y: 2, w: 2, h: 2)]
    check rects.covers(5, 3) and not rects.covers(2, 3)

  test "an empty mask is no region; the threshold decides soft edges":
    var m = AlphaMask(width: 3, height: 1, alpha: @[0'u8, 100, 200])
    check AlphaMask(width: 2, height: 2, alpha: newSeq[uint8](4)).toRects.len == 0
    check m.toRects(128) == @[ShapeRect(x: 2, y: 0, w: 1, h: 1)]
    check m.toRects(50) == @[ShapeRect(x: 1, y: 0, w: 2, h: 1)]

  test "a coarse sample of a shape is close to the full one, and much cheaper":
    let shape = disc(210, 210, 150)
    var t0 = getMonoTime()
    let fine = rectsFromFunc(420, 420, shape, step = 1)
    let fineTime = getMonoTime() - t0
    t0 = getMonoTime()
    let coarse = rectsFromFunc(420, 420, shape, step = 3)
    let coarseTime = getMonoTime() - t0
    # The same points are inside, except within a step of the edge.
    for (x, y) in [(210, 210), (100, 210), (330, 300), (5, 5), (400, 10)]:
      check fine.covers(x, y) == coarse.covers(x, y)
    check coarse.len < fine.len
    check coarseTime < fineTime

suite "the shape's bounds":
  test "the bounding box is where the visible shape is, inside a margin":
    let rects = @[ShapeRect(x: 20, y: 60, w: 380, h: 300), ShapeRect(x: 150, y: 10, w: 120, h: 50)]
    check rects.boundingBox == ShapeRect(x: 20, y: 10, w: 380, h: 350)
    check newSeq[ShapeRect]().boundingBox == ShapeRect()

suite "where the widgets go":
  test "a shape reaching the window's bottom-right corner lets content use the whole window":
    # a BeOS-style window: a rectangle with the corner beside its tab cut away
    let tabbed = @[ShapeRect(x: 0, y: 0, w: 150, h: 24),      # the title tab
                   ShapeRect(x: 0, y: 24, w: 400, h: 276)]    # the body below it
    check tabbed.boundingBox.contentArea(400, 300) == ShapeRect(x: 0, y: 0, w: 400, h: 300)

  test "a shape inside a margin holds the content to its box":
    check ShapeRect(x: 19, y: 9, w: 382, h: 352).contentArea(420, 420) ==
          ShapeRect(x: 19, y: 9, w: 382, h: 352)
    # reaching the right edge but not the bottom is still short of the corner
    check ShapeRect(x: 0, y: 0, w: 420, h: 300).contentArea(420, 420) ==
          ShapeRect(x: 0, y: 0, w: 420, h: 300)

  test "no shape at all: the whole window":
    check ShapeRect().contentArea(300, 200) == ShapeRect(x: 0, y: 0, w: 300, h: 200)

suite "choosing a method":
  test "X11: compositor gives see-through with click-through; without, an OS shape":
    var c = ShapeCaps(platform: spX11, x11: true, shapeExt: true, compositor: true, argbVisual: true)
    check chooseMethod(c) == smTransparentInput
    check chooseMethod(c, clickThrough = false) == smTransparent
    c.compositor = false
    check chooseMethod(c) == smOsShape
    c.shapeExt = false
    check chooseMethod(c) == smRectangle

  test "a see-through window that got no alpha channel steps down":
    var c = ShapeCaps(platform: spX11, x11: true, shapeExt: true, compositor: true,
                      argbVisual: true, windowDepth: 24)
    check confirmMethod(c, smTransparentInput) == smOsShape
    c.windowDepth = 32
    check confirmMethod(c, smTransparentInput) == smTransparentInput

  test "other platforms: Wayland and macOS see-through, Windows a region unless soft edges win":
    check chooseMethod(ShapeCaps(platform: spWayland)) == smTransparent
    check chooseMethod(ShapeCaps(platform: spMacOS)) == smTransparent
    check chooseMethod(ShapeCaps(platform: spWindows)) == smOsShape
    check chooseMethod(ShapeCaps(platform: spWindows), clickThrough = false) == smTransparent
    check chooseMethod(ShapeCaps(platform: spOther)) == smRectangle

  test "each method asks for what it needs":
    check smTransparentInput.needsTransparentFramebuffer and smTransparentInput.setsInputRegion
    check not smTransparentInput.setsBoundingRegion
    check smOsShape.setsBoundingRegion and smOsShape.setsInputRegion
    check not smRectangle.setsInputRegion and not smTransparent.setsInputRegion
