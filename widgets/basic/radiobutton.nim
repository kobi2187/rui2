## RadioButton Widget - RUI2
##
## A radio button for mutually exclusive selection.
## Typically used in groups where only one button can be selected at a time.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl
import ../../drawing_primitives/widget_primitives
import std/options

when defined(useGraphics):
  import raylib

definePrimitive(RadioButton):
  props:
    text: string = ""
    value: string = ""
    selectedValue: string = ""
    disabled: bool = false
    intent: ThemeIntent = Default

  actions:
    onChange(value: string)

  events:
    on_mouse_down:
      if not widget.disabled:
        if widget.selectedValue != widget.value:
          if widget.onChange.isSome:
            widget.onChange.get()(widget.value)
        return true
      return false

  render:
    when defined(useGraphics):
      let state = if widget.disabled: Disabled
                  elif widget.focused: Focused
                  else: Normal
      let props = currentTheme.getThemeProps(widget.intent, state)

      let isSelected = widget.selectedValue == widget.value
      let radioRect = Rect(
        x: widget.bounds.x,
        y: widget.bounds.y,
        width: 20,
        height: 20
      )
      drawRadioButton(radioRect, isSelected, props)

      let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
      let textX = widget.bounds.x + 25
      let textY = widget.bounds.y + (20 - 14) / 2
      drawText(widget.text, textX, textY, 14.0, textColor)
    else:
      let marker = if widget.selectedValue == widget.value: "●" else: "○"
      echo "RadioButton: ", marker, " ", widget.text
