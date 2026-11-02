## Aqua as a stress test of how far a theme reaches: gel finishes, soft
## shadows painted past the bounds, a default button that breathes.

import std/[unittest, options, os]
import rui
import ui_harness
import ../packages/rui_widgets/src/primitives/rectangle

suite "theme: Aqua (gel, soft shadows, a breathing default button)":
  test "aqua's controls are gel pills with soft shadows, and keep room for them":
    let t = brandTheme(aquaSpec())
    let f = t.getThemeProps(Info, Normal).boxFinish
    check f.gloss > 0 and f.gradient > 0 and f.caustic > 0 and f.shadow > 0
    check t.getThemeProps(Default, Normal).finishReach > 0      # the shadow paints past the box
    check t.getThemeProps(Default, Normal).boxFinish(well = true).shadow == 0   # fields sit in
    check t.pulse > 0 and t.glass > 0
    check t.assets.backgroundPattern == some("tile:pinstripes")

  test "the default button breathes in aqua, and is still with motion none":
    noteInput()                      # someone is here (decorative motion rests otherwise)
    let r = newRig(stack(newButton(text = "OK", intent = ThemeIntent.Info)))
    r.app.setTheme("aqua")
    let b = Button(r.app.tree.root.children[0])
    var faces: seq[Color]
    for i in 0 ..< 6:
      r.frame(1)
      faces.add rectangle.Rectangle(b.children[0]).color
      sleep(120)
    var changed = false
    for c in faces: changed = changed or c != faces[0]
    check changed                                                # it breathes
    motion = motionNone
    defer: motion = motionFull
    b.layoutDirty = true
    r.frame(1)
    let still = rectangle.Rectangle(b.children[0]).color
    sleep(200)
    b.layoutDirty = true
    r.frame(1)
    check rectangle.Rectangle(b.children[0]).color == still
