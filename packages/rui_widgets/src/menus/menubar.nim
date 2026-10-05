## MenuBar Widget - RUI2
##
## A horizontal strip of menu titles (File, Edit, View...). Each child is a Menu
## whose `title` the bar draws and whose dropdown it positions underneath.
##
## The bar's own bounds have to cover the open dropdown: renderPass composites a
## child into the parent's render texture, which is sized to the parent's
## bounds, so a dropdown taller than the strip would be cut off at the strip's
## bottom edge.

import rui_core
import rui_drawing
import menuitem   # re-exported for convenience: a bar is useless without items
import menu
import std/[options, strutils]
from raylib import KeyboardKey

export menu, menuitem

template barHeightOf(w: untyped): float32 =
  ## Bar height: the prop, else the theme's.
  themedSize(w.barHeight, currentTheme.barHeight(28.0))

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

proc menuIndices(children: seq[Widget]): seq[int] =
  ## The child indices that are menus, in order.
  for i, c in children:
    if c of menu.Menu: result.add i

proc adjacentMenu(children: seq[Widget], current, direction: int): int =
  ## The menu after (or before) `current`, wrapping round.
  let menus = menuIndices(children)
  if menus.len == 0: return -1
  let at = menus.find(current)
  if at < 0: return menus[0]
  menus[(at + direction + menus.len) mod menus.len]

template closeAll(widget: untyped) =
  ## Close whatever menu is open.
  for c in widget.children:
    if c of menu.Menu and menu.Menu(c).isOpen:
      highlightItem(c.children, -1)
      menu.Menu(c).close()
      closedPopup(c)
  if widget.activeMenuIndex >= 0:
    widget.activeMenuIndex = -1
    widget.isDirty = true
    widget.layoutDirty = true
    if widget.onMenuClose != nil:
      widget.onMenuClose()

template openMenuAt(widget: untyped, index: int, fromKeyboard: bool) =
  ## Open menu `index` (closing any other). From the keyboard its first
  ## item is highlighted and the bar takes focus.
  block:
    let bar = widget
    for j, other in bar.children:
      if other of menu.Menu and j != index and menu.Menu(other).isOpen:
        highlightItem(other.children, -1)
        menu.Menu(other).close()
        closedPopup(other)
    let m = menu.Menu(bar.children[index])
    m.open()
    m.selectedIndex = if fromKeyboard: m.children.stepItem(-1, 1) else: -1
    highlightItem(m.children, m.selectedIndex)
    openPopup(m, scope = bar, close = proc() = bar.closeAll())
    if fromKeyboard: wantFocus(bar)     # the bar takes the keys, not the panel
    bar.keyTitle = index
    if bar.activeMenuIndex != index:
      bar.activeMenuIndex = index
      if bar.onMenuOpen != nil:
        bar.onMenuOpen(index)
    bar.isDirty = true
    bar.layoutDirty = true

