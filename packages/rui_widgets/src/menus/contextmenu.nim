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
      for child in widget.children:
        child.visible = false
      widget.bounds.width = 0
      widget.bounds.height = 0
      return

    widget.bounds.x = widget.posX
    widget.bounds.y = widget.posY

    var y = widget.bounds.y + widget.padding
    var widest = widget.minWidth - widget.padding * 2

    # Pass 1: measure. Pass 2 squares every item off to the widest one.
    for child in widget.children:
      child.visible = true
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = y
      child.bounds.width = 0
      child.bounds.height = 0
      child.layout()
      widest = max(widest, child.bounds.width)
      y += child.bounds.height

    widget.bounds.width = widest + widget.padding * 2
    widget.bounds.height = (y - widget.bounds.y) + widget.padding

    for child in widget.children:
      child.bounds.width = widest
      child.layout()

  render:
    # Items are composited by renderPass; only the panel is drawn here.
    if not widget.isVisible:
      return
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    drawShadow(widget.bounds, Shadow(offsetX: 2.0, offsetY: 2.0,
                                     blur: 0.0, spread: 0.0,
                                     color: Color(r: 0, g: 0, b: 0, a: 50)))
    drawThemedBackground(widget.bounds, props)
    drawThemedBorder(widget.bounds, props)

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
  showOverlay(widget, interactive = true)
  widget.isDirty = true
  widget.layoutDirty = true
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
  hideOverlay(widget)
  widget.isDirty = true
  widget.layoutDirty = true
  if widget.onClose != nil:
    widget.onClose()
