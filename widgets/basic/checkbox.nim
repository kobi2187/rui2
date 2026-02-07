## Checkbox Widget - RUI2
##
## A checkbox input widget with a label that can be toggled on/off.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl
import ../../drawing_primitives/widget_primitives
import std/options

when defined(useGraphics):
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

  render:
    when defined(useGraphics):
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
    else:
      echo "Checkbox: ", widget.text, " [", (if widget.checked: "X" else: " "), "]"