definePrimitive(MenuBar):
  props:
    barHeight: float32 = 0.0   # 0: from the theme
    intent: ThemeIntent = Default

  state:
    activeMenuIndex: int         # Open menu, -1 for none
    hoverIndex: int
    keyTitle: int                # the keyboard's title while no menu is open

  actions:
    onMenuOpen(index: int)
    onMenuClose()

  init:
    # Dropdowns must paint over whatever follows them in the child list.
    widget.hasOverlay = true
    widget.activeMenuIndex = -1
    widget.hoverIndex = -1
    widget.keyTitle = -1
    widget.focusable = true

  events:
    on_mouse_down:
      if event.mousePos.y > widget.bounds.y + barHeightOf(widget):
        return false   # inside an open dropdown; the MenuItem handles it

      let hit = titleSlots(widget.children, widget.bounds.x).slotAt(event.mousePos.x)
      if hit < 0:
        return false

      # Clicking the open menu closes it; clicking another switches to it.
      if widget.activeMenuIndex == hit:
        widget.closeAll()
      else:
        widget.openMenuAt(hit, fromKeyboard = false)
      return true

    on_mouse_move:
      let newHover =
        if event.mousePos.y <= widget.bounds.y + barHeightOf(widget):
          titleSlots(widget.children, widget.bounds.x).slotAt(event.mousePos.x)
        else:
          -1
      if newHover != widget.hoverIndex:
        widget.hoverIndex = newHover
        widget.isDirty = true
      return false

    on_key_down:
      # With a menu open: Left/Right to the next menu, the menu's own keys
      # (Up/Down, Enter, a letter), Escape to close it. With none open:
      # Left/Right pick a title, Down/Enter/Space open it, Escape leaves.
      if not widget.focused:
        return false
      let open = widget.activeMenuIndex
      if open >= 0:
        case event.key
        of KeyboardKey.Left, KeyboardKey.Right:
          let next = widget.children.adjacentMenu(open,
                       if event.key == KeyboardKey.Right: 1 else: -1)
          if next >= 0: widget.openMenuAt(next, fromKeyboard = true)
          return true
        of KeyboardKey.Escape:
          widget.closeAll()
          return true
        else:
          let m = menu.Menu(widget.children[open])
          var current = m.selectedIndex
          result = menuKey(m.children, current, event)
          if widget.activeMenuIndex >= 0:      # still open: the item did not close it
            m.selectedIndex = current
          widget.isDirty = true
          return result
      case event.key
      of KeyboardKey.Left, KeyboardKey.Right:
        widget.keyTitle = widget.children.adjacentMenu(widget.keyTitle,
                            if event.key == KeyboardKey.Right: 1 else: -1)
        widget.isDirty = true
        return true
      of KeyboardKey.Down, KeyboardKey.Enter, KeyboardKey.KpEnter, KeyboardKey.Space:
        let t = if widget.keyTitle >= 0: widget.keyTitle
                else: widget.children.adjacentMenu(-1, 1)
        if t < 0: return false
        widget.openMenuAt(t, fromKeyboard = true)
        return true
      else:
        return false

  layout:
    # A menu closed by choosing one of its items leaves the bar to notice.
    if widget.activeMenuIndex >= 0 and
       not menu.Menu(widget.children[widget.activeMenuIndex]).isOpen:
      widget.activeMenuIndex = -1
    let slots = titleSlots(widget.children, widget.bounds.x)
    var dropdownBottom = widget.bounds.y + barHeightOf(widget)
    var stripRight = widget.bounds.x

    for slot in slots:
      let child = widget.children[slot.index]
      # The dropdown hangs off the left edge of its title.
      child.bounds.x = slot.x
      child.bounds.y = widget.bounds.y + barHeightOf(widget)
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
                       width: widget.bounds.width, height: barHeightOf(widget))
    drawThemedBackground(barRect, barProps)

    let borderColor = barProps.borderColor.get(Color(r: 180, g: 180, b: 180, a: 255))
    drawLine(barRect.x, barRect.y + barHeightOf(widget),
             barRect.x + barRect.width, barRect.y + barHeightOf(widget), borderColor)

    for slot in titleSlots(widget.children, widget.bounds.x):
      let state = if slot.index == widget.activeMenuIndex: Selected
                  elif slot.index == widget.hoverIndex or
                       (widget.focused and slot.index == widget.keyTitle): Hovered
                  else: Normal
      let props = currentTheme.getThemeProps(widget.intent, state)
      let titleRect = Rect(x: slot.x, y: widget.bounds.y,
                           width: slot.width, height: barHeightOf(widget))

      if state != Normal:
        drawThemedBackground(titleRect, props, hovered = state == Hovered)
      drawThemedCenteredText(menu.Menu(widget.children[slot.index]).title, titleRect, props)

proc openFromKeyboard*(bar: MenuBar, letter = '\0'): bool =
  ## F10 (no letter) opens the first menu; Alt+letter the menu whose title
  ## starts with it. The bar takes focus. False when there is no such menu.
  var index = -1
  for i in menuIndices(bar.children):
    let title = menu.Menu(bar.children[i]).title
    if letter == '\0' or (title.len > 0 and title[0].toLowerAscii == letter.toLowerAscii):
      index = i
      break
  if index < 0:
    return false
  bar.openMenuAt(index, fromKeyboard = true)
  true

proc findMenuBar*(root: Widget): MenuBar =
  ## The first visible MenuBar under `root`, or nil.
  if root == nil or not root.visible: return nil
  if root of MenuBar: return MenuBar(root)
  for c in root.children:
    let found = findMenuBar(c)
    if found != nil: return found
