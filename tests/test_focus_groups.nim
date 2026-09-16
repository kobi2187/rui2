## Two-level keyboard navigation — between groups, and within one
##
## The four design questions from issue #19, each written down as a test so a
## different answer is a visible change rather than a silent one:
##
##   Tab enters the group (roving tabindex), Enter is not required.
##   Escape pops exactly one level.
##   Arrows stop at the ends; they do not wrap and do not leak out.
##   Groups nest.

import std/unittest
import std/options
import rui
import std/monotimes
from raylib import KeyboardKey

proc keyEvent(key: KeyboardKey): GuiEvent =
  GuiEvent(kind: evKeyDown, key: key, timestamp: getMonoTime())

proc stop(name: string): Widget =
  ## A plain focusable leaf.
  let w = newLabel(text = name, fontSize = 14.0)
  w.focusable = true
  Widget(w)

proc group(children: varargs[Widget]): Widget =
  ## A container that is one Tab stop from outside.
  let g = newVStack()
  g.focusGroup = true
  for c in children:
    g.addChild(c)
  Widget(g)

proc plain(children: varargs[Widget]): Widget =
  ## A container that is not a group: its children belong to the level it is in.
  let v = newVStack()
  for c in children:
    v.addChild(c)
  Widget(v)

suite "what a level contains":

  test "a plain container is transparent to navigation":
    let a = stop("a")
    let b = stop("b")
    let root = plain(a, plain(b))
    check focusEntries(root) == @[a, b]

  test "a group is one entry, and is not descended into":
    let inner1 = stop("i1")
    let inner2 = stop("i2")
    let g = group(inner1, inner2)
    let outer = stop("o")
    let root = plain(outer, g)
    check focusEntries(root) == @[outer, g]
    check focusEntries(g) == @[inner1, inner2]

  test "a hidden group is not a group and not an entry":
    let g = group(stop("i"))
    g.visible = false
    let root = plain(stop("a"), g)
    check not g.isGroup
    check focusEntries(root).len == 1

  test "a disabled member is skipped":
    let a = stop("a")
    let b = stop("b")
    b.enabled = false
    let root = plain(a, b)
    check focusEntries(root) == @[a]

suite "depth and enclosure":

  test "a widget outside every group has no enclosing group":
    let a = stop("a")
    discard plain(a)
    check enclosingGroup(a) == nil
    check groupDepth(a) == 0

  test "a group's own enclosing group is the one outside it":
    # This is what makes Escape pop exactly one level rather than none.
    let leaf = stop("leaf")
    let inner = group(leaf)
    let outer = group(inner)
    discard plain(outer)
    check enclosingGroup(leaf) == inner
    check enclosingGroup(inner) == outer
    check enclosingGroup(outer) == nil
    check groupDepth(leaf) == 2

suite "Tab enters a group and lands on a member":

  setup:
    let a = stop("a")
    let m1 = stop("m1")
    let m2 = stop("m2")
    let g = group(m1, m2)
    let z = stop("z")
    let root = plain(a, g, z)
    let fm = newFocusManager()

  test "the first Tab lands on the first stop":
    fm.nextFocus(root)
    check fm.getFocusedWidget() == a

  test "Tab onto a group lands inside it, not on it":
    fm.nextFocus(root)
    fm.nextFocus(root)
    check fm.getFocusedWidget() == m1
    check fm.activeGroup == g

  test "Tab from inside the group leaves it entirely":
    # Roving tabindex: a group is one stop, not two. Tab from m1 goes to z,
    # not to m2 -- m2 is reached with an arrow key.
    fm.setFocus(m1)
    fm.nextFocus(root)
    check fm.getFocusedWidget() == z
    check fm.activeGroup == nil

  test "Tab from the middle of a group also leaves entirely":
    fm.setFocus(m2)
    fm.nextFocus(root)
    check fm.getFocusedWidget() == z

  test "Shift+Tab into a group lands on its last member":
    # So reversing direction retraces the same path.
    fm.setFocus(z)
    fm.prevFocus(root)
    check fm.getFocusedWidget() == m2

  test "Shift+Tab out of a group leaves entirely":
    fm.setFocus(m2)
    fm.prevFocus(root)
    check fm.getFocusedWidget() == a

  test "an empty group is skipped, not a dead stop":
    let empty = group()
    root.addChild(empty)
    fm.setFocus(z)
    fm.nextFocus(root)
    check fm.getFocusedWidget() == a       # wrapped past the empty group

suite "arrows move within the active group":

  setup:
    let a = stop("a")
    let m1 = stop("m1")
    let m2 = stop("m2")
    let m3 = stop("m3")
    let g = group(m1, m2, m3)
    let root = plain(a, g)
    let fm = newFocusManager()

  test "an arrow key does nothing outside a group":
    fm.setFocus(a)
    check not fm.moveWithinGroup(1)
    check fm.getFocusedWidget() == a

  test "arrows step through the members":
    fm.setFocus(m1)
    check fm.moveWithinGroup(1)
    check fm.getFocusedWidget() == m2
    check fm.moveWithinGroup(1)
    check fm.getFocusedWidget() == m3

  test "arrows stop at the end and leave the key unhandled":
    # The decision: no wrapping and no leaking. An arrow that silently jumps
    # out of the group the user is reading is worse than one that does nothing.
    fm.setFocus(m3)
    check not fm.moveWithinGroup(1)
    check fm.getFocusedWidget() == m3

  test "and at the start":
    fm.setFocus(m1)
    check not fm.moveWithinGroup(-1)
    check fm.getFocusedWidget() == m1

  test "wrapping is available for callers who want it":
    fm.wrapWithinGroup = true
    fm.setFocus(m3)
    check fm.moveWithinGroup(1)
    check fm.getFocusedWidget() == m1

  test "clicking into a group makes its arrows live":
    # activeGroup follows focus rather than being set separately, so there is
    # one answer to "which group are we in".
    fm.requestFocus(m2)
    check fm.activeGroup == g
    check fm.moveWithinGroup(1)
    check fm.getFocusedWidget() == m3

