## While a modal is open the page behind it is a still picture (rui_core
## freeze.nim): it is not laid out or painted, so nothing in it runs, and it
## catches up when the modal closes. It is laid out once more -- to be pictured
## again -- after a resize or a theme change. The picture's look is the
## theme's `backdrop:`.

import std/[unittest, options]
import rui
import ui_harness
from raylib import KeyboardKey

proc page(): (Widget, Label, MessageBox) =
  let label = newLabel(text = "the page")
  let box = newMessageBox(title = "Sure?", message = "Discard changes?")
  (stack(label, box), label, box)

suite "a modal freezes the page behind it":
  setup:
    thawAll()

  test "while it is open the page is not laid out; it catches up when it closes":
    let (root, label, box) = page()
    let r = newRig(root)
    box.show()
    r.frame()
    check frozenBy(r.root) == Widget(box)
    label.layoutDirty = true                 # something changed in the page
    r.frame(3)
    check label.layoutDirty                  # ...and nothing looked at it
    r.key(KeyboardKey.Escape)                # the modal answers and closes
    r.frame()
    check frozenBy(r.root) == nil
    check not label.layoutDirty              # the page ran again

  test "the modal itself still runs: its buttons answer":
    let (root, _, box) = page()
    let r = newRig(root)
    var answered = false
    box.onClose = proc(res: MessageBoxResult) = answered = true
    box.show()
    r.frame()
    r.key(KeyboardKey.Escape)
    r.frame()
    check answered and not box.visible

  test "a resize or a theme change lays the page out once more, then it is still again":
    let (root, label, box) = page()
    let r = newRig(root)
    box.show()
    r.frame()
    label.layoutDirty = true
    root.layoutDirty = true                  # what a resize does to the root
    r.frame()
    check not label.layoutDirty              # laid out, to be pictured at the new size
    label.layoutDirty = true
    r.frame()
    check label.layoutDirty                  # and frozen again
    inc settleEpoch                          # what setTheme does
    r.frame()
    check not label.layoutDirty

  test "modals stack: closing the top one returns to the one below, the page still frozen":
    let label = newLabel(text = "the page")
    let lower = newMessageBox(title = "Lower", message = "below")
    let upper = newMessageBox(title = "Upper", message = "on top")
    let r = newRig(stack(label, lower, upper))
    lower.show()
    r.frame()
    upper.show()
    r.frame()
    check frozenBy(r.root) == Widget(upper)
    r.key(KeyboardKey.Escape)
    r.frame()
    check frozenBy(r.root) == Widget(lower)
    label.layoutDirty = true
    r.frame()
    check label.layoutDirty

  test "a modal left open in another tree does not freeze this one":
    let (otherRoot, _, otherBox) = page()
    discard newRig(otherRoot)
    otherBox.show()                          # never closed
    let (root, label, _) = page()
    let r = newRig(root)
    check frozenBy(r.root) == nil
    label.layoutDirty = true
    r.frame()
    check not label.layoutDirty

suite "the backdrop's look is the theme's":
  proc noExtends(name: string): Theme = newTheme(name)

  test "unset, it is the old half-dark tint, sharp and in colour":
    let t = newTheme("plain")
    check t.backdropColor == Color(r: 0, g: 0, b: 0, a: 128)
    check t.backdropBlur == 0 and t.backdropSaturation == 1

  test "a theme file's backdrop: section sets it, and its keys are checked":
    let t = parseTheme("""
backdrop:
  color: "#F6F3FE99"
  blur: 6
  saturation: 0.25
""", tffYaml, noExtends)
    check t.backdropColor == Color(r: 246, g: 243, b: 254, a: 153)
    check t.backdropBlur == 6 and t.backdropSaturation == 0.25
    check parseTheme(t.toYaml, tffYaml, noExtends).backdrop == t.backdrop
    expect ValueError:
      discard parseTheme("backdrop:\n  tint: red\n", tffYaml, noExtends)

  test "a painter draws over it: the modal's own, else the app's, else none":
    let a = newMessageBox(title = "A", message = "a")
    let b = newMessageBox(title = "B", message = "b")
    var calls: seq[string]
    let appWide: BackdropPainter = proc(area: Rect) = calls.add "app"
    let own: BackdropPainter = proc(area: Rect) = calls.add "own"
    let more: BackdropPainter = proc(area: Rect) = calls.add "more"
    check backdropPainterFor(a) == nil
    setBackdropPainter(appWide)
    setBackdropPainter(b, own, more)
    backdropPainterFor(a)(Rect())
    backdropPainterFor(b)(Rect())
    check calls == @["app", "own", "more"]      # several run in order
    setBackdropPainter(b)                       # none: back to the app's
    calls.setLen(0)
    backdropPainterFor(b)(Rect())
    check calls == @["app"]
    setBackdropPainter()
    check backdropPainterFor(a) == nil

  test "some built-in themes have their own: frosted Aurora, grey Graphite":
    check getBuiltinTheme("aurora").backdropBlur > 0
    check getBuiltinTheme("graphite").backdropSaturation == 0
