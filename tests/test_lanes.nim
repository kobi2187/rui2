## Lanes and clips (modern/lanes.nim), driven through the real event router:
## a lane's header is its name or a widget of its own, clips move (between
## lanes too), trim and snap, empty space pans the view (or, with marks,
## seeks), Delete asks.

import std/[unittest, math]
import rui
import ui_harness
from raylib import KeyboardKey

proc rig(): tuple[r: Rig, l: Lanes, head: Label] =
  let view = newLink(wholeView(0.0, 100.0))       # 400 px of lane area: 0.25 a px
  let head = newLabel(text = "Video")
  let l = newLanes(view = view, lanes = @[lane("Video", header = head), lane("Music")],
                   clips = @[clip("a", 0, 10.0, 20.0, "A"), clip("b", 1, 50.0, 10.0, "B")],
                   headerWidth = 100, laneHeight = 40, snapStep = 1.0)
  let r = newRig(stack(l.frame(width = 500, height = 80)), 520, 100)
  (r, l, head)

proc xOf(l: Lanes, at: float): float32 = l.bounds.x + 100 + float32(at / 0.25)
proc yOf(l: Lanes, lane: int): float32 = l.bounds.y + 20 + float32(lane) * 40

suite "Lanes":
  teardown: clearRepaints()

  test "a lane's header widget sits beside it; a new set of lanes brings its own":
    let (r, l, head) = rig()
    check head.parent == l
    check head.bounds.x >= l.bounds.x and head.bounds.x + head.bounds.width <= l.bounds.x + 100
    check head.bounds.y >= l.bounds.y and head.bounds.y < l.bounds.y + 40
    let other = newLabel(text = "Music")
    l.lanes = @[lane("Video"), lane("Music", header = other)]
    r.frame(1)
    check l.children == @[Widget(other)] and head.parent == nil
    check other.bounds.y >= l.bounds.y + 40
    disposeTree(r.root)

  test "with marks, a click on empty space puts the playhead there":
    let (r, l, _) = rig()
    let play = newLink(0.0)
    l.marks = newMarks(playhead = play)
    r.frame(1)
    var sought = -1.0
    l.onSeek = proc(at: float) = sought = at
    r.click(l.xOf(70), l.yOf(0))
    check abs(play.value - 70) < 0.5 and abs(sought - 70) < 0.5
    r.drag(l.xOf(10) + 40, l.yOf(0), l.xOf(10) + 80, l.yOf(0))  # a clip still moves
    check l.clips[0].start == 20
    disposeTree(r.root)

  test "a drag on a clip moves it, snapped, and onto another lane":
    let (r, l, _) = rig()
    var changes = 0
    l.onClipChanged = proc(i: int, c: LaneClip) = inc changes
    r.drag(l.xOf(20), l.yOf(0), l.xOf(35.3), l.yOf(1))
    check l.clips[0].start == 25 and l.clips[0].lane == 1
    check l.clips[0].length == 20 and changes > 0
    check l.selected == 0
    disposeTree(r.root)

  test "an edge drag trims, and edges catch on another clip's edge":
    let (r, l, _) = rig()
    r.drag(l.xOf(30) - 2, l.yOf(0), l.xOf(49.4), l.yOf(0))   # the end of A, to near B's start
    check l.clips[0].start == 10 and l.clips[0].length == 40  # caught by B at 50
    r.drag(l.xOf(10) + 2, l.yOf(0), l.xOf(15.2), l.yOf(0))   # A's start
    check l.clips[0].start == 15 and l.clips[0].start + l.clips[0].length == 50
    disposeTree(r.root)

  test "empty space pans the view; a click there clears the selection":
    let (r, l, _) = rig()
    r.click(l.xOf(15), l.yOf(0))
    check l.selected == 0
    l.view.value = l.view.value.showing(0, 50, 400)
    r.frame(1)
    r.drag(l.xOf(45), l.yOf(1), l.xOf(5), l.yOf(1))
    check l.view.value.start > 0 and l.selected == -1
    disposeTree(r.root)

  test "Delete asks for the selected clip to go":
    let (r, l, _) = rig()
    var asked = -1
    l.onClipDelete = proc(i: int) = asked = i
    r.click(l.xOf(52), l.yOf(1))
    r.focus(l)
    r.key(KeyboardKey.Delete)
    check asked == 1
    disposeTree(r.root)
