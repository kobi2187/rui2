## Virtual row scrolling arithmetic
##
## This logic used to live seven times over, once inside each scrollable
## widget's `definePrimitive` body, where it could only be reached by building a
## widget and driving a window. As a plain value it can be checked directly —
## which is the point of extracting it.

import std/unittest
import virtual_rows

suite "rowAt":

  test "maps a pointer position to a row":
    let v = rowViewport(top = 100.0, height = 80.0, rowHeight = 20.0, scrollY = 0.0)
    check v.rowAt(100.0, rowCount = 10) == 0
    check v.rowAt(119.0, rowCount = 10) == 0
    check v.rowAt(120.0, rowCount = 10) == 1
    check v.rowAt(175.0, rowCount = 10) == 3

  test "accounts for the scroll offset":
    let v = rowViewport(top = 100.0, height = 80.0, rowHeight = 20.0, scrollY = 40.0)
    # Scrolled down two rows, so the top of the window now shows row 2.
    check v.rowAt(100.0, rowCount = 10) == 2

  test "returns -1 above the list and past the last row":
    let v = rowViewport(top = 100.0, height = 80.0, rowHeight = 20.0, scrollY = 0.0)
    check v.rowAt(99.0, rowCount = 10) == -1      # above
    check v.rowAt(100.0, rowCount = 0) == -1      # empty list
    check v.rowAt(300.0, rowCount = 3) == -1      # past the end

  test "an empty list never yields a row":
    let v = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 0.0)
    for y in [0.0'f32, 10.0, 50.0, 99.0]:
      check v.rowAt(y, rowCount = 0) == -1

suite "scrolling":

  test "maxScroll is zero while everything fits":
    let v = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 0.0)
    check v.maxScroll(rowCount = 3) == 0.0        # 60px of content in 100px
    check v.maxScroll(rowCount = 5) == 0.0        # exactly full
    check v.maxScroll(rowCount = 8) == 60.0       # 160px of content in 100px

  test "clampScroll keeps the offset in range":
    let v = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 0.0)
    check v.clampScroll(-50.0, rowCount = 8) == 0.0
    check v.clampScroll(999.0, rowCount = 8) == 60.0
    check v.clampScroll(30.0, rowCount = 8) == 30.0

  test "a wheel notch moves three rows and stays clamped":
    let v = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 0.0)
    # Wheel up at the top has nowhere to go.
    check v.scrolledBy(1.0, rowCount = 8) == 0.0
    # Wheel down moves three rows, then hits the bottom.
    check v.scrolledBy(-1.0, rowCount = 8) == 60.0

  test "scrollToShow leaves a visible row alone":
    let v = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 40.0)
    # Rows 2..6 are on screen at this offset.
    check v.scrollToShow(3, rowCount = 20) == 40.0

  test "scrollToShow reaches a row above or below the window":
    let v = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 40.0)
    check v.scrollToShow(0, rowCount = 20) == 0.0     # scroll up to the top
    check v.scrollToShow(9, rowCount = 20) == 100.0   # row 9 ends at 200

  test "nearEnd only fires in the last fifth":
    let v0 = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 0.0)
    check not v0.nearEnd(rowCount = 20)
    let v1 = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 290.0)
    check v1.nearEnd(rowCount = 20)

  test "nearEnd is false when there is nothing to scroll":
    # Otherwise a short list would ask a lazy loader for more rows forever.
    let v = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 0.0)
    check not v.nearEnd(rowCount = 2)

suite "visibleRange":

  test "covers only the rows on screen":
    let v = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 0.0)
    let r = v.visibleRange(rowCount = 100)
    check r.a == 0
    check r.b == 5

  test "follows the scroll offset":
    let v = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 200.0)
    let r = v.visibleRange(rowCount = 100)
    check r.a == 10
    check r.b == 15

  test "buffer pads both sides without leaving the list":
    let v = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 200.0)
    let r = v.visibleRange(rowCount = 100, buffer = 5)
    check r.a == 5
    check r.b == 20

    # At the very top the buffer cannot push the start negative.
    let top = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 0.0)
    check top.visibleRange(rowCount = 100, buffer = 5).a == 0

  test "never runs past the last row":
    let v = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 0.0)
    check v.visibleRange(rowCount = 3).b == 2
    check v.visibleRange(rowCount = 3, buffer = 10).b == 2

  test "an empty list yields a slice that iterates zero times":
    let v = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 0.0)
    var iterations = 0
    for i in v.visibleRange(rowCount = 0):
      inc iterations
    check iterations == 0

suite "rowTop and visibility":

  test "rowTop places rows relative to the scroll offset":
    let v = rowViewport(top = 50.0, height = 100.0, rowHeight = 20.0, scrollY = 30.0)
    check v.rowTop(0) == 20.0        # 50 - 30, scrolled above the window
    check v.rowTop(2) == 60.0

  test "isRowVisible matches what rowTop draws":
    let v = rowViewport(top = 0.0, height = 100.0, rowHeight = 20.0, scrollY = 0.0)
    check v.isRowVisible(0)
    check v.isRowVisible(4)
    check not v.isRowVisible(20)
