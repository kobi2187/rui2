## Checkbox Widget - RUI2
##
## A checkbox input widget with a label that can be toggled on/off.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import rui_core
import rui_drawing
import std/options

import raylib

definePrimitive(Checkbox):
  props:
    text: string = ""
    initialChecked: bool = false
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    checked: bool

  actions:
    onToggle(checked: bool)

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.checked = not widget.checked
        if widget.onToggle.isSome:
          widget.onToggle.get()(widget.checked)
        return true
      return false

  layout:
    # Size to content so stacks can arrange checkboxes without hand-set bounds.
    const BoxSize = 20.0f32
    const Gap = 8.0f32
    let style = TextStyle(fontFamily: "", fontSize: 14.0, color: BLACK,
                          bold: false, italic: false, underline: false)
    let m = measureText(widget.text, style)
    if widget.bounds.height <= 0:
      widget.bounds.height = max(BoxSize, m.height)
    if widget.bounds.width <= 0:
      widget.bounds.width = BoxSize + Gap + m.width

  render:
    let state = if widget.disabled: Disabled
                elif widget.focused: Focused
                else: Normal
    let props = currentTheme.getThemeProps(widget.intent, state)

    let checkboxRect = Rect(
      x: widget.bounds.x,
      y: widget.bounds.y,
      width: 20,
      height: 20
    )
    drawCheckbox(checkboxRect, widget.checked, props)

    let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
    let textX = widget.bounds.x + 25
    let textY = widget.bounds.y + (20 - 14) / 2
    drawText(widget.text, textX, textY, 14.0, textColor)