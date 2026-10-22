import std/[unittest, monotimes, times]
import ../packages/rui_widgets/src/fling
import rui_core

let t0 = getMonoTime()
proc at(ms: int): MonoTime = t0 + initDuration(milliseconds = ms)

suite "Fling":
  test "a fast drag released at once runs on in the same direction and stops":
    var f: Fling
    f.begin(500, at(0))
    for i in 1 .. 5: f.track(500 - i.float32 * 20, at(i * 16))   # ~1250 px/s up
    check f.release(at(5 * 16 + 10))
    var total = 0.0'f32
    var now = 90
    while f.active and now < 5000:
      now += 16
      total += f.step(at(now))
    check total < -200                 # kept moving upwards
    check not f.active

  test "a coast is easing: with motion reduced or none the content stops with the finger":
    for level in [motionReduced, motionNone]:
      motion = level
      var f: Fling
      f.begin(500, at(0))
      for i in 1 .. 5: f.track(500 - i.float32 * 20, at(i * 16))
      check not f.release(at(5 * 16 + 10))
      check not f.active
    motion = motionFull

  test "a slow drag does not fling":
    var f: Fling
    f.begin(100, at(0))
    for i in 1 .. 5: f.track(100 + i.float32, at(i * 50))        # 20 px/s
    check not f.release(at(260))
    check f.step(at(280)) == 0

  test "a finger that rested before lifting does not fling":
    var f: Fling
    f.begin(0, at(0))
    for i in 1 .. 5: f.track(i.float32 * 30, at(i * 16))
    check not f.release(at(80 + 300))

  test "touching again stops a fling":
    var f: Fling
    f.begin(0, at(0))
    for i in 1 .. 5: f.track(i.float32 * 30, at(i * 16))
    check f.release(at(90))
    f.begin(10, at(120))
    check not f.active
    check f.step(at(140)) == 0

  test "speed decays: later steps move less":
    var f: Fling
    f.begin(0, at(0))
    for i in 1 .. 5: f.track(i.float32 * 40, at(i * 16))
    check f.release(at(90))
    let first = f.step(at(106))
    var last = first
    for i in 2 .. 20: last = f.step(at(90 + i * 16))
    check abs(last) < abs(first)
