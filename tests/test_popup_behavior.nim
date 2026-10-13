## Fields with a popup (ComboBox, DatePicker, ColorPicker) open, close and dismiss
## the same way (input/popup_field.nim).

import std/unittest
import rui
import ui_harness
from raylib import KeyboardKey
import ../packages/rui_widgets/src/input/popup_field

suite "highlightKey":
  test "clamped to the list, other keys not taken":
    check highlightKey(KeyboardKey.Down, 3, 0) == 1
    check highlightKey(KeyboardKey.Down, 3, 2) == 2
    check highlightKey(KeyboardKey.Up, 3, 0) == 0
    check highlightKey(KeyboardKey.Home, 3, 2) == 0
    check highlightKey(KeyboardKey.End, 3, 0) == 2
    check highlightKey(KeyboardKey.A, 3, 0) == -1
    check highlightKey(KeyboardKey.Down, 0, 0) == -1

type Field = object
  name: string
  make: proc(): Widget
  isOpen: proc(w: Widget): bool
  disable: proc(w: Widget)

let fields = @[
  Field(name: "ComboBox", make: proc(): Widget = newComboBox(items = @["a", "b", "c"]),
        isOpen: proc(w: Widget): bool = ComboBox(w).isOpen,
        disable: proc(w: Widget) = ComboBox(w).disabled = true),
  Field(name: "DatePicker", make: proc(): Widget = newDatePicker(),
        isOpen: proc(w: Widget): bool = DatePicker(w).isOpen,
        disable: proc(w: Widget) = DatePicker(w).disabled = true),
  Field(name: "ColorPicker", make: proc(): Widget = newColorPicker(),
        isOpen: proc(w: Widget): bool = ColorPicker(w).isOpen,
        disable: proc(w: Widget) = ColorPicker(w).disabled = true),
]

suite "every popup field opens and closes the same way":
  for f in fields:
    let fld = f
    proc rig(): (Rig, Widget) =
      clearOverlays()
      let w = fld.make()
      (newRig(stack(w)), w)

    test fld.name & ": click opens it and puts the popup on the overlay layer; click again closes":
      let (r, w) = rig()
      r.click(w)
      check fld.isOpen(w)
      check overlays().len == 1
      r.click(w)
      check not fld.isOpen(w)
      check overlays().len == 0
    test fld.name & ": a click elsewhere closes it":
      let (r, w) = rig()
      r.click(w)
      r.click(395, 295)
      check not fld.isOpen(w)
      check overlays().len == 0
    test fld.name & ": Space, Enter and F4 open and close it; Escape closes it":
      let (r, w) = rig()
      r.focus(w)
      r.key(KeyboardKey.F4)
      check fld.isOpen(w)
      r.key(KeyboardKey.Escape)
      check not fld.isOpen(w)
      r.key(KeyboardKey.Space)
      check fld.isOpen(w)
      r.key(KeyboardKey.Enter)
      check not fld.isOpen(w)
    test fld.name & ": Escape with nothing open is not its key":
      let (r, w) = rig()
      r.focus(w)
      r.key(KeyboardKey.Escape)
      check not fld.isOpen(w)
    test fld.name & ": disabled never opens":
      let (r, w) = rig()
      fld.disable(w)
      r.click(w)
      r.focus(w)
      r.key(KeyboardKey.Space)
      check not fld.isOpen(w)
      check overlays().len == 0
