## Animation: easing curves, Animated[T], and how it asks for frames.

import std/[unittest, monotimes, times]
import rui

proc at(start: MonoTime, ms: int): MonoTime = start + initDuration(milliseconds = ms)

suite "easing":

  test "every curve runs from 0 to 1":
    for e in Easing:
      check ease(e, 0.0) == 0.0
      check abs(ease(e, 1.0) - 1.0) < 1e-5

  test "input is clamped":
    check ease(easeOut, -3.0) == 0.0
    check abs(ease(easeOut, 7.0) - 1.0) < 1e-5

  test "easeOut leads, easeIn lags, linear is the diagonal":
    check ease(easeOut, 0.5) > 0.5
    check ease(easeIn, 0.5) < 0.5
    check ease(linear, 0.25) == 0.25
    check abs(ease(easeInOut, 0.5) - 0.5) < 1e-5

  test "easeOutBack overshoots 1 on the way":
    var peak = 0.0'f32
    for i in 0 .. 100: peak = max(peak, ease(easeOutBack, i.float32 / 100))
    check peak > 1.0

suite "Animated":

  test "numbers, colours and rectangles interpolate":
    check lerp(10.0'f32, 20.0'f32, 0.5) == 15.0
    check lerp(Color(r: 0, g: 100, b: 200, a: 255), Color(r: 100, g: 100, b: 0, a: 255), 0.5) ==
      Color(r: 50, g: 100, b: 100, a: 255)
    check lerp(Rect(x: 0, y: 0, width: 10, height: 10), Rect(x: 10, y: 20, width: 30, height: 10), 0.5) ==
      Rect(x: 5, y: 10, width: 20, height: 10)

  test "a trip takes its time and then stops running":
    let t0 = getMonoTime()
    var a = newAnimated(0.0'f32)
    a.moveTo(100.0, 1.0, linear, t0)
    check a.isRunning
    check abs(a.advance(t0.at(500)) - 50.0) < 0.5
    check a.isRunning
    check a.advance(t0.at(1000)) == 100.0
    check not a.isRunning
    check a.advance(t0.at(5000)) == 100.0

  test "retargeting turns round from where it is, with no jump":
    let t0 = getMonoTime()
    var a = newAnimated(0.0'f32)
    a.moveTo(100.0, 1.0, linear, t0)
    discard a.advance(t0.at(500))                    # at 50
    a.moveTo(0.0, 1.0, linear, t0.at(500))
    check abs(a.advance(t0.at(500)) - 50.0) < 0.5    # still 50 the instant it turns
    check abs(a.advance(t0.at(1000)) - 25.0) < 0.5   # heading back

  test "asking for the same target does not restart it":
    let t0 = getMonoTime()
    var a = newAnimated(0.0'f32)
    a.moveTo(100.0, 1.0, linear, t0)
    a.moveTo(100.0, 1.0, linear, t0.at(900))         # every frame calls this
    check a.advance(t0.at(1000)) == 100.0

  test "zero seconds is instant":
    var a = newAnimated(Color(r: 0, g: 0, b: 0, a: 255))
    a.moveTo(Color(r: 255, g: 255, b: 255, a: 255), 0.0)
    check not a.isRunning
    check a.advance().r == 255

  test "a zero-valued Animated starts at its first target instead of fading in":
    var a: Animated[Color]
    let c = Color(r: 10, g: 20, b: 30, a: 255)
    a.moveTo(c, 1.0)
    check not a.isRunning
    check a.advance() == c

suite "follow: frames are requested only while moving":

  test "a moving value keeps the widget animating, and a settled one stops":
    clearRepaints()
    let w = newLabel(text = "x")
    var a = newAnimated(0.0'f32)
    discard a.follow(w, 100.0, 1.0)                  # starts moving
    check nextRepaint().isSome
    var due = fireDueRepaints(getMonoTime() + initDuration(seconds = 1))
    check due
    check w.layoutDirty                              # animations read their value in layout
    clearRepaints()
    a.jump(100.0)
    discard a.follow(w, 100.0, 1.0)
    check nextRepaint().isNone                       # idle again

  test "animationsEnabled = false lands on the target at once":
    clearRepaints()
    animationsEnabled = false
    defer: animationsEnabled = true
    let w = newLabel(text = "x")
    var a = newAnimated(0.0'f32)
    check a.follow(w, 100.0, 1.0) == 100.0
    check nextRepaint().isNone

suite "Button fades between states":

  test "hover eases toward the hover colour, and settles on it":
    clearRepaints()
    setCurrentTheme(brandTheme(daylightSpec()))
    let b = newButton(text = "Go")
    b.bounds = Rect(x: 0, y: 0, width: 100, height: 40)
    b.layout()
    let rest = b.children[0].getScriptableState()["color"]
    b.isHovered = true
    b.layout()
    let mid = b.children[0].getScriptableState()["color"]
    check mid == rest                       # t ~ 0: not there yet...
    check nextRepaint().isSome              # ...and a frame is on its way
    animationsEnabled = false
    defer: animationsEnabled = true
    b.layout()
    check b.children[0].getScriptableState()["color"] != rest   # settled on hover

  test "a theme switch snaps; only a state change fades":
    clearRepaints()
    setCurrentTheme(brandTheme(daylightSpec()))
    let b = newButton(text = "Go")
    b.bounds = Rect(x: 0, y: 0, width: 100, height: 40)
    b.layout()
    let before = b.children[0].getScriptableState()["color"]
    setCurrentTheme(brandTheme(midnightSpec()))
    b.layout()
    check b.children[0].getScriptableState()["color"] != before   # already midnight's
    check nextRepaint().isNone                                    # nothing left to animate
