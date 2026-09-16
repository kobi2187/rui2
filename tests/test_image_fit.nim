## Image fit geometry — where a picture goes inside a box
##
## This was 120 lines inside ImageWidget's `render`, so checking that Cover
## actually covers needed a GL context and an image file. The modes follow CSS
## object-fit; these cases pin what each one means.

import std/unittest
import rui
import basic/image_fit

const box = Rect(x: 10.0, y: 20.0, width: 200.0, height: 100.0)  # 2:1

suite "Fill":
  test "takes the whole box and ignores the aspect ratio":
    let d = destinationFor(Fill, box, 40.0, 40.0)
    check d.x == 10.0
    check d.y == 20.0
    check d.width == 200.0
    check d.height == 100.0

suite "Contain":
  test "a wide image is limited by width and centred vertically":
    # 4:1 into a 2:1 box.
    let d = destinationFor(Contain, box, 400.0, 100.0)
    check d.width == 200.0
    check d.height == 50.0
    check d.x == 10.0
    check d.y == 45.0          # 20 + (100 - 50) / 2

  test "a tall image is limited by height and centred horizontally":
    # 1:1 into a 2:1 box.
    let d = destinationFor(Contain, box, 100.0, 100.0)
    check d.width == 100.0
    check d.height == 100.0
    check d.y == 20.0
    check d.x == 60.0          # 10 + (200 - 100) / 2

  test "it never overflows the box":
    for (w, h) in [(400.0'f32, 100.0'f32), (100.0'f32, 400.0'f32),
                   (17.0'f32, 5.0'f32), (5.0'f32, 17.0'f32)]:
      let d = destinationFor(Contain, box, w, h)
      check d.width <= box.width + 0.001
      check d.height <= box.height + 0.001

  test "it preserves the aspect ratio":
    let d = destinationFor(Contain, box, 300.0, 200.0)
    check abs(d.width / d.height - 1.5) < 0.001

suite "Cover":
  test "a wide image overflows sideways":
    let d = destinationFor(Cover, box, 400.0, 100.0)
    check d.height == 100.0
    check d.width == 400.0
    check d.x < box.x          # cropped equally on both sides

  test "a tall image overflows above and below":
    let d = destinationFor(Cover, box, 100.0, 100.0)
    check d.width == 200.0
    check d.height == 200.0
    check d.y < box.y

  test "it always covers the box":
    for (w, h) in [(400.0'f32, 100.0'f32), (100.0'f32, 400.0'f32),
                   (17.0'f32, 5.0'f32), (5.0'f32, 17.0'f32)]:
      let d = destinationFor(Cover, box, w, h)
      check d.width >= box.width - 0.001
      check d.height >= box.height - 0.001

  test "it preserves the aspect ratio":
    let d = destinationFor(Cover, box, 300.0, 200.0)
    check abs(d.width / d.height - 1.5) < 0.001

suite "None":
  test "original size, centred, whatever the box is":
    let d = destinationFor(None, box, 60.0, 40.0)
    check d.width == 60.0
    check d.height == 40.0
    check d.x == 80.0          # 10 + (200 - 60) / 2
    check d.y == 50.0          # 20 + (100 - 40) / 2

  test "an oversized image is centred and cropped, not shrunk":
    let d = destinationFor(None, box, 400.0, 400.0)
    check d.width == 400.0
    check d.x < box.x

suite "ScaleDown":
  test "an image that fits is left at its own size":
    let d = destinationFor(ScaleDown, box, 60.0, 40.0)
    check d.width == 60.0
    check d.height == 40.0
    check d == destinationFor(None, box, 60.0, 40.0)

  test "an image that does not fit is Contain":
    let d = destinationFor(ScaleDown, box, 400.0, 100.0)
    check d == destinationFor(Contain, box, 400.0, 100.0)

  test "an image exactly the size of the box is not scaled":
    let d = destinationFor(ScaleDown, box, 200.0, 100.0)
    check d.width == 200.0
    check d.height == 100.0

suite "degenerate inputs":
  ## A zero-sized widget or image paints nothing, so the result is
  ## unobservable -- but a NaN rectangle is not, and would propagate.

  test "a zero-sized box does not divide by zero":
    let empty = Rect(x: 5.0, y: 5.0, width: 0.0, height: 0.0)
    for mode in ImageFit:
      let d = destinationFor(mode, empty, 100.0, 100.0)
      check d.width == 0.0
      check d.height == 0.0

  test "a zero-sized image does not divide by zero":
    for mode in ImageFit:
      let d = destinationFor(mode, box, 0.0, 0.0)
      check d.width == box.width
      check d.height == box.height
