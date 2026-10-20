## Modals (MessageBox, FileDialog, Dialog) open, hold the pointer and close the
## same way (dialogs/modal.nim): while open they are on their own hit-test layer,
## so the page under them -- however deeply nested -- gets none of its clicks;
## closed, the page has the pointer back.

import std/unittest
import rui
import ui_harness
from raylib import KeyboardKey

type Modal = object
  name: string
  make: proc(): Widget
  show: proc(w: Widget)
  isOpen: proc(w: Widget): bool
  answer: proc(w: Widget): Point   ## where a click closes it

let modals = @[
  Modal(name: "MessageBox",
        make: proc(): Widget = newMessageBox(message = "Sure?", buttons = mbOKCancel),
        show: proc(w: Widget) = MessageBox(w).show(),
        isOpen: proc(w: Widget): bool = MessageBox(w).isVisible,
        answer: proc(w: Widget): Point =
          let m = MessageBox(w)
          let b = dialogButtons(panelRect(m.bounds, m.dialogWidth, m.dialogHeight),
                                m.buttons)[0].rect
          Point(x: b.x + b.width / 2, y: b.y + b.height / 2)),
  Modal(name: "FileDialog",
        make: proc(): Widget = newFileDialog(dialogWidth = 360.0, dialogHeight = 240.0),
        show: proc(w: Widget) = FileDialog(w).show(),
        isOpen: proc(w: Widget): bool = FileDialog(w).isVisible,
        answer: proc(w: Widget): Point =
          let d = FileDialog(w)
          let b = cancelRect(panelRect(d.bounds, d.dialogWidth, d.dialogHeight))
          Point(x: b.x + b.width / 2, y: b.y + b.height / 2)),
  Modal(name: "Dialog",
        make: proc(): Widget =
          let d = newDialog(title = "x", closeOnBackdrop = true)
          d.addChild(newLabel(text = "hello"))
          d,
        show: proc(w: Widget) = Dialog(w).show(),
        isOpen: proc(w: Widget): bool = Dialog(w).isOpen,
        answer: proc(w: Widget): Point = Point(x: 4, y: 4)),   # the backdrop
]

proc page(clicks: ptr int): (Widget, Widget) =
  ## A button nested a few containers deep, covering the middle of the screen
  ## where a dialog's buttons land: deeper than the modal, so preferred by depth.
  let button = newButton(text = "page", onClick = proc() = inc clicks[])
  let inner = newVStack(padding = 0.0)
  inner.addChild(button.frame(width = 380, height = 260))
  let outer = newVStack(padding = 10.0)
  outer.addChild(inner)
  (Widget(outer), Widget(button))

suite "every modal holds the pointer and lets it go the same way":
  for m in modals:
    let md = m
    test md.name & ": the page under it gets no clicks; answering closes it":
      var clicks = 0
      let (body, button) = page(addr clicks)
      let modal = md.make()
      let root = stack(body, modal)
      let r = newRig(root, 400, 300)
      r.click(button)
      check clicks == 1
      md.show(modal)
      r.frame()
      check md.isOpen(modal)
      r.click(button)                       # the button is under the backdrop
      check clicks == 1 and md.isOpen(modal)
      let p = md.answer(modal)
      r.click(p.x, p.y)
      check not md.isOpen(modal)
      r.frame()
      r.click(button)                       # closed: the page is back
      check clicks == 2

    test md.name & ": Escape closes it":
      var clicks = 0
      let (body, button) = page(addr clicks)
      let modal = md.make()
      let r = newRig(stack(body, modal), 400, 300)
      md.show(modal)
      r.frame()
      r.key(KeyboardKey.Escape)
      check not md.isOpen(modal)
      r.frame()
      r.click(button)
      check clicks == 1
