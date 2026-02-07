## Checkbox Widget - RUI2
##
## A checkbox input widget with a label that can be toggled on/off.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../../core/widget_dsl
import ../../../drawing_primitives/widget_primitives
import std/options

when defined(useGraphics):
  import raylib

definePrimitive(Checkbox):
  props:
    text: string = ""
    initialChecked: bool = false
    disabled: bool = false
    #TODO: these should be fetched from the current theme
    themeProps: ThemeProps = ThemeProps(
      backgroundColor: some(Color(r: 255, g: 255, b: 255, a: 255)),
      borderColor: some(Color(r: 180, g: 180, b: 180, a: 255)),
      borderWidth: some(1.0f32),
      cornerRadius: some(2.0f32),
      foregroundColor: some(Color(r: 60, g: 60, b: 60, a: 255)),
      hoverColor: some(Color(r: 240, g: 240, b: 240, a: 255)),
      activeColor: some(Color(r: 100, g: 150, b: 255, a: 255)),
      focusColor: some(Color(r: 100, g: 150, b: 255, a: 255))
    )

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
      let checkboxRect = Rect(
        x: widget.bounds.x,
        y: widget.bounds.y,
        width: 20,
        height: 20
      )
      drawCheckbox(checkboxRect, widget.checked, widget.themeProps)

      let textX = widget.bounds.x + 25
      let textY = widget.bounds.y + (20 - 14) / 2
      drawText(widget.text, textX, textY, 14.0, Color(r: 60, g: 60, b: 60, a: 255))
    else:
      echo "Checkbox: ", widget.text, " [", (if widget.checked: "X" else: " "), "]"