suite "Escape pops one level":

  setup:
    let a = stop("a")
    let leaf1 = stop("leaf1")
    let leaf2 = stop("leaf2")
    let inner = group(leaf1, leaf2)
    let sibling = stop("sibling")
    let outer = group(sibling, inner)
    let root = plain(a, outer)
    let fm = newFocusManager()

  test "Escape outside a group does nothing":
    fm.setFocus(a)
    check not fm.exitGroup()

  test "Escape leaves the inner group but stays in the outer one":
    # The nested case is the whole reason the answer is "one level".
    fm.setFocus(leaf1)
    check fm.activeGroup == inner
    check fm.exitGroup()
    check fm.activeGroup == outer
    check fm.getFocusedWidget() == sibling

  test "a second Escape leaves the outer group too":
    fm.setFocus(leaf1)
    check fm.exitGroup()
    check fm.exitGroup()
    check fm.activeGroup == nil
    check fm.getFocusedWidget() == a

suite "key routing, innermost first":

  setup:
    let a = stop("a")
    let m1 = stop("m1")
    let m2 = stop("m2")
    let g = group(m1, m2)
    let root = plain(a, g)
    let fm = newFocusManager()

  test "Down inside a group moves within it":
    fm.setFocus(m1)
    check fm.handleKeyboardEvent(keyEvent(KeyboardKey.Down), root)
    check fm.getFocusedWidget() == m2

  test "Tab inside a group still leaves it":
    fm.setFocus(m1)
    check fm.handleKeyboardEvent(keyEvent(KeyboardKey.Tab), root)
    check fm.getFocusedWidget() == a       # wrapped past the end

  test "Escape inside a group is handled":
    fm.setFocus(m1)
    check fm.handleKeyboardEvent(keyEvent(KeyboardKey.Escape), root)
    check fm.activeGroup == nil

  test "Down at the end of a group is left unhandled":
    # Not swallowed: the caller may want it for something else.
    fm.setFocus(m2)
    check not fm.handleKeyboardEvent(keyEvent(KeyboardKey.Down), root)

  test "Down outside a group is left unhandled":
    fm.setFocus(a)
    check not fm.handleKeyboardEvent(keyEvent(KeyboardKey.Down), root)

  test "the group keys are configurable":
    fm.setGroupKeys(@[KeyboardKey.J], @[KeyboardKey.K], @[KeyboardKey.Q])
    fm.setFocus(m1)
    check fm.handleKeyboardEvent(keyEvent(KeyboardKey.J), root)
    check fm.getFocusedWidget() == m2
    check fm.handleKeyboardEvent(keyEvent(KeyboardKey.K), root)
    check fm.getFocusedWidget() == m1
    check not fm.handleKeyboardEvent(keyEvent(KeyboardKey.Down), root)

suite "nesting":

  test "Tab into a group whose first entry is a group descends all the way":
    let deep = stop("deep")
    let inner = group(deep)
    let outer = group(inner)
    let a = stop("a")
    let root = plain(a, outer)
    let fm = newFocusManager()

    fm.setFocus(a)
    fm.nextFocus(root)
    check fm.getFocusedWidget() == deep
    check fm.activeGroup == inner

  test "Tab out of a deeply nested group leaves one level at a time":
    let deep = stop("deep")
    let inner = group(deep)
    let sibling = stop("sibling")
    let outer = group(inner, sibling)
    let a = stop("a")
    let root = plain(a, outer)
    let fm = newFocusManager()

    fm.setFocus(deep)
    fm.nextFocus(root)
    check fm.getFocusedWidget() == sibling   # left inner, still in outer
    fm.nextFocus(root)
    check fm.getFocusedWidget() == a         # left outer too

suite "the widgets that are groups":

  test "a ToolBar is one Tab stop however many buttons it holds":
    # The motivating case: a strip of twelve tool buttons that costs twelve Tab
    # presses to get past is why focus groups exist.
    let before = stop("before")
    let bar = newToolBar()
    for i in 1 .. 12:
      bar.addChild(newToolButton(text = "t" & $i))
    let after = stop("after")
    let root = plain(before, Widget(bar), after)
    let fm = newFocusManager()

    check bar.isGroup
    check focusEntries(root) == @[before, Widget(bar), after]

    fm.setFocus(before)
    fm.nextFocus(root)
    check fm.getFocusedWidget() == Widget(bar.children[0])
    fm.nextFocus(root)
    check fm.getFocusedWidget() == after

  test "and arrows move along it":
    let bar = newToolBar()
    for i in 1 .. 3:
      bar.addChild(newToolButton(text = "t" & $i))
    discard plain(Widget(bar))
    let fm = newFocusManager()

    fm.setFocus(Widget(bar.children[0]))
    check fm.activeGroup == Widget(bar)
    check fm.moveWithinGroup(1)
    check fm.getFocusedWidget() == Widget(bar.children[1])

  test "a RadioGroup is deliberately not a focus group":
    # It draws its own options rather than owning child widgets, so there is
    # nothing for group navigation to move between. Its Up/Down handling is
    # internal and reaches it because the focused widget gets first refusal.
    let rg = newRadioGroup(options = @["a", "b", "c"])
    check rg.focusable
    check not rg.focusGroup
    check focusEntries(Widget(rg)).len == 0
