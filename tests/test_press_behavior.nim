## Everything button-like presses the same way (rui_widgets/press.nim). One set of
## gestures, run against each widget through a small adapter: how to make it, and
## how many times it has "done its thing".

import std/unittest
import rui
import ui_harness
from raylib import KeyboardKey, Space, Enter

type Subject = object
  name: string
  make: proc(): Widget
  effects: proc(w: Widget): int       ## how many times its action ran
  disable: proc(w: Widget)

var counts: int


let subjects = @[
  Subject(name: "Button",
    make: proc(): Widget =
      let b = newButton(text = "Go"); counts = 0
      b.onClick = proc() = inc counts
      b,
    effects: proc(w: Widget): int = counts,
    disable: proc(w: Widget) = Button(w).disabled = true),
  Subject(name: "ToolButton",
    make: proc(): Widget =
      let b = newToolButton(iconText = "B"); counts = 0
      b.onClick = proc() = inc counts
      b,
    effects: proc(w: Widget): int = counts,
    disable: proc(w: Widget) = ToolButton(w).disabled = true),
  Subject(name: "IconButton",
    make: proc(): Widget =
      let b = newIconButton(iconText = "+"); counts = 0
      b.onClick = proc() = inc counts
      b,
    effects: proc(w: Widget): int = counts,
    disable: proc(w: Widget) = IconButton(w).disabled = true),
  Subject(name: "Checkbox",
    make: proc(): Widget =
      let b = newCheckbox(text = "x"); counts = 0
      b.onToggle = proc(v: bool) = inc counts
      b,
    effects: proc(w: Widget): int = counts,
    disable: proc(w: Widget) = Checkbox(w).disabled = true),
  Subject(name: "Switch",
    make: proc(): Widget =
      let b = newSwitch(text = "x"); counts = 0
      b.onToggle = proc(v: bool) = inc counts
      b,
    effects: proc(w: Widget): int = counts,
    disable: proc(w: Widget) = Switch(w).disabled = true),
  Subject(name: "Hyperlink",
    make: proc(): Widget =
      let b = newHyperlink(text = "link", url = "x"); counts = 0
      b.onClick = proc() = inc counts
      b,
    effects: proc(w: Widget): int = counts,
    disable: proc(w: Widget) = Hyperlink(w).disabled = true),
  Subject(name: "RadioButton",
    make: proc(): Widget =
      let b = newRadioButton(text = "x", value = "a", selectedValue = ""); counts = 0
      b.onChange = proc(v: string) = inc counts
      b,
    effects: proc(w: Widget): int = counts,
    disable: proc(w: Widget) = RadioButton(w).disabled = true),
  Subject(name: "Expander",
    make: proc(): Widget =
      let b = newExpander(title = "More"); counts = 0
      b.onToggle = proc(v: bool) = inc counts
      b,
    effects: proc(w: Widget): int = counts,
    disable: proc(w: Widget) = Expander(w).disabled = true),
  Subject(name: "Crumb",
    make: proc(): Widget =
      let b = newCrumb(text = "docs"); counts = 0
      b.onClick = proc() = inc counts
      b,
    effects: proc(w: Widget): int = counts,
    disable: proc(w: Widget) = Crumb(w).disabled = true),
  Subject(name: "SidePane",
    make: proc(): Widget =
      let b = newSidePane(title = "Chosen", width = 200); counts = 0
      b.onToggle = proc(v: bool) = inc counts
      b,
    effects: proc(w: Widget): int = counts,
    disable: proc(w: Widget) = SidePane(w).disabled = true),
]

proc target(w: Widget): Point =
  ## Where to press: the middle, except an Expander, whose header is the top.
  if w.getTypeName() in ["Expander", "SidePane"]: Point(x: w.bounds.x + 10, y: w.bounds.y + 8)
  else: centre(w)

suite "every button-like widget presses the same way":
  for s in subjects:
    let sub = s

    proc rig(): (Rig, Widget) =
      let w = sub.make()
      (newRig(stack(w)), w)

    test sub.name & ": press arms it, release over it activates once and disarms":
      let (r, w) = rig()
      let p = target(w)
      r.press(p.x, p.y)
      check w.isPressed
      check sub.effects(w) == 0
      r.release(p.x, p.y)
      check not w.isPressed
      check sub.effects(w) == 1

    test sub.name & ": released outside: nothing happens and it is not left armed":
      let (r, w) = rig()
      let p = target(w)
      r.press(p.x, p.y)
      r.release(390, 290)
      check not w.isPressed
      check sub.effects(w) == 0
      check pointerCapture() == nil

    test sub.name & ": dragging off disarms, coming back re-arms and the release activates":
      let (r, w) = rig()
      let p = target(w)
      r.press(p.x, p.y)
      r.moveTo(390, 290)
      check not w.isPressed
      r.moveTo(p.x, p.y)
      check w.isPressed
      r.release(p.x, p.y)
      check sub.effects(w) == 1

    test sub.name & ": hover follows the pointer in and out":
      let (r, w) = rig()
      r.moveTo(target(w))
      check w.under
      r.moveTo(390, 290)
      check not w.under

    test sub.name & ": Space and Enter activate it when focused, not otherwise":
      let (r, w) = rig()
      r.key(Space)
      check sub.effects(w) == 0
      r.focus(w)
      r.key(Space)
      r.key(Enter)
      check sub.effects(w) == 2

    test sub.name & ": disabled ignores the pointer and the keyboard":
      let (r, w) = rig()
      sub.disable(w)
      let p = target(w)
      r.click(p.x, p.y)
      r.focus(w)
      r.key(Space)
      check sub.effects(w) == 0
      check not w.isPressed
