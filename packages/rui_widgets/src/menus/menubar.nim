## MenuBar Widget - RUI2
##
## A horizontal strip of menu titles (File, Edit, View...). Each child is a Menu
## whose `title` the bar draws and whose dropdown it positions underneath.
##
## The Menu type is written `menu.Menu` throughout: naylib's `KeyboardKey` has a
## `Menu` field, and rui_core has to re-export that enum for `event.key` to be
## usable, so the bare name is ambiguous wherever both are in scope. Exporting an
## enum type in Nim exposes its fields unqualified, so this one cannot be fixed
## by trimming the re-export -- only by renaming the widget.
##
## The bar's own bounds have to cover the open dropdown: renderPass composites a
## child into the parent's render texture, which is sized to the parent's
## bounds, so a dropdown taller than the strip would be cut off at the strip's
## bottom edge.

import rui_core
import rui_drawing
import menuitem   # re-exported for convenience: a bar is useless without items
import menu
import std/options

export menu, menuitem

const TitlePadding = 12.0'f32

type TitleSlot = tuple[index: int, x, width: float32]

proc titleSlots(children: seq[Widget], startX: float32): seq[TitleSlot] =
  ## Where each Menu child's title sits in the strip. Layout, hit-testing and
  ## painting all need the same answer, so they all ask this.
  let style = TextStyle(fontFamily: "", fontSize: 14.0, color: BLACK,
                        bold: false, italic: false, underline: false)
  var x = startX
  for i, child in children:
    if not (child of menu.Menu):
      continue
    let w = measureText(menu.Menu(child).title, style).width + TitlePadding * 2
    result.add((index: i, x: x, width: w))
    x += w

proc slotAt(slots: seq[TitleSlot], mouseX: float32): int =
  ## Index of the Menu child whose title contains `mouseX`, or -1.
  for slot in slots:
    if mouseX >= slot.x and mouseX < slot.x + slot.width:
      return slot.index
  -1

definePrimitive(MenuBar):
  props:
    barHeight: float32 = 28.0
    intent: ThemeIntent = Default

  state:
    activeMenuIndex: int         # Open menu, -1 for none
    hoverIndex: int

  actions:
    onMenuOpen(index: int)
    onMenuClose()

  init:
    # Dropdowns must paint over whatever follows them in the child list.
    widget.hasOverlay = true
    widget.activeMenuIndex = -1
    widget.hoverIndex = -1

  events:
    on_mouse_down:
      if event.mousePos.y > widget.bounds.y + widget.barHeight:
        return false   # inside an open dropdown; the MenuItem handles it

      let hit = titleSlots(widget.children, widget.bounds.x).slotAt(event.mousePos.x)
      if hit < 0:
        return false

      # Clicking the open menu closes it; clicking another switches to it.
      let opening = widget.activeMenuIndex != hit
      for j, other in widget.children:
        if other of menu.Menu:
          if j == hit and opening: menu.Menu(other).open()
          else: menu.Menu(other).close()

      if opening:
        widget.activeMenuIndex = hit
        if widget.onMenuOpen.isSome:
          widget.onMenuOpen.get()(hit)
      else:
        widget.activeMenuIndex = -1
        if widget.onMenuClose.isSome:
          widget.onMenuClose.get()()

      widget.isDirty = true
      widget.layoutDirty = true
      return true

    on_mouse_move:
      let newHover =
        if event.mousePos.y <= widget.bounds.y + widget.barHeight:
          titleSlots(widget.children, widget.bounds.x).slotAt(event.mousePos.x)
        else:
          -1
      if newHover != widget.hoverIndex:
        widget.hoverIndex = newHover
        widget.isDirty = true
      return false

  layout:
    let slots = titleSlots(widget.children, widget.bounds.x)
    var dropdownBottom = widget.bounds.y + widget.barHeight
    var stripRight = widget.bounds.x

    for slot in slots:
      let child = widget.children[slot.index]
      # The dropdown hangs off the left edge of its title.
      child.bounds.x = slot.x
      child.bounds.y = widget.bounds.y + widget.barHeight
      child.bounds.width = 0        # Menu sizes itself to its widest item
      child.bounds.height = 0
      child.layout()

      if slot.index == widget.activeMenuIndex:
        dropdownBottom = max(dropdownBottom, child.bounds.y + child.bounds.height)
      stripRight = slot.x + slot.width

    if widget.bounds.width <= 0:
      widget.bounds.width = stripRight - widget.bounds.x
    # Grow to cover whatever dropdown is open, or the strip alone when none is.
    widget.bounds.height = dropdownBottom - widget.bounds.y

  render:
    # Dropdown panels and their items are composited by renderPass.
    let barProps = currentTheme.getThemeProps(widget.intent, Normal)
    let barRect = Rect(x: widget.bounds.x, y: widget.bounds.y,
                       width: widget.bounds.width, height: widget.barHeight)
    drawThemedBackground(barRect, barProps)

    let borderColor = barProps.borderColor.get(Color(r: 180, g: 180, b: 180, a: 255))
    drawLine(barRect.x, barRect.y + widget.barHeight,
             barRect.x + barRect.width, barRect.y + widget.barHeight, borderColor)

    for slot in titleSlots(widget.children, widget.bounds.x):
      let state = if slot.index == widget.activeMenuIndex: Selected
                  elif slot.index == widget.hoverIndex: Hovered
                  else: Normal
      let props = currentTheme.getThemeProps(widget.intent, state)
      let titleRect = Rect(x: slot.x, y: widget.bounds.y,
                           width: slot.width, height: widget.barHeight)

      if state != Normal:
        drawThemedBackground(titleRect, props, hovered = state == Hovered)
      drawThemedCenteredText(menu.Menu(widget.children[slot.index]).title, titleRect, props)
