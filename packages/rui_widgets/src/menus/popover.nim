## Popover -- a small panel of anything (text, a form, buttons) that opens
## beside the widget it is about.
##
## ```nim
## var help: Popover
## var helpButton: Button
## ui:
##   helpButton = Button(text = "?", onClick = proc() = help.toggle(helpButton))
##   help = Popover(width = 240):
##     Column(spacing = 6):
##       Label(text = "Your password needs 12 characters.", wrap = true)
##       Button(text = "Got it", onClick = proc() = help.close())
## ```
##
## It lives in the tree where it is declared but takes no room there: open, it
## floats on the overlay layer below the widget it was opened beside (above,
## when the window has no room underneath), with the theme's panel and shadow.
## A click anywhere else, or Escape, closes it -- as a menu does
## (menu_panel.nim, popups.nim). Its content is its child: one widget, laid
## out in the panel.

import rui_core
import rui_drawing
import menu_panel
import ../input/popup_field
import std/options
from raylib import KeyboardKey

defineWidget(Popover):
  props:
    width: float32 = 0.0            ## 0: as wide as its content wants (at most 360)
    padding: float32 = 10.0
    gap: float32 = 6.0              ## between it and the widget it is beside
    intent: ThemeIntent = Default

  state:
    isOpen: bool
    anchor: Widget                  ## what it was opened beside

  actions:
    onOpen()
    onClose()

  init:
    widget.floating = true          # drawn above everything, on the overlay layer

  events:
    on_key_down:
      # Escape bubbles here from a control inside it, or comes to it focused.
      if widget.isOpen and event.key == KeyboardKey.Escape:
        closePopupOf(widget)
        return true
      return false

  layout:
    if not widget.isOpen or widget.anchor == nil:
      widget.collapseMenuPanel()
      return
    let p = widget.padding
    let w = if widget.width > 0: widget.width else: 360'f32
    var size = Size(width: w - 2 * p, height: 0)
    if widget.children.len > 0:
      let child = widget.children[0]
      child.visible = true
      size = child.measure(Constraints(minWidth: (if widget.width > 0: w - 2 * p else: 0),
                                       maxWidth: w - 2 * p, minHeight: 0, maxHeight: Inf))
    let panelW = (if widget.width > 0: w else: size.width + 2 * p)
    let panelH = size.height + 2 * p
    let a = widget.anchor.bounds
    let below = Rect(x: a.x, y: a.y, width: a.width, height: a.height + widget.gap)
    var r = popupRect(below, panelW, panelH)
    if r.y < a.y: r.y -= widget.gap      # flipped above: the gap on that side
    widget.bounds = r
    if widget.children.len > 0:
      widget.children[0].arrange(Rect(x: r.x + p, y: r.y + p, width: panelW - 2 * p,
                                      height: size.height))

  render:
    if widget.isOpen:
      widget.drawMenuPanel(widget.intent)

proc close*(widget: Popover)

proc openBeside*(widget: Popover, anchor: Widget) =
  ## Open it beside `anchor` (below it, or above when there is no room).
  widget.anchor = anchor
  widget.isOpen = true
  openPopup(widget, scope = widget, close = proc() = widget.close(), anchor = anchor)
  widget.showMenuLayer()
  if widget.onOpen != nil: widget.onOpen()

proc close*(widget: Popover) =
  if not widget.isOpen: return
  widget.isOpen = false
  closedPopup(widget)
  widget.hideMenuLayer()
  if widget.onClose != nil: widget.onClose()

proc toggle*(widget: Popover, anchor: Widget) =
  ## Open beside `anchor`, or close it if it is open: what a button does.
  if widget.isOpen: widget.close() else: widget.openBeside(anchor)
