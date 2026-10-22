## Decorations (decoration.nim): their own objects on the overlay layer that
## follow a widget -- or cover the window -- and obey the motion preference;
## none on a hidden widget or a page frozen behind a modal; gone with their
## widget.

import std/[unittest, options]
import rui
import ui_harness
from raylib import KeyboardKey

proc onLayer(d: Decoration): bool = Widget(d) in overlays()

suite "decorations":
  setup:
    clearOverlays()
    thawAll()
  teardown:
    motion = motionFull

  test "it follows its widget, reaching past it by the effect's reach":
    let b = newButton(text = "Lit").size(100, 40)
    let r = newRig(stack(b))
    let d = b.adorn(leds(size = 3))                     # reach 9
    r.frame()
    check d.onLayer
    check d.bounds == Rect(x: b.bounds.x - 9, y: b.bounds.y - 9,
                           width: b.bounds.width + 18, height: b.bounds.height + 18)

  test "an outward inset widens it so the moved path is not clipped":
    let b = newButton(text = "Sel").size(100, 40)
    let r = newRig(stack(b))
    let d = b.adorn(marchingAnts(width = 1), inset = -4)
    r.frame()
    check d.bounds.width == b.bounds.width + 2 * (1 + 4)

  test "motion: none hides a decorative effect and keeps an informative one, still":
    let a = newButton(text = "A").size(80, 30)
    let b = newButton(text = "B").size(80, 30)
    let r = newRig(stack(a, b))
    let lights = a.adorn(leds())
    let glow = b.adorn(glowPulse())
    r.frame()
    motion = motionNone
    r.frame()
    check not lights.onLayer
    check glow.onLayer
    motion = motionReduced                              # reduced only stops easing
    r.frame()
    check lights.onLayer

  test "nothing on a hidden widget, or on a page frozen behind a modal":
    let b = newButton(text = "Lit").size(80, 30)
    let box = newMessageBox(title = "Sure?", message = "Really?")
    let r = newRig(stack(b, box))
    let d = b.adorn(leds())
    r.frame()
    check d.onLayer
    box.show()
    r.frame()
    check not d.onLayer
    r.key(KeyboardKey.Escape)
    r.frame()
    check d.onLayer
    b.visible = false
    r.frame()
    check not d.onLayer

  test "remove takes it away; disposing its widget does too":
    let b = newButton(text = "Lit").size(80, 30)
    let r = newRig(stack(b))
    let d = b.adorn(leds())
    r.frame()
    d.remove()
    r.frame()
    check not d.onLayer
    let d2 = b.adorn(leds())
    r.frame()
    disposeTree(b)
    r.frame()
    check not d2.onLayer

  test "round the window: the window's rectangle, or your own points":
    let r = newRig(stack(newLabel(text = "page")), 300, 200)
    check r.app.windowOutline.length == 2 * (300 + 200).float32
    let mine = newPath([(20'f32, 10'f32), (280'f32, 10'f32), (150'f32, 190'f32)])
    let d = r.app.adornWindow(leds(), path = some(mine))
    r.frame()
    check d.onLayer
    check d.bounds.width == r.app.window.width.float32
    d.remove()                    # the next App may be given this one's address
