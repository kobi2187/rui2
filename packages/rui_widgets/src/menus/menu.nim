## Menu Widget - RUI2
##
## A dropdown panel holding MenuItem children. Used as a MenuBar drop-down or
## on its own. `title` is what a MenuBar shows in its strip; the Menu itself
## only draws the panel.
##
## While closed the menu occupies no space and its children are hidden, so the
## widgets underneath stay clickable.

import rui_core
import menu_panel
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

  init:
    widget.floating = true       # drawn above everything, on the overlay layer

  layout:
    if not widget.isOpen:
      widget.collapseMenuPanel()
      return
    widget.layoutMenuColumn(widget.padding, widget.minWidth)

  render:
    # Items are composited by renderPass; only the panel is drawn here.
    if widget.isOpen:
      widget.drawMenuPanel(widget.intent)

proc open*(widget: Menu) =
  ## Show the dropdown. Opening changes the menu's size, so layout has to re-run.
  if widget.isOpen:
    return
  widget.isOpen = true
  widget.showMenuLayer()
  if widget.onOpen != nil:
    widget.onOpen()

proc close*(widget: Menu) =
  ## Hide the dropdown.
  if not widget.isOpen:
    return
  widget.isOpen = false
  widget.hideMenuLayer()
  if widget.onClose != nil:
    widget.onClose()
