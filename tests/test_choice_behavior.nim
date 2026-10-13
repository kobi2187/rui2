## "Pick one of N" widgets share their keyboard (rui_widgets/choice.nim): the
## arrows along their axis, Home and End, and nothing at an end.

import std/unittest
import rui
import ui_harness
from raylib import KeyboardKey, Left, Right, Up, Down, Home, End
import ../packages/rui_widgets/src/choice

suite "choiceKey":
  test "along the axis, to the ends, and not past them":
    check choiceKey(Right, 3, 0, vertical = false) == (true, 1)
    check choiceKey(Left, 3, 1, vertical = false) == (true, 0)
    check choiceKey(Down, 3, 0, vertical = true) == (true, 1)
    check choiceKey(Home, 3, 2, vertical = false) == (true, 0)
    check choiceKey(End, 3, 0, vertical = true) == (true, 2)
    check not choiceKey(Left, 3, 0, vertical = false).handled
    check not choiceKey(Right, 3, 2, vertical = false).handled
    check not choiceKey(Up, 3, 0, vertical = true).handled
  test "the other axis and an empty list are not its keys":
    check not choiceKey(Up, 3, 1, vertical = false).handled
    check not choiceKey(Left, 3, 1, vertical = true).handled
    check not choiceKey(Right, 0, 0, vertical = false).handled

type Chooser = object
  name: string
  vertical: bool
  make: proc(): Widget
  selected: proc(w: Widget): int

let choosers = @[
  Chooser(name: "SegmentedControl", vertical: false,
    make: proc(): Widget = newSegmentedControl(options = @["a", "b", "c"]),
    selected: proc(w: Widget): int = SegmentedControl(w).selectedIndex),
  Chooser(name: "RadioGroup", vertical: true,
    make: proc(): Widget = newRadioGroup(options = @["a", "b", "c"]),
    selected: proc(w: Widget): int = RadioGroup(w).selectedIndex),
  Chooser(name: "TabControl", vertical: false,
    make: proc(): Widget = newTabControl(tabs = @["a", "b", "c"]),
    selected: proc(w: Widget): int = TabControl(w).activeTab),
]

suite "every pick-one widget answers the same keys":
  for c in choosers:
    let ch = c
    let fwd = if ch.vertical: KeyboardKey.Down else: KeyboardKey.Right
    let back = if ch.vertical: KeyboardKey.Up else: KeyboardKey.Left
    let across = if ch.vertical: KeyboardKey.Right else: KeyboardKey.Down

    test ch.name & ": forward and back along its axis":
      let w = ch.make()
      let r = newRig(stack(w))
      r.focus(w)
      r.key(fwd); check ch.selected(w) == 1
      r.key(fwd); check ch.selected(w) == 2
      r.key(back); check ch.selected(w) == 1
    test ch.name & ": Home and End":
      let w = ch.make()
      let r = newRig(stack(w))
      r.focus(w)
      r.key(End); check ch.selected(w) == 2
      r.key(Home); check ch.selected(w) == 0
    test ch.name & ": the other axis and the ends leave it where it is":
      let w = ch.make()
      let r = newRig(stack(w))
      r.focus(w)
      r.key(across); check ch.selected(w) == 0
      r.key(back); check ch.selected(w) == 0
    test ch.name & ": without focus the keys do nothing":
      let w = ch.make()
      let r = newRig(stack(w))
      r.key(fwd)
      check ch.selected(w) == 0
