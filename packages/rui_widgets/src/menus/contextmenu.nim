## ContextMenu Widget - RUI2
##
## A popup menu that appears where it is told to, normally on right-click.
## Holds MenuItem children stacked vertically.
##
## Call `openAt(x, y)` to show it and `close()` to dismiss it. While hidden it
## takes up no space, so it never blocks clicks on what is underneath.

import rui_core
import rui_drawing
import menuitem
import menu_panel
import std/options
from raylib import KeyboardKey

export menuitem

defineWidget(ContextMenu):
  props:
    itemHeight: float32 = 24.0
    minWidth: float32 = 150.0
    padding: float32 = 4.0
    intent: ThemeIntent = Default

  state:
    isVisible: bool
    posX: float32
    posY: float32
    current: int                 # the keyboard's item

  actions:
    onOpen(x: float32, y: float32)
    onClose()

  init:
    widget.floating = true       # drawn above everything, on the overlay layer

  events:
    on_key_down:
      # Open, it has the keyboard: Up/Down, Enter, a letter; Escape closes.
      if not widget.isVisible:
        return false
      if event.key == KeyboardKey.Escape:
        closePopupOf(widget)       # its close proc (declared after the type)
        return true
      var current = widget.current
      result = menuKey(widget.children, current, event)
      widget.current = current

  layout:
    if not widget.isVisible:
      widget.collapseMenuPanel()
      return
    widget.bounds.x = widget.posX
    widget.bounds.y = widget.posY
    widget.layoutMenuColumn(widget.padding, widget.minWidth)

  render:
    if widget.isVisible:
      widget.drawMenuPanel(widget.intent)

proc close*(widget: ContextMenu)

proc openAt*(widget: ContextMenu, x, y: float32) =
  ## Pop the menu up with its top-left corner at (x, y). It takes the
  ## keyboard, and a click anywhere else closes it.
  widget.posX = x
  widget.posY = y
  widget.isVisible = true
  widget.focusable = true
  widget.current = -1
  highlightItem(widget.children, -1)
  openPopup(widget, scope = widget, close = proc() = widget.close(), takeFocus = true)
  widget.showMenuLayer()
  if widget.onOpen != nil:
    widget.onOpen(x, y)

proc close*(widget: ContextMenu) =
  ## Dismiss the menu.
  if not widget.isVisible:
    return
  widget.isVisible = false
  widget.focusable = false
  highlightItem(widget.children, -1)
  closedPopup(widget)
  widget.hideMenuLayer()
  if widget.onClose != nil:
    widget.onClose()
