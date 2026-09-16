## Menu Widget - RUI2
##
## A dropdown panel holding MenuItem children. Used as a MenuBar drop-down or
## on its own. `title` is what a MenuBar shows in its strip; the Menu itself
## only draws the panel.
##
## While closed the menu occupies no space and its children are hidden, so the
## widgets underneath stay clickable.

import rui_core
import rui_drawing
import std/options

defineWidget(Menu):
  props:
    title: string = ""           # Shown by a parent MenuBar, not by the Menu
    itemHeight: float32 = 24.0
    minWidth: float32 = 150.0
    padding: float32 = 4.0
    intent: ThemeIntent = Default

  state:
    isOpen: bool
    selectedIndex: int

  actions:
    onOpen()
    onClose()

  layout:
    if not widget.isOpen:
      # Collapsed: no bounds, no visible children, nothing to hit-test.
      for child in widget.children:
        child.visible = false
      widget.bounds.width = 0
      widget.bounds.height = 0
      return

    var y = widget.bounds.y + widget.padding
    var widest = widget.minWidth - widget.padding * 2

    # Pass 1: let each item measure itself so the panel can size to the widest.
    for child in widget.children:
      child.visible = true
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = y
      child.bounds.width = 0        # 0 = measure yourself
      child.bounds.height = 0
      child.layout()
      widest = max(widest, child.bounds.width)
      y += child.bounds.height

    widget.bounds.width = widest + widget.padding * 2
    widget.bounds.height = (y - widget.bounds.y) + widget.padding

    # Pass 2: square every item off to the panel width.
    for child in widget.children:
      child.bounds.width = widest
      child.layout()

  render:
    # Items are composited by renderPass; only the panel is drawn here.
    if not widget.isOpen:
      return
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    drawThemedBackground(widget.bounds, props)
    drawThemedBorder(widget.bounds, props)

proc open*(widget: Menu) =
  ## Show the dropdown. Opening changes the menu's size, so layout has to re-run.
  if widget.isOpen:
    return
  widget.isOpen = true
  widget.isDirty = true
  widget.layoutDirty = true
  if widget.onOpen != nil:
    widget.onOpen()

proc close*(widget: Menu) =
  ## Hide the dropdown.
  if not widget.isOpen:
    return
  widget.isOpen = false
  widget.isDirty = true
  widget.layoutDirty = true
  if widget.onClose != nil:
    widget.onClose()
