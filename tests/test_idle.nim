## A window left alone costs nothing: decorative motion (a caret blinking, a
## default button breathing, a decoration's lights) rests once the user has
## been away `userIdleAfter`, and the first input wakes it
## (rui_core repaint_timers.nim).

import std/[unittest, options, monotimes, times, os]
import rui
import ui_harness
import ../packages/rui_widgets/src/primitives/rectangle

suite "an idle window draws nothing":
  test "decorative repaints are scheduled while active, parked while away, woken by input":
    let w = newLabel(text = "x")
    lastInput = getMonoTime()
    check not userAway()
    w.repaintWhileActive(0.5)
    check nextRepaint().isSome                     # scheduled as usual
    discard fireDueRepaints(getMonoTime() + initDuration(seconds = 1))
    lastInput = getMonoTime() - userIdleAfter - initDuration(seconds = 1)
    check userAway()
    w.isDirty = false
    w.repaintWhileActive(0.5)
    check nextRepaint().isNone                     # nothing will wake the loop
    noteInput()
    check w.isDirty                                # the first input wakes it
    check not userAway()

  test "aqua's default button rests at its plain colour once the user is away":
    let r = newRig(stack(newButton(text = "OK", intent = ThemeIntent.Info)))
    r.app.setTheme("aqua")
    let b = Button(r.app.tree.root.children[0])
    lastInput = getMonoTime() - userIdleAfter - initDuration(seconds = 1)
    var faces: seq[Color]
    for i in 0 ..< 4:
      b.layoutDirty = true
      r.frame(1)
      faces.add rectangle.Rectangle(b.children[0]).color
      sleep(120)
    for c in faces: check c == faces[0]            # still
    check nextRepaint().isNone                     # and asks for no frames
    noteInput()
    lastInput = getMonoTime()
