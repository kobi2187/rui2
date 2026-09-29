## Layout system regression tests
##
## Covers the two things that were silently broken for a long time: containers
## not laying out their children at all, and widgets having no size of their own.
## Also pins down the dirty-gating, so nobody "optimises" the layout pass into
## running unconditionally again — or the reverse, gates it so hard that a
## content change stops reaching the screen.
##
## No GL context needed: layout only measures text (Pango, CPU-side).

import std/unittest
import rui
import std/options

suite "layout: containers arrange their children":

  test "VStack stacks children top to bottom with spacing":
    let root = newVStack(spacing = 10.0, padding = 5.0)
    root.bounds = Rect(x: 0, y: 0, width: 200, height: 400)

    let a = newLabel(text = "one", fontSize = 14.0)
    let b = newLabel(text = "two", fontSize = 14.0)
    let c = newLabel(text = "three", fontSize = 14.0)
    for w in [Widget(a), Widget(b), Widget(c)]:
      root.addChild(w)

    root.layout()

    check a.bounds.y == root.bounds.y + 5.0
    check b.bounds.y == a.bounds.y + a.bounds.height + 10.0
    check c.bounds.y == b.bounds.y + b.bounds.height + 10.0
    # every child shares the container's inner width
    check a.bounds.width == 190.0
    check c.bounds.width == 190.0

  test "HStack lays children left to right":
    let row = newHStack(spacing = 8.0)
    row.bounds = Rect(x: 10, y: 10, width: 400, height: 40)

    let a = newLabel(text = "aa", fontSize = 14.0)
    let b = newLabel(text = "bb", fontSize = 14.0)
    row.addChild(a)
    row.addChild(b)

    row.layout()

    check a.bounds.x == 10.0
    check b.bounds.x == a.bounds.x + a.bounds.width + 8.0
    check a.bounds.y == b.bounds.y

  test "nested stacks position grandchildren":
    let root = newVStack(spacing = 0.0, padding = 0.0)
    root.bounds = Rect(x: 0, y: 0, width: 300, height: 300)
    let row = newHStack(spacing = 4.0)
    let leaf = newLabel(text = "deep", fontSize = 14.0)
    row.addChild(leaf)
    root.addChild(row)

    root.layout()

    check leaf.bounds.x >= root.bounds.x
    check leaf.bounds.y >= root.bounds.y
    check leaf.bounds.height > 0

  test "a container with no children does not crash or produce NaN":
    let empty = newVStack(spacing = 8.0, padding = 4.0)
    empty.bounds = Rect(x: 0, y: 0, width: 100, height: 0)
    empty.layout()
    check empty.bounds.height >= 0

suite "layout: widgets size themselves to their content":

  test "a Label takes its natural width and height":
    let short = newLabel(text = "hi", fontSize = 16.0)
    let long = newLabel(text = "a much longer piece of text", fontSize = 16.0)
    short.layout()
    long.layout()

    check short.bounds.width > 0
    check short.bounds.height > 0
    check long.bounds.width > short.bounds.width
    check long.bounds.height == short.bounds.height  # same single line

  test "font size drives label height":
    let small = newLabel(text = "Wg", fontSize = 10.0)
    let big = newLabel(text = "Wg", fontSize = 30.0)
    small.layout()
    big.layout()
    check big.bounds.height > small.bounds.height
    check big.bounds.width > small.bounds.width

  test "a Button sizes to its text plus padding":
    let b = newButton(text = "OK")
    let wide = newButton(text = "A much wider caption")
    b.layout()
    wide.layout()

    check b.bounds.width > 0
    check b.bounds.height > 0
    check wide.bounds.width > b.bounds.width
    # padding means the button is wider than the bare text
    let m = measureText("OK", TextStyle(fontFamily: "", fontSize: 14.0,
                                        color: BLACK, bold: false,
                                        italic: false, underline: false))
    check b.bounds.width > m.width

  test "a parent-assigned width is respected, not overwritten":
    let l = newLabel(text = "x", fontSize = 14.0)
    l.bounds.width = 500
    l.layout()
    check l.bounds.width == 500.0

  test "wrapping increases height and respects the assigned width":
    let l = newLabel(
      text = "this label has enough words in it that it must wrap " &
             "across several lines when given a narrow width",
      fontSize = 14.0, wrap = true)
    l.bounds.width = 120
    l.layout()
    check l.bounds.width == 120.0
    check l.bounds.height > 20.0   # definitely more than one line

  test "stacks size to content when given no size":
    let col = newVStack(spacing = 5.0, padding = 10.0)
    col.addChild(newLabel(text = "one", fontSize = 14.0))
    col.addChild(newLabel(text = "two", fontSize = 14.0))
    col.layout()
    check col.bounds.height > 0
    check col.bounds.width > 0

  test "a row of buttons does not collapse":
    # Regression: an HStack with no height of its own used to force height 0
    # onto every child, so a button row rendered as a sliver.
    let row = newHStack(spacing = 10.0)
    let a = newButton(text = "-")
    let b = newButton(text = "+")
    row.addChild(a)
    row.addChild(b)
    row.layout()

    check a.bounds.height > 0
    check b.bounds.height > 0
    check row.bounds.height >= a.bounds.height

