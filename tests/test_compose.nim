## The pieces that let an unusual widget be put together from ordinary ones,
## without a widget type of its own or any drawing code: input on any widget
## (`onKey`, `onEvent`, `focusable`), timers that belong to a widget (`every`,
## `after`, `onTick`), `Clip`, and text broken into lines (`wrapLines`,
## `lineHeight`). examples/widgets/wave_reader.nim is all of them at once.

import std/[unittest, os, options, strutils]
import rui
import ui_harness
from raylib import KeyboardKey

var rigs: seq[Rig]

proc rig(w: Widget): Rig =
  result = newRig(stack(w))
  rigs.add result

proc cleanUp() =
  ## Each test's tree goes, timers and all, so none keeps ticking into the
  ## tests that follow (test_motion_none would see it).
  for r in rigs: disposeTree(r.root)
  rigs.setLen(0)
  clearRepaints()

suite "input on any widget":
  teardown: cleanUp()

  test "a plain container takes keys with onKey once it can have focus":
    var got: seq[KeyboardKey]
    let box = newStack().frame(width = 100, height = 60).focusable()
    box.onKey(proc(k: KeyboardKey): bool =
      got.add k
      k == KeyboardKey.Down)
    let r = rig((box))
    r.focus(box)
    r.key(KeyboardKey.Down)
    r.key(KeyboardKey.Up)
    check got == @[KeyboardKey.Down, KeyboardKey.Up]

  test "onEvent sees the pointer on any widget; the widget's own handling comes first":
    var clicks, hooked = 0
    let b = newButton(text = "B")
    b.onClick = proc() = inc clicks
    b.onEvent(proc(e: GuiEvent): bool =
      if e.kind == evMouseDown: inc hooked
      false)
    let plain = newLabel(text = "plain").frame(width = 80, height = 30)
    var pressed = false
    plain.onEvent(proc(e: GuiEvent): bool =
      if e.kind == evMouseDown: pressed = true
      e.kind == evMouseDown)
    let r = rig(stack(b, plain))
    r.click(b)
    check clicks == 1 and hooked == 0     # the button used the press itself
    r.click(plain)
    check pressed

suite "timers that belong to a widget":
  teardown: cleanUp()

  test "every and after fire on time; onTick gets the seconds since the last":
    let w = newLabel(text = "t")
    let r = rig((w))
    var everyN, afterN = 0
    var ticked = 0.0
    w.every(0.05, proc() = inc everyN)
    w.after(0.08, proc() = inc afterN)
    w.onTick(proc(dt: float) = ticked += dt)
    for _ in 0 ..< 12:
      sleep(20)
      r.frame(1)
    check everyN in 3 .. 6
    check afterN == 1
    check ticked > 0.15 and ticked < 0.4
    check timerCount(w) == 2               # after is gone once it fired

  test "they wait while the widget is hidden; a tick does not jump on its return":
    let w = newLabel(text = "t")
    let r = rig((w))
    var ticked = 0.0
    var n = 0
    w.onTick(proc(dt: float) = ticked += dt)
    w.every(0.02, proc() = inc n)
    r.frame(1)
    w.visible = false
    let before = (ticked, n)
    sleep(150)
    r.frame(3)
    check (ticked, n) == before              # nothing while hidden
    w.visible = true
    r.frame(1)
    r.frame(1)
    check ticked - before[0] < 0.1           # the 150 ms away are not added in

  test "they stop with stopTimers, and go with their widget":
    let w = newLabel(text = "t")
    let r = rig((w))
    w.every(0.01, proc() = discard)
    w.onTick(proc(dt: float) = discard)
    check timerCount(w) == 2
    stopTimers(w)
    check timerCount(w) == 0
    let v = newLabel(text = "v")
    v.every(0.01, proc() = discard)
    disposeTree(v)
    check timerCount(v) == 0
    discard r

  test "the motion preference does not stop them: they are the app's content":
    let w = newLabel(text = "t")
    let r = rig((w))
    motion = motionNone
    var n = 0
    w.every(0.01, proc() = inc n)
    for _ in 0 ..< 5:
      sleep(15)
      r.frame(1)
    motion = motionFull
    check n >= 2

suite "Clip":
  teardown: cleanUp()

  test "only the part left after the cut is shown, to the sub-pixel; the child keeps its whole layout":
    let inner = newLabel(text = "inside").frame(width = 200, height = 100)
    let c = newClip(cut = EdgeInsets(top: 30.5, right: 20))
    c.addChild(inner)
    let r = rig((c.frame(width = 200, height = 100)))
    check c.shownPart == Rect(x: 0, y: 30.5, width: 180, height: 69.5)
    check inner.bounds.width == 200 and inner.bounds.height == 100
    check c.softClip
    c.cut = EdgeInsets(bottom: 40)
    r.frame(1)
    check c.childClip.get == Rect(x: 0, y: 0, width: 200, height: 60)

suite "text in lines":
  teardown: cleanUp()

  test "wrapLines breaks as a wrapped Label does; lineHeight spaces them":
    let style = TextStyle(fontSize: 16)
    let text = "one two three four five six seven eight nine ten eleven twelve"
    let lines = wrapLines(text, style, 120)
    check lines.len >= 3
    for l in lines: check measureText(l, style).width <= 121
    check lines.join(" ") == text
    check wrapLines("a\nb", style, 500) == @["a", "b"]
    check lineHeight(style) > 16 and lineHeight(style) < 30
