## Ruler (modern/ruler.nim, axis_ticks.nim): round steps per format, labels
## with the detail the step needs, marks that follow the view, and a press
## that seeks.

import std/[unittest, strutils]
import rui
import ui_harness

suite "steps and labels":
  test "steps are round for each format":
    check plainTicks().pickStep(37) == 50
    check secondTicks().pickStep(7) == 10
    check secondTicks().pickStep(50) == 60
    check secondTicks().pickStep(0.03) == 0.05
    check abs(timecodeTicks(25).pickStep(0.05) - 2 / 25) < 1e-9     # whole frames
    check beatTicks(120).pickStep(0.4) == 0.5                        # a beat
    check beatTicks(120).pickStep(1.5) == 2.0                        # a bar of 4
    check sampleTicks(48000).pickStep(0.01) * 48000 == 500

  test "labels say what the step needs":
    check secondTicks().tickLabel(90, 10) == "1:30"
    check secondTicks().tickLabel(3725, 60) == "1:02:05"
    check secondTicks().tickLabel(1.25, 0.25) == "0:01.25"
    check timecodeTicks(25).tickLabel(61 + 12 / 25, 1 / 25) == "00:01:01:12"
    check sampleTicks(48000).tickLabel(0.5, 0.1) == "24000"
    check beatTicks(120, 4).tickLabel(2.5, 0.5) == "2.2"           # bar 2, beat 2
    check beatTicks(120, 4).tickLabel(4.0, 2.0) == "3"
    check plainTicks().tickLabel(2.5, 0.5) == "2.5"

  test "labelled marks are spaced about the label spacing apart, inside the view":
    let v = wholeView(0.0, 600.0)                 # ten minutes over 600 px: 1 s a px
    let ticks = axisTicks(secondTicks(), v, 0, 600, 80)
    var majors: seq[Tick]
    for t in ticks:
      check t.x >= -0.01 and t.x <= 600.01
      if t.major: majors.add t
    check majors.len >= 4 and majors.len <= 8
    check majors[1].at - majors[0].at == 120                        # 2:00 steps
    check majors[1].label == "2:00"

suite "the Ruler widget":
  teardown: clearRepaints()

  test "it follows its view, and a press seeks to the time under it":
    let view = newLink(wholeView(0.0, 100.0))
    var sought: seq[float]
    let ruler = newRuler(view = view, ticks = secondTicks())
    ruler.onSeek = proc(at: float) = sought.add at
    let r = newRig(stack(ruler.frame(width = 400, height = 26)), 400, 60)
    r.press(ruler.bounds.x + 100, ruler.bounds.y + 10)
    r.moveTo(ruler.bounds.x + 200, ruler.bounds.y + 10)
    r.release(ruler.bounds.x + 200, ruler.bounds.y + 10)
    check sought.len >= 2
    check abs(sought[0] - 25) < 0.5 and abs(sought[^1] - 50) < 0.5
    ruler.isDirty = false
    view.value = view.value.showing(10, 20, 400)
    check ruler.isDirty                          # another widget zoomed: it redraws
    disposeTree(r.root)
