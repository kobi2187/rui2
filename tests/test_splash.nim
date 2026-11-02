## Splash (basic/splash.nim): it covers the app and takes every press while it
## is up; finish() fades it out (at once when easing is off) and calls onDone;
## then the app underneath takes presses again.

import std/[unittest, os]
import rui
import ui_harness

suite "Splash":
  teardown: clearRepaints()

  test "the fade goes from 1 to 0 over its seconds":
    check fadeLeft(0, 0.4) == 1
    check abs(fadeLeft(0.2, 0.4) - 0.5) < 1e-6
    check fadeLeft(0.5, 0.4) == 0
    check fadeLeft(0, 0) == 0

  test "while up it takes the presses; finish hides it, calls onDone, and the app answers":
    var clicks = 0
    var done = 0
    var splash: Splash
    var button: Button
    let root = ui:
      Stack(fit = StackFit.expand):
        button = Button(text = "go", onClick = proc() = inc clicks)
        splash = Splash(title = "App", onDone = proc() = inc done)
    let r = newRig(root, 400, 300)
    r.click(button)
    check clicks == 0                    # the splash had it
    motion = motionReduced               # no easing: it goes at once
    defer: motion = motionFull
    splash.finish()
    r.frame(2)
    check not splash.visible and done == 1
    r.click(button)
    check clicks == 1
    disposeTree(r.root)

  test "with easing it fades over its time before it hides":
    var splash = newSplash(title = "App", fadeSeconds = 0.15)
    let r = newRig(stack(splash), 400, 300)
    splash.finish()
    r.frame(1)
    check splash.visible                 # still fading
    for _ in 0 ..< 100:                  # its own next steps (repaintAfter) finish it
      if not splash.visible: break
      sleep(10)
      r.frame(1)
    check not splash.visible
    disposeTree(r.root)
