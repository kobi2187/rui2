## MenuItem Widget - RUI2
##
## A single row in a Menu, MenuBar dropdown or ContextMenu. Carries text, an
## optional icon glyph, an optional shortcut hint, an optional check state, and
## can instead be a separator rule.

import rui_core
import rui_drawing
import std/[options, strutils]
from raylib import KeyboardKey

template rowH(w: untyped): float32 =
  ## This widget's row height: its own prop, else the theme's.
  themedSize(w.itemHeight, currentTheme.rowHeight(24.0))

const
  IconGutter = 20.0'f32
  ShortcutGap = 24.0'f32
  SeparatorHeight = 7.0'f32

template choose*(widget: untyped) =
  ## What picking the item does, by click or by key: toggle it if it is
  ## checkable, run it, and close the menu it is in.
  if widget.checkable:
    widget.checked = not widget.checked
    widget.isDirty = true
    if widget.onToggle != nil:
      widget.onToggle(widget.checked)
  closePopupOf(widget)
  if widget.onClick != nil:
    widget.onClick()

definePrimitive(MenuItem):
  props:
    text: string = ""
    shortcut: string = ""        # e.g. "Ctrl+S", "F5"
    iconText: string = ""        # Text icon (emoji / Unicode glyph)
    checkable: bool = false
    initialChecked: bool = false
    separator: bool = false      # Draw a rule instead of a row
    hasSubmenu: bool = false
    itemHeight: float32 = 0.0   # 0: the theme's row height
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    checked: bool
    highlighted: bool            # the keyboard's item in an open menu

  actions:
    onClick()
    onToggle(checked: bool)

  events:
    on_mouse_down:
      if widget.disabled or widget.separator:
        return false
      widget.choose()
      return true

  layout:
    if widget.bounds.height <= 0:
      widget.bounds.height = if widget.separator: SeparatorHeight
                             else: rowH(widget)
    if widget.bounds.width <= 0:
      let style = TextStyle(fontFamily: "", fontSize: 14.0, color: BLACK,
                            bold: false, italic: false, underline: false)
      var w = IconGutter + measureText(widget.text, style).width
      if widget.shortcut.len > 0:
        w += ShortcutGap + measureText(widget.shortcut, style).width
      if widget.hasSubmenu:
        w += IconGutter
      widget.bounds.width = w + 16.0

  render:
    let props = currentTheme.getThemeProps(widget.intent,
                                           if widget.disabled: Disabled
                                           elif widget.hovered or widget.highlighted: Hovered
                                           else: Normal)

    if widget.separator:
      let color = props.borderColor.get(Color(r: 200, g: 200, b: 200, a: 255))
      let y = widget.bounds.y + widget.bounds.height / 2
      drawLine(widget.bounds.x + 10, y,
               widget.bounds.x + widget.bounds.width - 10, y, color)
      return

    # The shared primitive paints selection + label + submenu arrow; the icon
    # gutter and shortcut column are drawn over it.
    let labelRect = Rect(x: widget.bounds.x + IconGutter, y: widget.bounds.y,
                         width: widget.bounds.width - IconGutter,
                         height: widget.bounds.height)
    # The keyboard's item reads as selected, across the full row (gutter
    # included); a pointer over an item, as hovered.
    let lit = widget.highlighted and not widget.disabled
    drawSelectionBackground(widget.bounds, props, lit, widget.hovered and not lit)
    drawMenuItem(labelRect, widget.text, props, selected = lit,
                 hovered = false, hasSubmenu = widget.hasSubmenu)

    let fgColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
    let glyphY = widget.bounds.y + (widget.bounds.height - 14.0) / 2

    if widget.checkable and widget.checked:
      drawCheckmark(Rect(x: widget.bounds.x + 4, y: glyphY, width: 12, height: 12),
                    fgColor)
    elif widget.iconText.len > 0:
      drawText(widget.iconText, widget.bounds.x + 4, glyphY, 14.0, fgColor)

    if widget.shortcut.len > 0:
      let style = TextStyle(fontFamily: "", fontSize: 12.0, color: fgColor,
                            bold: false, italic: false, underline: false)
      let m = measureText(widget.shortcut, style)
      drawText(widget.shortcut,
               widget.bounds.x + widget.bounds.width - m.width - 10.0,
               glyphY, 12.0,
               Color(r: fgColor.r, g: fgColor.g, b: fgColor.b, a: 160))

    if widget.disabled:
      drawDisabledOverlay(widget.bounds)

proc selectable*(item: Widget): bool =
  ## Whether the keyboard may stop on `item`: a MenuItem that is neither a
  ## separator nor disabled.
  item of MenuItem and not MenuItem(item).separator and
    not MenuItem(item).disabled

proc stepItem*(items: openArray[Widget], current, direction: int): int =
  ## The next selectable item from `current` in `direction` (+1/-1),
  ## wrapping round; -1 when there is none.
  if items.len == 0: return -1
  var i = current
  for _ in 0 ..< items.len:
    i = (i + direction + items.len) mod items.len
    if i < 0: i = items.len - 1
    if items[i].selectable: return i
  -1

proc highlightItem*(items: openArray[Widget], index: int) =
  ## Mark item `index` as the keyboard's, and no other.
  for i, it in items:
    if it of MenuItem:
      let m = MenuItem(it)
      if m.highlighted != (i == index):
        m.highlighted = i == index
        m.isDirty = true

proc itemForLetter*(items: openArray[Widget], letter: char, after: int): int =
  ## The next selectable item whose text starts with `letter` (ignoring
  ## case), after `after`, wrapping; -1 when none does.
  let lower = letter.toLowerAscii
  for k in 1 .. items.len:
    let i = (after + k) mod items.len
    if items[i].selectable and MenuItem(items[i]).text.len > 0 and
       MenuItem(items[i]).text[0].toLowerAscii == lower:
      return i
  -1

proc menuKey*(items: openArray[Widget], current: var int, event: GuiEvent): bool =
  ## The keys inside an open menu: Up/Down (Home/End) move the highlight,
  ## skipping separators and disabled items; Enter/Space choose; a letter
  ## jumps to the item that starts with it. Escape is the owner's: it knows
  ## what closing means.
  case event.key
  of KeyboardKey.Down: current = items.stepItem(current, 1)
  of KeyboardKey.Up: current = items.stepItem(if current < 0: 0 else: current, -1)
  of KeyboardKey.Home: current = items.stepItem(-1, 1)
  of KeyboardKey.End: current = items.stepItem(0, -1)
  of KeyboardKey.Enter, KeyboardKey.KpEnter, KeyboardKey.Space:
    if current >= 0 and current < items.len and items[current].selectable:
      let m = MenuItem(items[current])
      m.highlighted = false
      m.choose()
    return true
  else:
    let k = ord(event.key)
    if k >= ord('A') and k <= ord('Z') and event.mods * {kmCtrl, kmAlt} == {}:
      let i = items.itemForLetter(chr(k), current)
      if i < 0: return false
      current = i
    else:
      return false
  items.highlightItem(current)
  true
