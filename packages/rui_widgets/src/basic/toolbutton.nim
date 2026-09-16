## ToolButton Widget - RUI2
##
## A flat button for toolbars: icon glyph on top, optional label underneath.
## Unlike IconButton it can be toggleable (stays pressed until clicked again)
## and it only paints a background when hovered, pressed or toggled on.
##
## For a hover tip, pair it with the Tooltip widget: a button cannot draw one
## itself, because renderPass clips every widget to its own bounds.

import rui_core
import rui_drawing
import std/options

const
  IconSize = 16.0'f32
  LabelSize = 9.0'f32

definePrimitive(ToolButton):
  props:
    iconText: string = ""        # Text icon (emoji / Unicode glyph)
    text: string = ""            # Optional label below the icon
    size: float32 = 24.0
    showText: bool = false
    toggleable: bool = false
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    isPressed: bool
    toggled: bool

  actions:
    onClick()
    onToggle(state: bool)

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      if widget.disabled:
        return false
      widget.isPressed = true
      widget.isDirty = true
      return true

    on_mouse_up:
      if not widget.isPressed or widget.disabled:
        return false
      widget.isPressed = false
      widget.isDirty = true

      if widget.toggleable:
        widget.toggled = not widget.toggled
        if widget.onToggle != nil:
          widget.onToggle(widget.toggled)

      if widget.onClick != nil:
        widget.onClick()
      return true

  layout:
    let labelStyle = TextStyle(fontFamily: "", fontSize: LabelSize, color: BLACK,
                               bold: false, italic: false, underline: false)
    let labelW = if widget.showText and widget.text.len > 0:
                   measureText(widget.text, labelStyle).width
                 else:
                   0.0'f32
    if widget.bounds.width <= 0:
      widget.bounds.width = max(widget.size, labelW + 8.0)
    if widget.bounds.height <= 0:
      widget.bounds.height = widget.size +
        (if widget.showText and widget.text.len > 0: LabelSize + 6.0 else: 0.0'f32)

  render:
    let active = widget.isPressed or widget.toggled
    let state = if widget.disabled: Disabled
                elif active: Pressed
                elif widget.hovered: Hovered
                elif widget.focused: Focused
                else: Normal
    let props = currentTheme.getThemeProps(widget.intent, state)

    # Toolbar buttons stay flat until they have something to say.
    if active or widget.hovered or widget.focused:
      drawInteractiveBox(widget.bounds, props, active, widget.hovered, widget.focused)

    if widget.iconText.len > 0:
      let iconRect = Rect(x: widget.bounds.x, y: widget.bounds.y + 4,
                          width: widget.bounds.width, height: IconSize)
      drawThemedCenteredText(widget.iconText, iconRect, props)

    if widget.showText and widget.text.len > 0:
      let labelRect = Rect(
        x: widget.bounds.x,
        y: widget.bounds.y + widget.bounds.height - LabelSize - 4,
        width: widget.bounds.width,
        height: LabelSize
      )
      drawThemedCenteredText(widget.text, labelRect, props)

    if widget.disabled:
      drawDisabledOverlay(widget.bounds)