suite "layout: dirty gating":

  test "a fresh widget starts dirty so the first frame draws it":
    let l = newLabel(text = "x", fontSize = 14.0)
    check l.layoutDirty
    check l.isDirty
    check l.visible      # regression: constructors used to leave this false
    check l.enabled

  test "layoutPass clears layoutDirty and skips clean widgets":
    let root = newVStack(spacing = 4.0)
    root.bounds = Rect(x: 0, y: 0, width: 200, height: 200)
    let l = newLabel(text = "start", fontSize = 14.0)
    root.addChild(l)

    root.layoutPass()
    check not root.layoutDirty
    check not l.layoutDirty

    # A clean tree must not re-run layout: change the text behind layout's back
    # and confirm the cached size is untouched.
    let heightBefore = l.bounds.height
    l.text = "a much much longer string that would measure wider"
    root.layoutPass()
    check l.bounds.height == heightBefore

    # Marking it dirty makes the next pass pick the change up.
    l.layoutDirty = true
    root.layoutPass()
    check l.bounds.width > 0

  test "anyChildLayoutDirty sees a dirty descendant":
    let root = newVStack()
    root.bounds = Rect(x: 0, y: 0, width: 100, height: 100)
    let mid = newVStack()
    let leaf = newLabel(text = "x", fontSize = 14.0)
    mid.addChild(leaf)
    root.addChild(mid)

    root.layoutPass()
    check not root.anyChildLayoutDirty()

    leaf.layoutDirty = true
    check root.anyChildLayoutDirty()

  test "markDirtyToRoot dirties the ancestor line but not siblings":
    let root = newVStack()
    let branchA = newVStack()
    let branchB = newVStack()
    let leaf = newLabel(text = "x", fontSize = 14.0)
    branchA.addChild(leaf)
    root.addChild(branchA)
    root.addChild(branchB)

    for w in [Widget(root), Widget(branchA), Widget(branchB), Widget(leaf)]:
      w.isDirty = false

    leaf.markDirtyToRoot()

    check leaf.isDirty
    check branchA.isDirty
    check root.isDirty
    check not branchB.isDirty   # untouched subtree keeps its cached texture

  test "markSubtreeDirty dirties everything below":
    let root = newVStack()
    let a = newLabel(text = "a", fontSize = 14.0)
    let b = newLabel(text = "b", fontSize = 14.0)
    root.addChild(a)
    root.addChild(b)
    for w in [Widget(root), Widget(a), Widget(b)]:
      w.isDirty = false
      w.layoutDirty = false

    root.markSubtreeDirty()
    check a.isDirty and b.isDirty and root.isDirty
    check a.layoutDirty and b.layoutDirty

