## The distance-field box, against a real GL context: right colours inside and
## on the border, transparent outside the corners, and a soft edge in between
## (the point of it: the triangle-fan path has none).

import rui
import raylib
import std/[unittest, options]

initWindow(200, 200, "sdf")
setTraceLogLevel(TraceLogLevel.Error)

const
  Red = raylib.Color(r: 220, g: 30, b: 30, a: 255)
  Ink = raylib.Color(r: 10, g: 10, b: 10, a: 255)

proc paint(draw: proc()): Image =
  let target = loadRenderTexture(100, 100)
  beginTextureMode(target)
  clearBackground(raylib.Color(r: 0, g: 0, b: 0, a: 0))
  draw()
  endTextureMode()
  result = loadImageFromTexture(target.texture)
  imageFlipVertical(result)           # render textures are stored upside down

suite "sdf rounded box":

  test "fill, border, and transparent corners":
    let img = paint(proc() = drawBox(Rect(x: 10, y: 10, width: 60, height: 40), 14, Red, Ink, 3))
    check getImageColor(img, 40, 30) == Red                    # inside
    let edge = getImageColor(img, 11, 30)                      # on the border
    check edge.r < 40 and edge.a == 255
    check getImageColor(img, 10, 10).a == 0                    # cut-off corner
    check getImageColor(img, 5, 30).a == 0                     # outside

  test "the curved edge is antialiased":
    let img = paint(proc() = drawBox(Rect(x: 10, y: 10, width: 60, height: 40), 14, Red, Ink, 0))
    var soft = 0
    for y in 10 ..< 24:
      for x in 10 ..< 24:
        let a = getImageColor(img, x.int32, y.int32).a
        if a > 0 and a < 255: inc soft
    check soft >= 8                                            # an arc of partial pixels

  test "radius is in pixels and capped at half the short side":
    let img = paint(proc() = drawBox(Rect(x: 10, y: 10, width: 60, height: 20), 500, Red, Ink, 0))
    check getImageColor(img, 40, 20) == Red
    check getImageColor(img, 11, 11).a < 128                   # a pill, not a rectangle

  test "an outline-only box leaves the inside clear":
    let img = paint(proc() = drawRoundedRect(Rect(x: 10, y: 10, width: 60, height: 40), 8, Red, filled = false, lineThickness = 3))
    check getImageColor(img, 40, 30).a == 0
    check getImageColor(img, 40, 11).a == 255
