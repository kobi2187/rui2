## Popups: menus and dropdowns that close when you click elsewhere.
##
## An open popup registers here with the part of the tree that counts as
## "inside" it -- a menu bar's dropdown counts the bar too, so a click on
## another title switches menus rather than closing and reopening. A press
## anywhere outside every open popup's scope closes them (the App asks before
## routing the press). A popup that wants the keyboard -- a context menu,
## opened by a right-click while focus was elsewhere -- asks for focus, and the
## App hands it over at the next frame: widgets have no focus manager.

import types
import overlays   # isWithin

type Popup = object
  widget, scope: Widget
  close: proc() {.closure.}

var
  open: seq[Popup]
  focusWanted: Widget

proc openPopup*(widget, scope: Widget, close: proc() {.closure.},
                takeFocus = false) =
  ## Record `widget` as open. `close` is how to shut it; `scope` is what a
  ## click may land on without closing it (`widget` itself when nil).
  for p in open:
    if p.widget == widget: return
  open.add Popup(widget: widget, scope: (if scope != nil: scope else: widget),
                 close: close)
  if takeFocus:
    focusWanted = widget

proc closedPopup*(widget: Widget) =
  ## Forget `widget`: it has closed itself.
  for i in countdown(open.high, 0):
    if open[i].widget == widget:
      open.delete(i)

proc closePopupOf*(inside: Widget) =
  ## Close the popup that `inside` sits in -- what choosing a menu item does.
  for i in countdown(open.high, 0):
    if inside.isWithin(open[i].widget):
      let p = open[i]
      open.delete(i)
      p.close()
      return

proc dismissPopupsOutside*(target: Widget): bool =
  ## A press landed on `target`: close every popup it is not inside. Returns
  ## whether any closed.
  for i in countdown(open.high, 0):
    if i <= open.high and (target == nil or not target.isWithin(open[i].scope)):
      let p = open[i]
      open.delete(i)
      p.close()
      result = true

proc wantFocus*(widget: Widget) =
  ## Ask for `widget` to have the keyboard at the next frame.
  focusWanted = widget

proc anyPopupOpen*(): bool = open.len > 0

proc takeFocusRequest*(): Widget =
  ## The widget that asked for focus, once; nil when none did.
  result = focusWanted
  focusWanted = nil

proc clearPopups*() =
  ## Forget them all (tests, or a tree replaced wholesale).
  open.setLen(0)
  focusWanted = nil
