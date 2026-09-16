## MenuItem Widget - RUI2
##
## A single row in a Menu, MenuBar dropdown or ContextMenu. Carries text, an
## optional icon glyph, an optional shortcut hint, an optional check state, and
## can instead be a separator rule.

import rui_core
import rui_drawing
import std/options

const
  IconGutter = 20.0'f32
  ShortcutGap = 24.0'f32
  SeparatorHeight = 7.0'f32

definePrimitive(MenuItem):
  props:
    text: string = ""
    shortcut: string = ""        # e.g. "Ctrl+S", "F5"
    iconText: string = ""        # Text icon (emoji / Unicode glyph)
    checkable: bool = false
    initialChecked: bool = false
    separator: bool = false      # Draw a rule instead of a row
    hasSubmenu: bool = false
    itemHeight: float32 = 24.0
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    checked: bool

  actions:
    onClick()
    onToggle(checked: bool)

  events:
    on_mouse_down:
      if widget.disabled or widget.separator:
        return false
      if widget.checkable:
        widget.checked = not widget.checked
        widget.isDirty = true
        if widget.onToggle.isSome:
          widget.onToggle.get()(widget.checked)
      if widget.onClick.isSome:
        widget.onClick.get()()
      return true

  layout:
    if widget.bounds.height <= 0:
      widget.bounds.height = if widget.separator: SeparatorHeight
                             else: widget.itemHeight
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
                                           elif widget.hovered: Hovered
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
    drawMenuItem(labelRect, widget.text, props,
                 hovered = widget.hovered, hasSubmenu = widget.hasSubmenu)

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