suite "layout: widget identity":

  test "widget ids are unique":
    # Regression: the id counter was {.compileTime.}, so every widget built at
    # runtime received id 0 and collided in the widget map.
    let a = newLabel(text = "a", fontSize = 14.0)
    let b = newLabel(text = "b", fontSize = 14.0)
    let c = newButton(text = "c")
    check a.id != b.id
    check b.id != c.id
    check a.id != c.id

  test "addChild sets the parent link":
    let parent = newVStack()
    let child = newLabel(text = "x", fontSize = 14.0)
    parent.addChild(child)
    check child.parent == Widget(parent)
    check parent.children.len == 1

  test "treeDepth counts ancestors":
    let root = newVStack()
    let mid = newVStack()
    let leaf = newLabel(text = "x", fontSize = 14.0)
    mid.addChild(leaf)
    root.addChild(mid)
    check root.treeDepth == 0
    check mid.treeDepth == 1
    check leaf.treeDepth == 2

suite "what a bounds change invalidates":
  ## A widget renders into its own texture with its origin at (0, 0), so the
  ## texture's content depends on its SIZE, never on where it sits. Position
  ## affects only the parent, which composites children at relative offsets.
  ##
  ## So the two cases are genuinely different:
  ##   resized  -> the widget must re-render, and the parent must re-composite
  ##   moved    -> the widget keeps its texture; only the parent re-composites
  ##
  ## The old rule was `bounds != oldBounds -> isDirty`, which re-rendered a
  ## whole subtree that had merely slid sideways, and never told the parent.

  proc fixedStack(spacing: float32): tuple[stack: Widget, a, b: Widget] =
    let s = newVStack(spacing = spacing)
    s.bounds = Rect(x: 0, y: 0, width: 200, height: 200)
    let a = newLabel(text = "a", fontSize = 14.0)
    let b = newLabel(text = "b", fontSize = 14.0)
    s.addChild(a)
    s.addChild(b)
    s.layoutDirty = true
    s.layoutPass()
    (Widget(s), Widget(a), Widget(b))

  test "moving a child re-composites the parent without re-rendering the child":
    let (stack, a, b) = fixedStack(4.0)
    stack.isDirty = false
    a.isDirty = false
    b.isDirty = false
    let before = b.bounds.y

    VStack(stack).spacing = 40.0
    stack.layoutDirty = true
    stack.layoutPass()

    check b.bounds.y != before        # it moved
    check not b.isDirty               # its texture is unchanged
    check stack.isDirty               # the parent's composite is not

  test "resizing a widget re-renders it and re-composites its parent":
    let (stack, a, _) = fixedStack(4.0)
    stack.isDirty = false
    a.isDirty = false

    # Font size, not text: the stack imposes the width, and one line stays one
    # line, so a longer string would not actually change the label's size.
    Label(a).fontSize = 40.0
    a.layoutDirty = true
    a.layoutPass()

    check a.isDirty                   # its texture is a different size now
    check stack.isDirty               # so the parent's composite changed too

  test "a layout that changes nothing dirties nothing":
    let (stack, a, b) = fixedStack(4.0)
    stack.isDirty = false
    a.isDirty = false
    b.isDirty = false

    stack.layoutDirty = true
    stack.layoutPass()

    check not stack.isDirty
    check not a.isDirty
    check not b.isDirty

suite "composites reuse their children":
  ## renderPass composites a parent from its children's cached textures, so a
  ## composite that recreates its children every layout throws away the very
  ## thing the cache exists to reuse -- and hands each child a fresh WidgetId
  ## each frame, which hit-testing and the focus chain do not expect.

  test "a Button keeps the same child widgets across relayouts":
    let b = newButton(text = "press")
    b.layoutDirty = true
    b.layoutPass()
    check b.children.len == 2
    let bgId = b.children[0].id
    let labelId = b.children[1].id

    # Relayout for a reason that changes nothing structural.
    b.isHovered = true
    b.layoutDirty = true
    b.layoutPass()

    check b.children.len == 2
    check b.children[0].id == bgId        # same widget, not a replacement
    check b.children[1].id == labelId

  test "the child keeps its parent link, which bubbling relies on":
    let b = newButton(text = "press")
    b.layoutDirty = true
    b.layoutPass()
    for child in b.children:
      check child.parent == Widget(b)

  test "the label still tracks the button's text":
    let b = newButton(text = "before")
    b.layoutDirty = true
    b.layoutPass()
    check Label(b.children[1]).text == "before"

    b.text = "after"
    b.layoutDirty = true
    b.layoutPass()
    check Label(b.children[1]).text == "after"

