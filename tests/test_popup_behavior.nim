## Fields with a popup (ComboBox, DatePicker, ColorPicker) open, close and dismiss
## the same way (input/popup_field.nim).

import std/[unittest, options, sequtils]
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

suite "a list popup longer than the window is cut to fit, and scrolls":
  test "popupRect: below, flipped above, or with shrink cut to the roomier side":
    renderView = some(Rect(x: 0, y: 0, width: 400, height: 300))
    defer: renderView = none(Rect)
    let field = Rect(x: 10, y: 40, width: 100, height: 30)
    check popupRect(field, 100, 100).y == 70                    # fits below
    check popupRect(field, 100, 400).height == 400              # no shrink: as asked
    let cut = popupRect(field, 100, 400, shrink = true)
    check cut.y == 70 and cut.height == 230                     # the rest of the window
    let low = Rect(x: 10, y: 250, width: 100, height: 30)
    check popupRect(low, 100, 200).y == 50                      # flipped above
    let up = popupRect(low, 100, 400, shrink = true)
    check up.y == 0 and up.height == 250                        # above has more room

  let many = toSeq(0 ..< 40).mapIt("item " & $it)

  test "ComboBox: the list stays in the window; End, the wheel and a click reach far rows":
    clearOverlays()
    renderView = some(Rect(x: 0, y: 0, width: 400, height: 300))
    defer: renderView = none(Rect)
    var chosen = -1
    let c = newComboBox(items = many, onSelect = proc(i: int) = chosen = i)
    let r = newRig(stack(c.frame(width = 200)))
    r.click(c)
    check c.isOpen
    let list = c.list
    check list.bounds.y + list.bounds.height <= 300
    check list.bounds.height < 40 * list.itemHeight
    r.key(KeyboardKey.End)                                      # the highlight goes last...
    check c.hoverIndex == 39
    check list.viewport.isRowVisible(39)                        # ...and the list follows
    r.key(KeyboardKey.Home)
    check list.scrollY == 0
    r.wheel(list.bounds.x + 20, list.bounds.y + 20, -1)         # scroll down a notch
    check list.scrollY > 0
    let first = list.viewport.rowAt(list.bounds.y + 1, 40)
    check first > 0
    r.click(list.bounds.x + 20, list.bounds.y + list.itemHeight / 2)
    check chosen == first                                       # the row shown, not row 0
    check not c.isOpen

  test "ComboBox: opening shows the current choice, however far down":
    clearOverlays()
    renderView = some(Rect(x: 0, y: 0, width: 400, height: 300))
    defer: renderView = none(Rect)
    let c = newComboBox(items = many, initialSelectedIndex = 33)
    let r = newRig(stack(c.frame(width = 200)))
    r.click(c)
    check c.list.viewport.isRowVisible(33)

  test "Autocomplete: the same list, cut to fit, follows Down":
    clearOverlays()
    renderView = some(Rect(x: 0, y: 0, width: 400, height: 300))
    defer: renderView = none(Rect)
    let a = newAutocomplete(suggestions = many, maxShown = 40)
    let r = newRig(stack(a.frame(width = 200)))
    r.focus(a.input)
    r.typeText("item")
    check a.isOpen
    check a.list.bounds.y + a.list.bounds.height <= 300
    for i in 0 ..< 25: r.key(KeyboardKey.Down)
    check a.hoverIndex == 24
    check a.list.viewport.isRowVisible(24)
