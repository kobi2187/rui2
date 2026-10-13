## Repainting only the damaged area gives the same pixels as repainting everything.
##
## A widget that is dirty only because a descendant repainted redoes just the area
## that descendant covers (scissor, clear, its own `render`, the children that
## reach into it). This builds trees with panels, overlapping siblings and text,
## changes one leaf at a time, repaints, and compares the root texture with one
## produced by a full repaint of the same state -- to the pixel, read back from
## the GPU. Run under Xvfb by tools/run_tests.sh.

import rui
import raylib
import std/[options, unittest]

initWindow(420, 320, "partial")
setTraceLogLevel(TraceLogLevel.Error)
setCurrentTheme(brandTheme(daylightSpec()))

type Scene = object
  root: Widget
  label: Label
  bar: ProgressBar
  chip: rectangle.Rectangle
  under: rectangle.Rectangle
  button: Button

proc build(): Scene =
  let root = newVStack(spacing = 6.0, padding = 8.0)
  let label = newLabel(text = "hello")
  let bar = newProgressBar(initialValue = 10.0).frame(width = 200, height = 18)
  let panel = newPanel(padding = 8.0, cornerRadius = 6.0).frame(width = 300, height = 90)
  let inner = newColumn(spacing = 4.0)
  let button = newButton(text = "Go")
  inner.addChild label
  inner.addChild bar
  inner.addChild button
  panel.addChild inner
  root.addChild panel
  # two siblings that overlap: a partial update must redraw both under the damage
  let stack = newStack().frame(width = 120, height = 60)
  let under = newRectangle(color = Color(r: 40, g: 120, b: 220, a: 255)).frame(width = 100, height = 50)
  let chip = newRectangle(color = Color(r: 230, g: 60, b: 60, a: 160)).frame(width = 60, height = 30)
  stack.addChild under
  stack.addChild chip
  root.addChild stack
  root.addChild newTextInput(initialText = "text field")
  root.bounds = Rect(x: 0, y: 0, width: 420, height: 320)
  root.layoutPass()
  root.renderPass()
  Scene(root: root, label: label, bar: bar, chip: chip, under: under, button: button)

proc pixels(w: Widget): seq[Color] =
  let img = loadImageFromTexture(w.cachedTexture.get().texture)
  for y in 0 ..< img.height:
    for x in 0 ..< img.width:
      result.add getImageColor(img, x, y)

proc markAll(w: Widget) =
  w.isDirty = true
  for c in w.children: markAll(c)

proc settle(s: Scene) =
  s.root.layoutPass()
  s.root.renderPass()

proc fullRepaint(s: Scene): seq[Color] =
  ## Same state, every widget repainted whole.
  partialRepaint = false
  defer: partialRepaint = true
  markAll(s.root)
  s.root.renderPass()
  pixels(s.root)

var before: seq[Color]

proc fullBefore(s: Scene): seq[Color] = before

proc changed(w: Widget): int =
  ## How many widgets in the tree redrew only part of themselves last pass.
  if w.damage.width < w.bounds.width or w.damage.height < w.bounds.height: result = 1
  for c in w.children: result += changed(c)

suite "partial repaint":

  test "a progress bar's value changes: same pixels, and some widget did less than all":
    let s = build()
    s.bar.value = 70.0
    s.bar.markDirtyToRoot()
    settle(s)
    check changed(s.root) > 0
    let partial = pixels(s.root)
    check partial == fullRepaint(s)

  test "text changes size: layout moves things, still identical":
    let s = build()
    s.label.text = "a much longer greeting than before"
    s.label.layoutDirty = true
    s.label.markDirtyToRoot()
    settle(s)
    check pixels(s.root) == fullRepaint(s)

  test "an overlapping sibling inside the damage is drawn again, in order":
    let s = build()
    s.under.color = Color(r: 20, g: 200, b: 90, a: 255)
    s.under.markDirtyToRoot()
    settle(s)
    check pixels(s.root) == fullRepaint(s)

  test "many changes in a row never drift from a full repaint":
    let s = build()
    for i in 0 ..< 12:
      case i mod 4
      of 0:
        s.bar.value = float32(i * 7)
        s.bar.markDirtyToRoot()
      of 1:
        s.label.text = "n=" & $i
        s.label.layoutDirty = true
        s.label.markDirtyToRoot()
      of 2:
        s.chip.color = Color(r: uint8(i * 20), g: 60, b: 200, a: 200)
        s.chip.markDirtyToRoot()
      else:
        s.button.markDirtyToRoot()
      settle(s)
    check pixels(s.root) == fullRepaint(s)

  test "a widget that changed itself repaints whole":
    let s = build()
    s.root.children[0].isDirty = true            # the panel itself, by hand
    settle(s)
    check s.root.children[0].damage == s.root.children[0].bounds

  test "with the switch off nothing is partial":
    let s = build()
    partialRepaint = false
    defer: partialRepaint = true
    s.bar.value = 50.0
    s.bar.markDirtyToRoot()
    settle(s)
    check changed(s.root) == 0

  test "a leaf marked dirty by hand (no walk to the root) still reaches the screen":
    # What a key press does: the widget's handler sets its own flag and nobody
    # marks the ancestors. The parents used to be re-composited only when something
    # else happened to repaint them -- typed text showed up a blink late.
    let s = build()
    before = pixels(s.root)
    s.bar.value = 90.0
    s.bar.isDirty = true                          # not markDirtyToRoot
    settle(s)
    let shown = pixels(s.root)
    check shown != fullBefore(s)
    check shown == fullRepaint(s)
