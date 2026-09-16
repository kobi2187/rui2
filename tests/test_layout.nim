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