suite "adding a widget marks the parent for layout":
  ## The frame's post-layout work -- rebuilding the hit-test trees and
  ## re-registering stringIds -- is gated on layout having run, so a widget
  ## added without marking its parent would be invisible to both clicks and
  ## scripting selectors.

  test "addChild marks the parent layoutDirty":
    let root = newVStack(spacing = 4.0)
    root.layoutDirty = false
    root.addChild(newLabel(text = "x", fontSize = 14.0))
    check root.layoutDirty

  test "a child added after the first layout still gets bounds":
    let root = newVStack(spacing = 4.0)
    root.bounds = Rect(x: 0, y: 0, width: 200, height: 200)
    root.addChild(newLabel(text = "first", fontSize = 14.0))
    root.layoutPass()

    let late = newLabel(text = "added later", fontSize = 14.0)
    root.addChild(late)
    root.layoutPass()

    check late.bounds.height > 0      # it was laid out, not left at zero

suite "flex: stacks share leftover space":

  test "flexShares splits by weight and ignores non-positive weights":
    check flexShares([0.0'f32, 1.0, 3.0], 100.0) == @[0.0'f32, 25.0, 75.0]
    check flexShares([1.0'f32, 1.0], 0.0) == @[0.0'f32, 0.0]
    check flexShares([1.0'f32, 1.0], -10.0) == @[-5.0'f32, -5.0]   # shrink
    check flexShares([0.0'f32, -1.0], 50.0) == @[0.0'f32, 0.0]

  test "a Spacer pushes the children after it to the bottom of a VStack":
    let root = newVStack(spacing = 0.0, padding = 10.0)
    root.bounds = Rect(x: 0, y: 0, width: 200, height: 400)
    let top = newLabel(text = "top", fontSize = 14.0)
    let gap = newSpacer()
    let bottom = newLabel(text = "bottom", fontSize = 14.0)
    for w in [Widget(top), Widget(gap), Widget(bottom)]:
      root.addChild(w)

    root.layout()

    check top.bounds.y == 10.0
    check bottom.bounds.y + bottom.bounds.height == 390.0   # flush with padding
    check gap.bounds.y == top.bounds.y + top.bounds.height
    check gap.bounds.height == bottom.bounds.y - gap.bounds.y
    check root.bounds.height == 400.0                       # the stack kept its size

  test "two spacers split the room by their weights":
    let root = newVStack(spacing = 0.0)
    root.bounds = Rect(x: 0, y: 0, width: 100, height: 300)
    let a = newSpacer(grow = 1.0)
    let b = newSpacer(grow = 2.0)
    root.addChild(a)
    root.addChild(b)

    root.layout()

    check a.bounds.height == 100.0
    check b.bounds.height == 200.0
    check b.bounds.y == 100.0

  test "a grown Spacer shrinks back when the stack does":
    let root = newVStack(spacing = 0.0)
    root.bounds = Rect(x: 0, y: 0, width: 100, height: 300)
    let gap = newSpacer(minHeight = 5.0)
    root.addChild(gap)
    root.layout()
    check gap.bounds.height == 300.0

    root.bounds.height = 120
    root.layout()
    check gap.bounds.height == 120.0

  test "any widget can flex, not only Spacer":
    let row = newHStack(spacing = 0.0)
    row.bounds = Rect(x: 0, y: 0, width: 500, height: 30)
    let left = newLabel(text = "left", fontSize = 14.0)
    let fill = newLabel(text = "fill", fontSize = 14.0)
    fill.flexGrow = 1.0
    let right = newLabel(text = "right", fontSize = 14.0)
    for w in [Widget(left), Widget(fill), Widget(right)]:
      row.addChild(w)

    row.layout()

    check right.bounds.x + right.bounds.width == 500.0
    check fill.bounds.x == left.bounds.x + left.bounds.width
    check fill.bounds.width > left.bounds.width

  test "a stack that sizes to its content has nothing to hand out":
    let root = newVStack(spacing = 0.0)        # no height of its own
    let label = newLabel(text = "only", fontSize = 14.0)
    let gap = newSpacer(minHeight = 12.0)
    root.addChild(label)
    root.addChild(gap)

    root.layout()

    check gap.bounds.height == 12.0
    check root.bounds.height == label.bounds.height + 12.0

suite "self-sized widgets re-measure":
  ## `bounds.width <= 0` meant "measure yourself" only the first time: after
  ## that a self-computed size looked like one the parent had assigned.

  test "a content-sized stack grows when a child is added":
    let root = newVStack(spacing = 0.0)
    root.addChild(newLabel(text = "one", fontSize = 14.0))
    root.layout()
    let h1 = root.bounds.height
    root.addChild(newLabel(text = "two", fontSize = 14.0))
    root.layout()
    check root.bounds.height > h1

  test "and shrinks when one is removed":
    let root = newVStack(spacing = 0.0)
    for t in ["a", "b", "c"]:
      root.addChild(newLabel(text = t, fontSize = 14.0))
    root.layout()
    let h3 = root.bounds.height
    root.children.setLen(1)
    root.layout()
    check root.bounds.height < h3

  test "a content-sized row widens with longer text":
    let row = newHStack(spacing = 4.0)
    let l = newLabel(text = "short", fontSize = 14.0)
    row.addChild(l)
    row.layout()
    let w1 = row.bounds.width
    l.text = "a good deal longer than it was"
    row.layout()
    check row.bounds.width > w1

  test "a size the parent assigned is kept":
    let root = newVStack(spacing = 0.0)
    root.bounds = Rect(x: 0, y: 0, width: 300, height: 200)
    root.addChild(newLabel(text = "x", fontSize = 14.0))
    root.layout()
    root.layout()
    check root.bounds.width == 300.0
    check root.bounds.height == 200.0

  test "a nested content-sized stack follows its content too":
    let outer = newVStack(spacing = 0.0)
    outer.bounds = Rect(x: 0, y: 0, width: 300, height: 400)
    let inner = newVStack(spacing = 0.0)
    inner.addChild(newLabel(text = "1", fontSize = 14.0))
    outer.addChild(inner)
    outer.layout()
    let h1 = inner.bounds.height
    inner.addChild(newLabel(text = "2", fontSize = 14.0))
    outer.layout()
    check inner.bounds.height > h1

suite "cross-axis alignment in stacks":

  test "stretch is the default and keeps today's behaviour":
    let col = newVStack(spacing = 0.0)
    col.bounds = Rect(x: 0, y: 0, width: 200, height: 100)
    let l = newLabel(text = "x", fontSize = 14.0)
    col.addChild(l)
    col.layout()
    check l.bounds.width == 200.0

  test "a centred row lines a label up with a taller input":
    let row = newHStack(spacing = 8.0, crossAlign = CrossCenter)
    let l = newLabel(text = "Name:", fontSize = 14.0)
    let t = newTextInput()
    row.addChild(l)
    row.addChild(t)
    row.layout()
    check t.bounds.height > l.bounds.height
    let lMid = l.bounds.y + l.bounds.height / 2
    let tMid = t.bounds.y + t.bounds.height / 2
    check abs(lMid - tMid) < 0.5

  test "end alignment in a VStack with a width puts children on the right":
    let col = newVStack(spacing = 0.0, crossAlign = CrossEnd)
    col.bounds = Rect(x: 10, y: 0, width: 200, height: 100)
    let l = newLabel(text = "right", fontSize = 14.0)
    col.addChild(l)
    col.layout()
    check l.bounds.x + l.bounds.width == 210.0
    check l.bounds.width < 200.0

  test "an aligned child's own children move with it":
    let row = newHStack(spacing = 0.0, crossAlign = CrossEnd)
    row.bounds = Rect(x: 0, y: 0, width: 300, height: 100)
    let inner = newVStack(spacing = 0.0)
    let leaf = newLabel(text = "deep", fontSize = 14.0)
    inner.addChild(leaf)
    row.addChild(inner)
    row.layout()
    check leaf.bounds.y + leaf.bounds.height == 100.0

suite "size requests are honoured by layout":

  test "a requested size wins over stretch":
    let col = newVStack(spacing = 0.0)
    col.bounds = Rect(x: 0, y: 0, width: 300, height: 200)
    let l = newLabel(text = "x", fontSize = 14.0).frame(width = 120)
    col.addChild(l)
    col.layout()
    check l.bounds.width == 120.0

  test "a requested height on a leaf with no layout of its own":
    let r = newRectangle().frame(width = 90, height = 60)
    let row = newHStack(spacing = 0.0)
    row.addChild(r)
    row.layout()
    check r.bounds.width == 90.0 and r.bounds.height == 60.0
    check row.bounds.height == 60.0              # the row sized around it

  test "min and max clamp a content-sized widget":
    let short = newLabel(text = "hi", fontSize = 14.0).frame(minWidth = 100)
    short.layout()
    check short.bounds.width == 100.0
    let long = newLabel(text = "a rather long caption indeed",
                        fontSize = 14.0).frame(maxWidth = 50)
    long.layout()
    check long.bounds.width == 50.0

  test "a stretched child is still clamped by its max":
    let col = newVStack(spacing = 0.0)
    col.bounds = Rect(x: 0, y: 0, width: 400, height: 100)
    let l = newLabel(text = "x", fontSize = 14.0).frame(maxWidth = 150)
    col.addChild(l)
    col.layout()
    check l.bounds.width == 150.0

  test "unframe goes back to content size":
    let l = newLabel(text = "x", fontSize = 14.0).frame(width = 200)
    l.layout()
    check l.bounds.width == 200.0
    discard l.unframe()
    l.layout()
    check l.bounds.width < 200.0

  test "a requested size survives relayout":
    let r = newRectangle().frame(width = 50, height = 20)
    r.layout()
    r.layout()
    check r.bounds.width == 50.0 and r.bounds.height == 20.0

suite "stack justification":

  test "mainOffsets spends the spare room as asked":
    check mainOffsets(MainStart, 90.0, 3) == (0.0'f32, 0.0'f32)
    check mainOffsets(MainCenter, 90.0, 3) == (45.0'f32, 0.0'f32)
    check mainOffsets(MainEnd, 90.0, 3) == (90.0'f32, 0.0'f32)
    check mainOffsets(SpaceBetween, 90.0, 3) == (0.0'f32, 45.0'f32)
    check mainOffsets(SpaceAround, 90.0, 3) == (15.0'f32, 30.0'f32)
    check mainOffsets(SpaceEvenly, 80.0, 3) == (20.0'f32, 20.0'f32)

  test "a row pushed to the end":
    let row = newHStack(spacing = 0.0, mainAlign = MainEnd)
    row.bounds = Rect(x: 0, y: 0, width: 300, height: 40)
    let b = newRectangle().frame(width = 50, height = 20)
    row.addChild(b)
    row.layout()
    check b.bounds.x == 250.0

  test "space between puts the ends on the edges":
    let row = newHStack(spacing = 0.0, mainAlign = SpaceBetween)
    row.bounds = Rect(x: 0, y: 0, width: 300, height: 40)
    let a = newRectangle().frame(width = 50, height = 20)
    let b = newRectangle().frame(width = 50, height = 20)
    row.addChild(a)
    row.addChild(b)
    row.layout()
    check a.bounds.x == 0.0
    check b.bounds.x + b.bounds.width == 300.0

  test "a flex child takes the room first; justification has none left":
    let row = newHStack(spacing = 0.0, mainAlign = MainEnd)
    row.bounds = Rect(x: 0, y: 0, width: 300, height: 40)
    let a = newRectangle().frame(width = 50, height = 20)
    let f = newSpacer()
    row.addChild(a)
    row.addChild(f)
    row.layout()
    check a.bounds.x == 0.0

suite "Grid":

  test "tracks: fixed, fit and star":
    let w = resolveTracks([px(100.0), fit(), star(1.0), star(3.0)],
                          [0.0'f32, 40.0, 10.0, 10.0], 540.0)
    check w == @[100.0'f32, 40.0, 100.0, 300.0]

  test "with no width, star columns size like fit":
    check resolveTracks([star(), star()], [30.0'f32, 70.0], 0.0) == @[30.0'f32, 70.0]

  test "a form: labels in a fit column, inputs filling the rest":
    let g = newGrid(columns = @[fit(), star()], colSpacing = 10.0, rowSpacing = 6.0)
    g.bounds = Rect(x: 0, y: 0, width: 400, height: 0)
    let name = newLabel(text = "Name", fontSize = 14.0)
    let nameIn = newTextInput()
    let email = newLabel(text = "Email address", fontSize = 14.0)
    let emailIn = newTextInput()
    for w in [Widget(name), nameIn, email, emailIn]:
      g.addChild(w)
    g.layout()
    check nameIn.bounds.x == emailIn.bounds.x           # one column
    check nameIn.bounds.x == email.bounds.width + 10.0  # after the widest label
    check nameIn.bounds.x + nameIn.bounds.width == 400.0
    check emailIn.bounds.y == nameIn.bounds.y + nameIn.bounds.height + 6.0
    check g.bounds.height == emailIn.bounds.y + emailIn.bounds.height

suite "Wrap":

  test "lineBreaks starts a line when the next child would cross the edge":
    check lineBreaks([40.0'f32, 40, 40, 40], 100.0, 10.0) == @[0, 2]
    check lineBreaks([40.0'f32, 40, 40], 0.0, 10.0) == @[0]      # no edge
    check lineBreaks([150.0'f32, 20], 100.0, 10.0) == @[0, 1]    # too wide: alone

  test "chips flow onto a second line":
    let w = newWrap(spacing = 4.0, lineSpacing = 4.0)
    w.bounds = Rect(x: 0, y: 0, width: 100, height: 0)
    var chips: seq[Widget]
    for i in 0 ..< 4:
      let c = newRectangle().frame(width = 40, height = 20)
      chips.add c
      w.addChild(c)
    w.layout()
    check chips[1].bounds.y == chips[0].bounds.y
    check chips[2].bounds.y == 24.0
    check chips[2].bounds.x == 0.0
    check w.bounds.height == 44.0

suite "Align and Center":

  test "Center puts its child in the middle":
    let c = newCenter().frame(width = 200, height = 100)
    let r = newRectangle().frame(width = 50, height = 20)
    c.addChild(r)
    c.layout()
    check r.bounds.x == 75.0 and r.bounds.y == 40.0

  test "an Align with no size wraps its content plus padding":
    let a = newAlign(padding = 10.0)
    a.addChild(newRectangle().frame(width = 50, height = 20))
    a.layout()
    check a.bounds.width == 70.0 and a.bounds.height == 40.0

  test "bottom-right":
    let a = newAlign(horizontal = CrossEnd, vertical = CrossEnd).frame(width = 100, height = 100)
    let r = newRectangle().frame(width = 10, height = 10)
    a.addChild(r)
    a.layout()
    check r.bounds.x == 90.0 and r.bounds.y == 90.0

  test "a ZStack with no size takes its largest child's":
    let z = newZStack()
    z.addChild(newRectangle().frame(width = 80, height = 30))
    z.addChild(newLabel(text = "on top", fontSize = 14.0))
    z.layout()
    check z.bounds.width == 80.0 and z.bounds.height == 30.0

  test "an overflowing row shrinks its flex child instead of spilling":
    let row = newHStack(spacing = 0.0)
    row.bounds = Rect(x: 0, y: 0, width: 300, height: 40)
    let fixed = newRectangle().frame(width = 200, height = 20)
    let col = newVStack(spacing = 0.0).flex
    col.addChild(newRectangle().frame(width = 180, height = 20))   # wants 180
    col.addChild(newLabel(text = "stretches", fontSize = 14.0))
    row.addChild(fixed)
    row.addChild(col)
    row.layout()
    check col.bounds.x + col.bounds.width == 300.0     # stops at the edge
    check fixed.bounds.width == 200.0                  # fixed never shrinks
    check col.children[1].bounds.width == col.bounds.width  # stretched to it

suite "Grid rows":

  test "a short cell is centred in a tall row":
    let g = newGrid(columns = @[fit(), star()], colSpacing = 0.0)
    g.bounds = Rect(x: 0, y: 0, width: 300, height: 0)
    let lbl = newRectangle().frame(width = 40, height = 10)
    let tall = newRectangle().frame(height = 30)
    g.addChild(lbl)
    g.addChild(tall)
    g.layout()
    check lbl.bounds.y == 10.0
